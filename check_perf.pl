#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use feature qw(switch);
use v5.16;
use Term::ANSIColor qw(:constants); 
use Benchmark qw(:all) ;
# use Text::Table;

# Пользоватеьские настройки 
my $SNAPSHOTS_SHOW="0";


my %LPAR;
my %VIOS;
my %SERVER;
# Для benchmarks
my $cr_start;
my $cr_end;
# Возможные метрики для INDICATORS, LPAR(Реальное использование от максимально возможного для LPAR) MEMNEW PAGING CPU(То что видит пользователь), PAGING
# Возможные метрики для Dev_Adapt, DISKBUSY DISKSERV DISKWAIT
# Возможные метрики для twice_calc, pbuf

# FCXFERTOTAL - сумма FCXFERIN и FCXFEROUT за один снепшот

my @INDICATORS=qw/LPAR MEMNEW PAGING/; # Общий список индикаторов по которому должны собираться метрики для каждого такта(SNAPSHOTS)
my @twice_calc=qw/pbuf/;	# Список метрик для которых есть только два значения(Сбор при старте nmon и сбор при завершении nmon)
my @Dev_Adapt=qw//; # Список метрик для девайсов и адаптеров для каждого такта(SNAPSHOTS)
my @Custom_Metric=qw//; # Пользовательские метрики, созданые из обратоки текущих ; При парсинге не учитываются

# my @INDICATORS=qw//; # Общий список индикаторов по которому должны собираться метрики для каждого такта(SNAPSHOTS)
# my @twice_calc=qw//;	# Список метрик для которых есть только два значения(Сбор при старте nmon и сбор при завершении nmon)
# my @Dev_Adapt=qw/DISKBUSY/; # Список метрик для девайсов и адаптеров для каждого такта(SNAPSHOTS)

my $SORTS="MEMNEW"; #  Сортировка
my $regex = join ('|', @INDICATORS, @Dev_Adapt, "nothing");

sub general_value{
	my @a_cap;
	$a_cap[0]=1;
	my %general_value=( 
						min => 101,
						max => 0,
						avg => 0,
						sum => 0,
						min_snap => 0,
						max_snap => 0,
						count => 1,
						# a_cap => \@a_cap,
	);
	return %general_value;
}

