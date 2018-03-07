#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use feature qw(switch);
use v5.16;
use Term::ANSIColor qw(:constants); 
use Benchmark qw(:all) ;
# use Text::Table;
use Getopt::Long;
use Pod::Usage;


# Пользоватеьские настройки  1 - off, 0 - on
my $SHOW_SNAPSHOTS="1";
my $SHOW_time="0";
my $SHOW_vremya="1";


my $verbose="0";
my $CPU_MAX="70";
my $man = 0;
my $help = 0;
my $sAVG_MAX="max";


# Хеши для основных данных
my %LPAR, my %VIOS, my %SERVER;

# Для benchmarks
my $cr_start;
my $cr_end;

# Переменные для форматирования вывода !!! Все заточено под моник 24'
my $max_on_line_dev, my $indent_device;
my $max_on_line_snapsh, my $indent_metrics;
my $new_line_before_device;



# Defaults 
my $sort_num;
# my $SORTS="LPAR"; #  Сортировка  
my $SORTS_tmp; #  Сортировка  
my @INDICATORS;
my @twice_calc;
my @Dev_Adapt;
my @Custom_Metric;
my $type="general";
my $dump=0;
my @files;
my $user_dev=" ";
my $user_iden=" ";


if ( !@ARGV ) {  pod2usage(1)  }
GetOptions (
	"f|files=s{1,}"					=> \@files,
	"s|sort=s"						=> \$SORTS_tmp,
	"t|type=s"						=> \$type,
	"dev|device=s{1,}"				=> \$user_dev,
	"id|identificator=s{1,}"		=> \$user_iden,
	"dump"							=> \$dump,
	"help|?"						=> \$help, 
	"man" 							=> \$man 
	)  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;


my $SORTS=$SORTS_tmp||"LPAR"; #  Сортировка  

# Выбор сортировки
given ( $SORTS ) {
# Сортировка для числовых значений
	when(/CPU$/i)		{	$SORTS="CPU_ALL";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/LPAR$/i)		{	$SORTS="LPAR";			$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/SCPU$/i)		{	$SORTS="SCPU_ALL";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/PCPU$/i)		{	$SORTS="PCPU_ALL";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/MEM$/i)		{	$SORTS="MEMNEW";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/pagesp$/i)	{	$SORTS="PAGING";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/pbuf$/i)		{	$SORTS="pbuf";			$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/DISKBUSY$/i)	{	$SORTS="DISKBUSY";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/DISKSERV$/i)	{	$SORTS="DISKSERV";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/DISKWAIT$/i)	{	$SORTS="DISKWAIT";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/DISKXFER$/i)	{	$SORTS="DISKXFER";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/NETERROR$/i)	{	$SORTS="NETERROR";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/FCXFERIN$/i)	{	$SORTS="FCXFERIN";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/FCXFEROUT$/i)	{	$SORTS="FCXFEROUT";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/FCREAD$/i)	{	$SORTS="FCREAD";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/FCWRITE$/i)	{	$SORTS="FCWRITE";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/FCXFERTOTAL$/i){	$SORTS="FCXFERTOTAL";	$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/FCTOTALGB$/i) {	$SORTS="FCTOTALGB";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/FCRATIORW$/i)	{	$SORTS="FCRATIORW";		$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
# Сортировка для алфовитных значений
	when(/time$/i)		{	$SORTS="Data";			$sort_num="0";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/serial$/i)	{	$SORTS="SN";			$sort_num="0";	print "Sorts - $SORTS" if ($verbose==1) }
	when(/name$/i)		{	$SORTS="LPARNAME";		$sort_num="0";	print "Sorts - $SORTS" if ($verbose==1) }
# Надеемся что пользователь знает что делает
	default 			{ 	$SORTS=$_;				$sort_num="1";	print "Sorts - $SORTS" if ($verbose==1) }
};


# Набор готовых шаблонов - Если пользователь не выбрал ни одного выводим general
given ($type) {
	when ( /neterror/i) {
		@INDICATORS=qw//;
		@twice_calc=qw//;
		@Dev_Adapt=qw/NETERROR/;
		@Custom_Metric=qw//;
		$SORTS=$SORTS_tmp||"LPARNAME";
		$sort_num="0";
		$new_line_before_device=1, $indent_device=4, $max_on_line_snapsh=5, $indent_metrics=4;
	}
	when (/general/i) {
		@INDICATORS=qw/LPAR CPU_ALL PAGING MEMNEW/;
		@twice_calc=qw/pbuf/;
		@Dev_Adapt=qw/DISKSERV/;
		@Custom_Metric=qw//;
		$new_line_before_device=0, $indent_device=1, $max_on_line_snapsh=5, $indent_metrics=1;
	}
	when ( /disk/i) {
		@INDICATORS=qw/FCREAD FCWRITE IOADAPT/;
		@twice_calc=qw/pbuf/;
		@Dev_Adapt=qw/IOADAPT DISKBUSY DISKSERV DISKWAIT DISKREAD DISKWRITE /;
		@Custom_Metric=qw/FCRATIORW FCTOTALGB/;
		$sAVG_MAX="avg";
		$SORTS=$SORTS_tmp||"FCTOTALGB";
		$new_line_before_device=1, $indent_device=4, $max_on_line_snapsh=5, $indent_metrics=4;
	}
# More for test
	when (/ALL/i) {
		@INDICATORS=qw/LPAR CPU_ALL SCPU_ALL PCPU_ALL PAGING MEMNEW FCREAD FCWRITE FCXFERIN FCXFEROUT/;
		@twice_calc=qw/pbuf/;
		@Dev_Adapt=qw/IOADAPT NETERROR DISKBUSY DISKSERV DISKWAIT NETERROR DISKXFER/;
		@Custom_Metric=qw/FCRATIORW/;
		$new_line_before_device=1, $indent_device=4, $max_on_line_snapsh=5, $indent_metrics=4;
	}
	when (/adv/i) {
		@INDICATORS=split/ /,"$user_iden"||qw//;
		@Dev_Adapt=split/ /,"$user_dev"||qw//;
		$SORTS=$SORTS_tmp||"LPARNAME";
		$sort_num="0";
		$new_line_before_device=1, $indent_device=4, $max_on_line_snapsh=5, $indent_metrics=2;
	}
	default {print "Неправильное значения Типа"}
};
# print Dumper(\@Dev_Adapt);
# print Dumper(\@INDICATORS);



# TODO - настроить форматирование вывода (количество полей) для каждой метрики по отдельности
sub choice_indent{
	given (shift){
		when (/IOADAPT/)	{	$max_on_line_dev=3;	}
		when (/NETERROR/)	{	$max_on_line_dev=6;	}
		when (/SEACHPHY/)	{	$max_on_line_dev=3;	}
		when (/SEACLITRAFFIC/){	$max_on_line_dev=2;	}
		when (/NPIV/)		{	$max_on_line_dev=5;	}
		when (/SEA/)		{	$max_on_line_dev=2;	}
		default				{	$max_on_line_dev=4	}
	};
}

# Возможные метрики для INDICATORS, LPAR(Реальное использование от максимально возможного для LPAR) MEMNEW PAGING CPU(То что видит пользователь), PAGING
# Возможные метрики для Dev_Adapt, DISKBUSY DISKSERV DISKWAIT
# Возможные метрики для twice_calc, pbuf

# FCXFERTOTAL - сумма FCXFERIN и FCXFEROUT за один снепшот

# my @INDICATORS=qw/LPAR CPU_ALL PAGING MEMNEW/; # Общий список индикаторов по которому должны собираться метрики для каждого такта(SNAPSHOTS) в отличие от Dev_Adapt, создаваться хеши для каждого девайся (en0,en1 ..) не будут
# my @twice_calc=qw/pbuf/;	# Список метрик для которых есть только два значения(Сбор при старте nmon и сбор при завершении nmon)
# my @Dev_Adapt=qw/DISKSERV/; # Список метрик для девайсов и адаптеров для каждого такта(SNAPSHOTS)
# my @Custom_Metric=qw//; # Пользовательские метрики, созданые из обратоки текущих ; При парсинге не учитываются

# Все возможные
# my @INDICATORS=qw/LPAR CPU_ALL SCPU_ALL PCPU_ALL PAGING MEMNEW FCREAD FCWRITE FCXFERIN FCXFEROUT/; # Общий список индикаторов по которому должны собираться метрики для каждого такта(SNAPSHOTS)
# my @twice_calc=qw/pbuf/;	# Список метрик для которых есть только два значения(Сбор при старте nmon и сбор при завершении nmon)
# my @Dev_Adapt=qw/NETERROR DISKBUSY DISKSERV DISKAVGWIO DISKWAIT NETERROR DISKXFER/; # Список метрик для девайсов и адаптеров для каждого такта(SNAPSHOTS)
# my @Custom_Metric=qw/ FCRATIORW/; # Пользовательские метрики, созданые из обратоки текущих ; При парсинге не учитываются

# my $SORTS="LPARNAME"; #  Сортировка

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
						$result->{$indicator}->{vremya}=$snapshots->{$snap}->{ZZZZ}->{time};
					}
					$result->{$indicator}->{sum}+=$load_sum;
					$result->{$indicator}->{count}++;
			};

			given ($indicator) {
# Нестандартный подсчет значений
				# when (/ZZZZ/	) 	{ $load_sum=$load->{"User%"}		+	$load->{"Sys%"};					&$avgsub}
				when (/^CPU_ALL/  or /^CPU\d\d/	) 	{ $load_sum=$load->{"User%"}		+	$load->{"Sys%"};					&$avgsub}
				when (/^SCPU_ALL/ or /^SCPU\d\d/) 	{ $load_sum=$load->{"User"}			+	$load->{"Sys"}; 					&$avgsub}
				when (/^PCPU_ALL/ or /^PCPU\d\d/) 	{ $load_sum=$load->{"User"}			+	$load->{"Sys"}; 					&$avgsub}
				when (/^LPAR/ 					)	{ 
					$load_sum=$load->{"VP_User%"} + $load->{"VP_Sys%"};
					$result->{$indicator}->{time}++ if ($load_sum > $CPU_MAX);
					&$avgsub
				}
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
# Стандартный подсчет значений
				default	{ 
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
						$result->{$Dev_Adapt}->{$device}->{max}		=$load_sum;
						$result->{$Dev_Adapt}->{$device}->{max_snap}=$snap;
						$result->{$Dev_Adapt}->{$device}->{vremya}	=$snapshots->{$snap}->{ZZZZ}->{time};
					}
				$result->{$Dev_Adapt}->{$device}->{sum}+=$load_sum;
				$result->{$Dev_Adapt}->{$device}->{count}++;
			};
			# print "Dev_Adapt = $Dev_Adapt\n";
			given ( $Dev_Adapt ) {
# Для подсчета требуются доп действия
				when (/DISKBUSY/) { 
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "1"); # Пропускаем значения меньше единицы 
						&$avgsub($_); 
					}
				}