sub structure_create {
	my $lparname=shift;
	my $snapshots=\%{$lparname->{SNAPSHOTS}};
	my $result=\%{$lparname->{RESULT}};
	my @tmp=map s/\s//rg, split/,/,"@_";
	my @a_cap;
	my $lp=$#tmp;

	@a_cap=@tmp[2..$#tmp];
	%{$lparname->{RESULT}->{$tmp[0]}}=general_value  ;
	$lparname->{RESULT}->{$tmp[0]}{a_cap}=\@a_cap;
	foreach ( @a_cap ) { 
		%{$lparname->{RESULT}->{$tmp[0]}{$_}} = general_value  ;
	}
}

sub fill_structure {
	# print @_,"\n";
	my $lparname=shift;
	my $snapshots=\%{$lparname->{SNAPSHOTS}};
	my $result=\%{$lparname->{RESULT}};
	my @data_all=split/,/,"@_";
	my @a_cap=@{$result->{$data_all[0]}->{a_cap}};
	my %data;
	my $snap_num=$data_all[1];
	my $count=2;
	foreach my $part (@a_cap) {
		$data{$part}=$data_all[$count++];
	}
	$snapshots->{$snap_num}{$data_all[0]}=\%data;
}
sub search_value{
	my $lparname=shift;
	my $snapshots=$lparname->{SNAPSHOTS};
	my $result=$lparname->{RESULT};
	# my $SAN=$lparname->{SAN};
	my $load_sum;
	my $PS=$result->{"PageSize"};
	my $DN=$result->{"DeviceName"};

	foreach my $snap (keys $snapshots) {
		foreach my $indicator ( @INDICATORS ) {
		# print $indicator,"\n";
			my $load=$snapshots->{$snap}->{$indicator};
			my $avgsub = sub { 
				if ($load_sum > $result->{$indicator}->{max}) {
						$result->{$indicator}->{max}=$load_sum;
						$result->{$indicator}->{max_snap}=$snap;
					}
					$result->{$indicator}->{sum}+=$load_sum;
					$result->{$indicator}->{count}++;
			};

			given ($indicator) {
				when (/^CPU_ALL/  or /^CPU\d\d/	) 	{ $load_sum=$load->{"User%"}		+	$load->{"Sys%"};					&$avgsub}
				when (/^SCPU_ALL/ or /^SCPU\d\d/) 	{ $load_sum=$load->{"User"}			+	$load->{"Sys"}; 					&$avgsub}
				when (/^PCPU_ALL/ or /^PCPU\d\d/) 	{ $load_sum=$load->{"User"}			+	$load->{"Sys"}; 					&$avgsub}
				when (/^LPAR/ 					)	{ $load_sum=$load->{"VP_User%"}		+	$load->{"VP_Sys%"}; 				&$avgsub}
				when (/^MEMNEW/					)	{ $load_sum=100 - $load->{"Free%"}	-	$load->{"FScache%"};				&$avgsub} # 100 - Free - FS cache 
				when (/^PAGING/					)	{ $load_sum=$PS - $load->{"$DN"}; 											&$avgsub}
				when (/FCXFER/) {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						$result->{FCXFERTOTAL}->{total_by_snap}+=$load_sum;
						&$avgsub();
						# &$avgsub("FCXFERTOTAL"); 
					}
				}
				when (/FCREAD/) {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						# $result->{FCXFERTOTAL}->{total_by_snap}+=$load_sum;
						&$avgsub();
						# &$avgsub("FCXFERTOTAL"); 
					}
				}
				when (/FCWRITE/) {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						# $result->{FCXFERTOTAL}->{total_by_snap}+=$load_sum;
						&$avgsub();
						# &$avgsub("FCXFERTOTAL"); 
					}
				}
			}
		}

		foreach my $Dev_Adapt ( @Dev_Adapt ) {
			my $load=$snapshots->{$snap}->{$Dev_Adapt};
			my $avgsub = sub { 
				my $device=shift;
				# my $ref_to_hash=shift||$load;
				if ($load_sum > $result->{$Dev_Adapt}->{$device}->{max}) {
						$result->{$Dev_Adapt}->{$device}->{max}=$load_sum;
						$result->{$Dev_Adapt}->{$device}->{max_snap}=$snap;
					}
				$result->{$Dev_Adapt}->{$device}->{sum}+=$load_sum;
				$result->{$Dev_Adapt}->{$device}->{count}++;
			};
			# print "Dev_Adapt = $Dev_Adapt\n";
			given ( $Dev_Adapt ) {
				when (/DISKBUSY/) { 
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "1");
						&$avgsub($_); 
					}
				}
				when (/DISKSERV/) {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						&$avgsub($_); 
					}
				}
				when (/DISKAVGWIO/) {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						&$avgsub($_); 
					}

				}
				when (/DISKWAIT/) {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						&$avgsub($_); 
					}
				}
				when (/NETERROR/) {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						&$avgsub($_); 
					}
				}
				when (/DISKXFER/) {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						&$avgsub($_); 
					}
				}
			}
		}
		foreach my $metric ( @Custom_Metric ) {
			my $load=$result->{$metric};
			# my $=$snapshots->{$snap}->{$metric};

			my $avgsub = sub { 
				if ($load_sum > $result->{$metric}->{max}) {
						$result->{$metric}->{max}=$load_sum;
						$result->{$metric}->{max_snap}=$snap;
					}
					$result->{$metric}->{sum}+=$load_sum;
					$result->{$metric}->{count}++;
			};
			given ( $metric ) {
				when (/FCXFERTOTAL/) { # Сложить IO со всех адаптеров следующих метрик FCXFERIN и FCXFEROUT
					$result->{$metric}->{max}=0 if  (! exists $result->{$metric}->{max});
					$load_sum=$load->{total_by_snap};
					&$avgsub;
					$load->{total_by_snap}=0; # Обнуляем 
					}
				when (/FCRATIORW/) { # Сложить IO со всех адаптеров следующих метрик FCXFERIN и FCXFEROUT
						$result->{$metric}->{max}=eval(sprintf("%.2f",$result->{FCWRITE}->{sum} * 100 /($result->{FCREAD}->{sum}+$result->{FCWRITE}->{sum})));
						$result->{$metric}->{avg}=100-$result->{$metric}->{max};
				}
			}
		}		
	}

	foreach ( @twice_calc) {
		my $ref=$result->{$_};
		given ($_) {
			when (/pbuf/) {$result->{pbuf}{avg}=$ref->{"pbuf_finish"} - $ref->{"pbuf_begin"}} # Скоколько накапало за один день
		}
	}
# Postprocessing	
	foreach ( @INDICATORS){
		$result->{$_}->{"avg"}=eval(sprintf("%.2f",$result->{$_}->{"sum"} / $result->{$_}->{"count"}))
	}
	foreach my $Dev_Adapt ( @Dev_Adapt ){
		foreach (@{$result->{$Dev_Adapt}{a_cap}}) {
			$result->{$Dev_Adapt}{$_}{"avg"}=eval(sprintf("%.2f",$result->{$Dev_Adapt}{$_}{sum} / $result->{$Dev_Adapt}{$_}{count}))
		}
	}
}

sub server_strcture {
	# AAA
	# SerialNumber
	# 21A84C7
	# my $tmp=shift;
	# my $SerialNumber=$tmp =~ s/^AAA,SerialNumber,//r;
	# $SERVER{$SerialNumber}=();
	# printf "It's BBBL - @_ \n";
}

sub lparname_structure{
	my $lparname=shift;
	my $data=shift;
	my $SerialNumber=shift;
	my $LPAR=shift;
	my %cpu,my %scpu,my %pcpu, my %lpar_stats;
	my %snapshots;
	my %result;
	my $count=1;
	my @ZZZZ=("time","date");

	$result{LPARNAME}=		$LPAR;
	$result{SN}=			$SerialNumber;
	$result{Data}=			$data=~ s/-//gr;
	$result{ID}=			"$result{Data}$LPAR";
	$result{ZZZZ}{a_cap}=	\@ZZZZ;
	$lparname->{SNAPSHOTS}=	\%snapshots;
	$lparname->{RESULT}=	\%result;

	return $lparname;
	# printf "It's BBBL - @_ \n";
}

sub output { 
	# Индикатор, Порог Крит среднее, Предупреждение среднее, Критическое максимальное, критическое предупреждение, Префикс, постфикс
	(my $indicator, my $crit_avg, my $warn_avg, my $crit_max, my $warn_max, my $prefix, my $postfix, my $skip, my $skip_avg)= (@_); 
	my $avg=$indicator->{avg};
	my $max=$indicator->{max}||"0";
	my $snap=$indicator->{max_snap};
	# my $min=$indicator->{min};
	$skip_avg=$skip if (! defined $skip_avg);
	# print "skip_avg=$skip_avg\n";
	return	if ($avg < $skip_avg) and ($max < $skip);


	# return "skip" if &$SKIP($avg);
	if 		($avg > $crit_avg)	{ print " $prefix(", 	RED,	"$avg", "$postfix",	RESET }
	elsif 	($avg > $warn_avg)	{ print " $prefix(", 	YELLOW,	"$avg", "$postfix",	RESET }
	else 						{ print " $prefix(",	GREEN,	"$avg",	"$postfix",	RESET }
	if ( $max > "0") {
		# my $max=$indicator->{max};
		# return "skip" if &$SKIP($max);
		if 		($max > $crit_max) 	{ print 			RED, 	"/$max","$postfix)",	RESET }
		elsif 	($max > $warn_max) 	{ print 			YELLOW, "/$max","$postfix)",	RESET }
		else 					 	{ print 			GREEN,  "/$max","$postfix)",	RESET }
	}else {print ")"}
	print " $snap" if ($SNAPSHOTS_SHOW == 0) and (defined $snap );
}