# Если для подсчета не требуется дополнительных действий
				default {
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
					$result->{$metric}->{max}=eval(sprintf("%.2f",$result->{FCWRITE}->{sum} * 100 /($result->{FCREAD}->{sum}+$result->{FCWRITE}->{sum})));
					# $result->{$metric}->{max}=0 if  (! exists $result->{$metric}->{max});
					# $load_sum=$load->{total_by_snap};
					# &$avgsub;
					# $load->{total_by_snap}=0; # Обнуляем 
					}
				when (/FCTOTALGB/) { # Сложить KB со всех адаптеров следующих метрик FCREAD и FCWRITE
					# $result->{$metric}->{avg}=eval(sprintf("%.2f",$result->{FCWRITE}->{sum} * 100 /($result->{FCREAD}->{sum}+$result->{FCWRITE}->{sum})));
					$result->{$metric}->{avg}=eval(sprintf("%.2f",($result->{FCWRITE}->{sum} + $result->{FCREAD}->{sum})/1024/1024));
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
	...
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

}

sub output { 
	# Индикатор, Порог Крит среднее, Предупреждение среднее, Критическое максимальное, критическое предупреждение, Префикс, постфикс
	(my $indicator, my $crit_avg, my $warn_avg, my $crit_max, my $warn_max, my $prefix, my $postfix, my $skip, my $skip_avg)= (@_); 
	my $avg=$indicator->{avg};
	my $max=$indicator->{max}||"0";
	my $snap=$indicator->{max_snap};
	my $time=$indicator->{time};
	my $vremya=$indicator->{vremya};
	# my $min=$indicator->{min};
	$skip_avg=$skip if (! defined $skip_avg);
	# print "skip_avg=$skip_avg\n";
	return 0 if ($avg < $skip_avg) and ($max < $skip);


	# return "skip" if &$SKIP($avg);
	if 		($avg > $crit_avg)	{ print "\t$prefix(", 	RED,	"$avg", "$postfix",	RESET }
	elsif 	($avg > $warn_avg)	{ print "\t$prefix(", 	YELLOW,	"$avg", "$postfix",	RESET }
	else 						{ print "\t$prefix(",	GREEN,	"$avg",	"$postfix",	RESET }
	if ( $max > "0") {
		# my $max=$indicator->{max};
		# return "skip" if &$SKIP($max);
		if 		($max > $crit_max) 	{ print 			RED, 	"/$max","$postfix)",	RESET }
		elsif 	($max > $warn_max) 	{ print 			YELLOW, "/$max","$postfix)",	RESET }
		else 					 	{ print 			GREEN,  "/$max","$postfix)",	RESET }
	}else {print ")"}
	print " $snap" 	if ($SHOW_SNAPSHOTS == 0)	and (defined $snap 	);
	print " x$time" if ($SHOW_time		== 0) 	and (defined $time 	);
	print " $vremya"if ($SHOW_vremya	== 0) 	and (defined $vremya);
	return 1
}