sub value_for_metricks {
	my $ind=shift;
	my $device=shift||"non defined";
	# print $device;
# Среднее критическое, Среднее предупреждение, Критическое максиммальное, Предупредение максимальное, префикс, постфикс, skip
# =========== CPU ================
	return("60", "50", ,"90", "60", "CPU", 	"%",	"0"	)		if ( $ind eq "CPU_ALL"	);	
	return("60", "50", ,"90", "50", "LPAR",	"%",	"0"	)		if ( $ind eq "LPAR" 	);
	return("60", "90", ,"40", "70", "SCPU",	"%",	"0"	)		if ( $ind eq "SCPU_ALL"	);
	return("60", "90", ,"40", "70", "PCPU",	" core","0"	)		if ( $ind eq "PCPU_ALL"	);
# =========== MEM ================
	return("90", "70", "90", "70", "MEM", "%", "0"		)		if ( $ind eq "MEMNEW"	);
# =========== Page ===============
	return("512", "70", "512", "70", "PageSp", "MB", "0")		if ( $ind eq "PAGING"	);

# =========== Pbuf ===============
	return("1000", "70", "512", "70", "Pbuf", " IO blocks", "0")	if ( $ind eq "pbuf"	);
# =========== DISK ===============
	return("70",		"50",		"70",		"50",		"$device",	" %",	"60"		)		if ( $ind eq "DISKBUSY"	);
	return("100",		"50",		"15",		"5",		"$device",	" ms",	"50", "5"	)		if ( $ind eq "DISKSERV");
	return("2",			"1",		"2",		"1",		"$device",	" ms",	"0.1"		)		if ( $ind eq "DISKWAIT");
	return("100000",	"100000",	"100000",	"100000",	"$device",	" IOs",	"0"			)		if ( $ind eq "DISKXFER");
# =========== NET ===========
	return("2",		"1",	"2",	"1",	"$device",		" ms",	"0")		if ( $ind eq "NETERROR"		);
# =========== FC =================
	return("1400",	"600",	"1400",	"600",	"FCXFERIN",		" IOs",	"0")		if ( $ind eq "FCXFERIN"		);
	return("1400",	"600",	"1400", "600",	"FCXFEROUT",	" IOs",	"0")		if ( $ind eq "FCXFEROUT"	);
	return("50000",	"25000","80000","25000","FCREAD",		" KBs",	"0")		if ( $ind eq "FCREAD"		);
	return("10000",	"8000",	"10000","8000", "FCWRITE",		" KBs",	"0")		if ( $ind eq "FCWRITE"		);
	return("1400",	"1000",	"1400",	"600",	"FCXFERTOTAL",	" IOs",	"0")		if ( $ind eq "FCXFERTOTAL"	);
	return("50",	"50",	"50",	"50",	"FCRATIORW", 	" %",	"0")		if ( $ind eq "FCRATIORW"	);
	
}


# Новая версия вывода отчета , добавлена сортировка
sub report1{ 
	my $sorts=shift;
	my @new_arr;
	@new_arr=sort  { $b->{$SORTS}{max} <=> $a->{$SORTS}{max} } @{$sorts}; # SORTS - a global value , metric by sorting
	# @new_arr=sort  { $b->{$SORTS}{avg} <=> $a->{$SORTS}{avg} } @{$sorts}; # SORTS - a global value , metric by sorting
	# @new_arr=sort  { $b->{$SORTS} cmp $a->{$SORTS} } @{$sorts}; # SORTS - a DATA
	foreach (@new_arr) {
		my $count=0; # Число выведенных метрик
		my $max_on_line=5;
		my $indent_device=1;
		my $ndent_metrics=4;
		# Стандартные значения которые должна содержать каждая LPAR
		my $ID=$_->{ID};
		my $sn=$_->{SN};
		my $date=$_->{Data};
		my $lparname=$_->{LPARNAME};
		##############################################
		my $lpar_ref=$_; # ссылка на LPAR
		my %metrics; # ССылки на метрики
		my @full_array=(@INDICATORS, @twice_calc, @Dev_Adapt, @Custom_Metric);
		my @snapshots=(@INDICATORS, @twice_calc,@Custom_Metric);
		# my @new_arr=(@Custom_Metric,@Dev_Adapt );
		my @keys=(keys %{$_});
		foreach (@full_array) {if ( $_ ~~ @keys ) {$metrics{$_}=$lpar_ref->{$_}}}

		print "$date";
		print "\t$sn";
		print "\t$lparname";
		# printf "\tЗагрузка(avg/max)";
		foreach ( @snapshots ) {
			print "\t"; output($metrics{$_}, value_for_metricks($_));
			print "\n","\t"x$ndent_metrics and $count=0 if ( $count++ >= $max_on_line);

		}
		# print "\n";
		# $count=0;
		foreach ( @Dev_Adapt ) {
			# 1 - В каждой строке не более 8 элементов
			#  Делаем начальный отступ и пишем имя метрики
			my $device=$_;
			print "","\t"x$indent_device, $device,":";
			foreach ( @{$metrics{$device}{"a_cap"}}) {
				output($metrics{$device}{$_}, value_for_metricks($device, $_));
				# print "\n","\t"x$ndent_metrics and $count=0 if ( $count++ >= $max_on_line);
			}
		}
		print "\n";

	}
}