sub value_for_metricks {
	my $ind=shift;
	my $device=shift||"$ind";
	# print $device;
# Среднее критическое, Среднее предупреждение, Критическое максиммальное, Предупредение максимальное, префикс, постфикс, skip
# =========== CPU ================
	return("60", "50", ,"90", "60", "CPU", 	"%",	"0"	)		if ( $ind eq "CPU_ALL"	);	
	return("60", "50", ,"90", "50", "LPAR",	"%",	"0"	)		if ( $ind eq "LPAR" 	);
	return("60", "90", ,"40", "70", "SCPU",	"%",	"0"	)		if ( $ind eq "SCPU_ALL"	);
	return("60", "90", ,"40", "70", "PCPU",	" core","0"	)		if ( $ind eq "PCPU_ALL"	);
# =========== MEM ================
	return("80", "70", "80", "70", "MEM", "%", "0"		)		if ( $ind eq "MEMNEW"	);
# =========== Page ===============
	return("512", "70", "512", "70", "PageSp", "MB", "0")		if ( $ind eq "PAGING"	);

# =========== Pbuf ===============
	return("1000", "70", "512", "70", "Pbuf", " IO blocks", "0")	if ( $ind eq "pbuf"	);
# =========== DISK ===============
	return("70",		"50",		"70",		"50",		"$device",	" %",	"60"		)		if ( $ind eq "DISKBUSY"	);
	return("100",		"50",		"15",		"5",		"$device",	" ms",	"1000", "10")		if ( $ind eq "DISKSERV"	);
	return("2",			"1",		"2",		"1",		"$device",	" ms",	"0.1"		)		if ( $ind eq "DISKWAIT"	);
	return("100000",	"100000",	"100000",	"100000",	"$device",	" IOs",	"0"			)		if ( $ind eq "DISKXFER"	);
	return("50000",		"25000",	"80000",	"25000",	"$device",	" KBs",	"0"			)		if ( $ind eq "DISKREAD"	);
	return("10000",		"8000",		"10000",	"8000",		"$device",	" KBs",	"0"			)		if ( $ind eq "DISKWRITE");
# =========== NET ===========
	return("2",		"1",	"2",	"1",	"$device",		" ms",	"0")		if ( $ind eq "NETERROR"		);
# =========== FC =================
	return("1400",	"600",	"1400",	"600",	"FCXFERIN",		" IOs",	"0")		if ( $ind eq "FCXFERIN"		);
	return("1400",	"600",	"1400", "600",	"FCXFEROUT",	" IOs",	"0")		if ( $ind eq "FCXFEROUT"	);
	return("50000",	"25000","80000","25000","FCREAD",		" KBs",	"0")		if ( $ind eq "FCREAD"		);
	return("100000","80000","100000","80000", "FCWRITE",	" KBs",	"0")		if ( $ind eq "FCWRITE"		);
	return("1400",	"1000",	"1400",	"600",	"FCXFERTOTAL",	" IO",	"0")		if ( $ind eq "FCXFERTOTAL"	);
	return("1400",	"1000",	"1400",	"600",	"FCTOTALGB",	" GB",	"0")		if ( $ind eq "FCTOTALGB"	);
	return("100",	"100",	"100",	"100",	"Read/Write", 	" %",	"0")		if ( $ind eq "FCRATIORW"	);
# ============= IOADAPT ========================
	return("100000",		"80000",		"100000",	"80000",		"$device",	" KBs",	"0"			)		if ( $ind eq "IOADAPT");

# ============= Хотелось бы знать что именно пользователь хочет вывести, но мы не знаем, так что, просто нечего не раскрашиваем
	return("999999999",	"999999999",	"999999999",	"999999999",	"$device",	" ",	"0");


	
}


# Новая версия вывода отчета , добавлена сортировка
sub report1{ 
	my $sorts=shift;
	my @new_arr;
	@new_arr=sort  { $b->{$SORTS}{$sAVG_MAX} <=> $a->{$SORTS}{$sAVG_MAX} } @{$sorts} 	if ($sort_num == 1); # SORTS - a global value , metric by sorting
	@new_arr=sort  { $b->{$SORTS} cmp $a->{$SORTS} } @{$sorts} 							if ($sort_num == 0); # SORTS - a DATA (string line)

	foreach (@new_arr) {
		my $count=1; # Число выведенных метрик

		# Стандартные значения которые должна содержать каждая LPAR
		my $ID=$_->{ID};
		my $sn=$_->{SN};
		my $date=$_->{Data};
		my $lparname=$_->{LPARNAME};
		##############################################
		my $lpar_ref=$_; # ссылка на LPAR
		my %metrics; # Сылки на метрики
		my @full_array=(@INDICATORS, @twice_calc, @Dev_Adapt, @Custom_Metric);
		my @snapshots=(@INDICATORS, @twice_calc,@Custom_Metric);
		# my @new_arr=(@Custom_Metric,@Dev_Adapt );
		my @keys=(keys %{$_});
		foreach (@full_array) {if ( $_ ~~ @keys ) {$metrics{$_}=$lpar_ref->{$_}}}

		print "$date";
		print " $sn";
		print " $lparname","\n"x$new_line_before_device,"\t"x$indent_metrics;
		# printf "\tЗагрузка(avg/max)";
		foreach ( @snapshots ) {
			# print "__${count}__";
			print "\n","\t"x$indent_metrics and $count=2 if ( $count++ > $max_on_line_snapsh);
			print ""; output($metrics{$_}, value_for_metricks($_));
		}
		# $count=0;
		foreach ( @Dev_Adapt ) {
			choice_indent($_);
			$count=1; 
			# 1 - В каждой строке не более 8 элементов
			#  Делаем начальный отступ и пишем имя метрики
			my $device=$_;
			print "\n" if ($new_line_before_device == 1) ;
			print "","\t"x$indent_device, $device,":\n"x$new_line_before_device,"\t"x$indent_device;

			foreach (sort ( @{$metrics{$device}{"a_cap"}})) {
				my $result=output($metrics{$device}{$_}, value_for_metricks($device, $_));
				# print "-------------${count}-----------";
				print "\n","\t"x$indent_device and $count=1 if ( ($count=$result + $count) > $max_on_line_dev);
			}
			print "\n" if ($new_line_before_device == 1) ;
		}
		print "\n";

	}
}