#_____________________________________MAIN_____________________________________________#
{
	# Создаем массив файлов
	my (@files)=@ARGV;
	my @sorts;

	my $files= scalar @files;
	my $cc=1;
	foreach my $FILENAME (@files) {
		# system("clear");
		print "$FILENAME: Обработано файлов...............", $cc++, " из $files  \n" ;
		open(NMON, "<:utf8", "$FILENAME") or die "Can't open this file $!\n";
		my $file=<NMON>;
		my $SerialNumber=0,	my $lparname=0,	my $data=0; # Данные о lpar
		# my %RESULT;
		my %lparname;
		my @head;
		my $PageSize=0,	my $DeviceName=0; # Page Space
		my $pbuf_begin=undef, my $pbuf_finish=undef;

PARSE:	while (<NMON>) {
		    chomp;                  # no newline

		    if (!exists $SERVER{$data}{$SerialNumber}{$lparname}) {
			    $data=$_ 		 =~ s/^AAA,date,//r 																		and next PARSE	if /^AAA,date,/os;
			    $SerialNumber=$_ =~ s/^AAA,SerialNumber,//r 																and next PARSE	if /^AAA,SerialNumber,/os;
				$lparname=$_ 	 =~ s/^AAA,NodeName,//r																		and
				$SERVER{$data}{$SerialNumber}{$lparname}=lparname_structure(\%lparname, $data, $SerialNumber, $lparname)	and next PARSE 	if /^AAA,NodeName,/os;
			}

			# Данные о размере Paging Space
			if ($PageSize eq 0) {
				if ( /^BBBP,\d+,lsps -a,"(hd\d+)\s+hdisk\d{1,3}\s+rootvg\s+(\d+)MB.*/os ) {
					($DeviceName, $PageSize)=($1,$2);
					$SERVER{$data}{$SerialNumber}{$lparname}{"RESULT"}{"PageSize"}=		$PageSize;
					$SERVER{$data}{$SerialNumber}{$lparname}{"RESULT"}{"DeviceName"}=	$DeviceName;
					next PARSE;
				}
			}

			# Сбор данных по SAN
			if ( ! defined $pbuf_begin ) {
				if (/^BBBP,\d+,vmstat\s-v,\"\s+(\d+)\spending disk I\/Os blocked with no pbuf\"/os) {
					$pbuf_begin=$1;
					$SERVER{$data}{$SerialNumber}{$lparname}{"RESULT"}{"pbuf"}{"pbuf_begin"}=$pbuf_begin;
					next PARSE;
				}
			}

			# Сбор snapshots, выполняется только после того как создана структ
		    if  ( /^($regex)/os) {
		    	# print $_,"\n";
				if 		( /^\w+\d{0,2},T\d?/os 		)	{fill_structure		(\%lparname,  $_)	}
				elsif 	( ! /^(AAA|\w+\d{0,2},T\d?)/os)	{structure_create	(\%lparname,  $_)	}
				next PARSE;

		 	}
			if ( ! defined $pbuf_finish ) {
				if (/^BBBP,\d+,ending\svmstat\s-v,\"\s+(\d+)\spending disk I\/Os blocked with no pbuf\"/os) {
					$pbuf_finish=$1;
					$SERVER{$data}{$SerialNumber}{$lparname}{"RESULT"}{"pbuf"}{"pbuf_finish"}=$pbuf_finish;
					next PARSE;
				}
			}			
		} 
		# print "begin: $pbuf_begin, finish: $pbuf_finish", "\n";
	search_value(\%lparname);
	close NMON or warn $! ? "Error closing sort pipe: $!" : "Exit status $? from sort";
	undef $lparname{SNAPSHOTS};
	push(@sorts, $lparname{RESULT});
	# print Dumper(\%lparname);
	}
	# print Dumper(\@sorts);
	report1(\@sorts);

}
__END__

321