#_____________________________________MAIN_____________________________________________#
{
	# Создаем массив файлов
	# my (@files)=@ARGV;
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
		my $BBSEA;

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

			# Сбор данных по PBUF
			if ( ! defined $pbuf_begin ) {
				if (/^BBBP,\d+,vmstat\s-v,\"\s+(\d+)\spending disk I\/Os blocked with no pbuf\"/os) {
					$pbuf_begin=$1;
					$SERVER{$data}{$SerialNumber}{$lparname}{"RESULT"}{"pbuf"}{"pbuf_begin"}=$pbuf_begin;
					next PARSE;
				}
			}

			# Сбор snapshots, выполняется только после того как создана структура
		    if  ( /^($regex)/os or /ZZZZ/os) {
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
	# print Dumper(\%lparname);
	close NMON or warn $! ? "Error closing sort pipe: $!" : "Exit status $? from sort";
	undef $lparname{SNAPSHOTS};
	push(@sorts, $lparname{RESULT});
	}
	print Dumper(\@sorts) if ($dump==1);
	report1(\@sorts);

}

__END__

=encoding utf-8
=head1 NAME

sample - Простой парсер NMON файлов

=head1 SYNOPSIS

Example: check_perf.pl -f /path/to/dir/file* -s LPAR -t general --dump 

=head1 OPTIONS
   -help           brief help message
   -man            full documentation
   -files          Список NMON которые необходимо проверить. К примеру /home/mishina/NMON/18021[678]/* 
   -sort           Выбор столбца для сортировки. По умолчанию LPAR
   -type           Набор шаблонов для сбора статистики. По умолчанию general
   -dump           Вывод готового хеша содержащий данные прошедшие сортировку и парсинг.  


=head1 DESCRIPTION

Скрипт для быстрого анализа NMON файлов. Парсит и B<вывод> метрики по определенным параметрам.

=cut

=head2 OPTIONS

   -help -h        brief help message
   -man            full documentation
   -files -f       Список NMON которые необходимо проверить. К примеру /home/mishina/NMON/18021[678]/* 
   -sort  -s       Выбор столбца для сортировки. По умолчанию LPAR. 
                   Доступные сортировки:
                        LPAR - Загрузка CPU с учетов entitled
                        CPU - Загрзука CPU
                        MEM - Используемая память
                        pagesp - Сколько памяти в Page
                        pbuf - Свидетельствует о недостатки pbuf для VG
                        DISKSERV - Среднее время дискового ввода-вывода на передачу в миллисекундах.
                        FCRATIORW - соотношение  IO Чтение/Запись 
                        time - Дата
                        serial - Серийный номер оборудования
                        name - Имя LPAR
                        !!!!!!!!!!! NETERROR - Ошибки на адаптерах. Возможно доверять этим данным не стоит...
                        SCPU - 
                        PCPU - 
                        DISKBUSY - 
                        DISKWAIT - 
                        DISKXFER - 
                        FCXFERIN - 
                        FCXFEROUT - 
                        FCREAD - 
                        FCWRITE - 
                        FCXFERTOTAL - 
   -type  -t        Набор шаблонов для сбора статистики. По умолчанию general.
                    Доступные шаблоны:
                    !!!!!!! neterror - Вывод ошибок на сетевых интерфейсах. Возможно доверять этим данным не стоит...
                    general  - Вывод метрик по LPAR CPU PAGING MEM.
                    disk     - Вывод метрик по FCTOTALGB FCRATIORW. 

   -dump           Вывод готового хеша содержащий данные прошедшие сортировку и парсинг.  


=cut
