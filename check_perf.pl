#!/usr/bin/perl 
use strict;
use warnings;
use Data::Dumper;
use feature qw(switch);
use v5.16;
use Term::ANSIColor qw(:constants); 
use Benchmark qw(:all);
use Getopt::Long;
use Pod::Usage;
use JSON;
use Scalar::Util qw(looks_like_number);
no warnings qw( experimental::smartmatch );


my $YES=1;
my $NO=0;


my $tinit;
my $tinit_fin;
my $tdif_init;
$tinit = Benchmark->new ;


# Пользоватеьские настройки ;
my $SHOW_SNAPSHOTS	="$NO";
my $SHOW_time		="$YES";
my $SHOW_vremya		="$NO";

my $SHOW_phys_against_entitle="$YES";
my $SHOW_phys="$YES";
my $SHOW_EC="$NO";
my $SHOW_PoolBusy="$NO";
my $SHOW_entitled_level="$YES";


my $verbose="0";
my $bench="0";
my $CPU_MAX="99";
my $CPU_ALL_MAX="50";
my $EC_MAX="50";
my $entitled;
my $man = 0;
my $help = 0;
my $sAVG_MAX="max";
my $CVS_FROMATE=$NO;


# Хеши для основных данных
my %LPAR, my %VIOS, my %SERVER;
my $type="general1";
my $delimetr="\t";

# Metrics what have depends of others
# FCRATIORW - FCWRITE FCREAD
# FCTOTALGB - FCWRITE FCREAD
# FCXFERTOTAL - FCXFEROUT FCXFERIN




# Переменные для форматирования вывода !!! Все заточено под моник 24'
my $max_on_line_dev, 	my $indent_device;
my $max_on_line_snapsh, my $indent_metrics;
my $new_line_before_device;

# Defaults 
my $sort_num;
my $SORTS_tmp; #  Сортировка  
my @INDICATORS;
my @twice_calc;
my @Dev_Adapt;
my @Custom_Metric;
my $dump=$NO;
my $requiered_gather=$NO;
my @files, my @json;
my $user_dev=" ", my $user_iden=" ", my $user_cust=" "; # Если пользователь выбирает метрики вручную
my $zero=0; # Вывод метрик с 0 
my $no_new_line=0, my $max_dev, my $max_snap;

if ( !@ARGV ) {  pod2usage(1)  }
GetOptions (
	"files=s{1,}"					=> \@files,
	"j|json=s{1,}"					=> \@json,
	"g|gather"						=> \$requiered_gather,
	"s|sort=s"						=> \$SORTS_tmp,
	"t|type=s"						=> \$type,
	"cvs"							=> \$CVS_FROMATE,
	"F=s"							=> \$delimetr,
	"dev|device=s{1,}"				=> \$user_dev,
	"id|identificator=s{1,}"		=> \$user_iden,
	"cu|custom=s{1,}"				=> \$user_cust,
	"dump"							=> \$dump,
	"help|?"						=> \$help, 
	"zero" 							=> \$zero,
	"no_new-line|nonl"				=> \$no_new_line,
	"md=s" 							=> \$max_dev,
	"ms=s" 							=> \$max_snap,
	"man" 							=> \$man,
	"verbose"						=> \$verbose,
	"bench"							=> \$bench
	)  or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

# Для benchmarks
my $tstart;
my $tfinished;
my $tdfinished;
$tstart = Benchmark->new  								if ($bench == 1);


my $SORTS=$SORTS_tmp||"name"; #  Сортировка  
my $SORTS1=$SORTS_tmp||"name"; #  Сортировка  
my @custom_all=qw/FCRATIORW FCTOTALGB FCXFERTOTAL/;
my @indicator_all=qw/LPAR CPU_ALL SCPU_ALL PCPU_ALL PAGING MEMNEW FCREAD FCWRITE FCXFERIN FCXFEROUT IOADAPT/;
my @twice_calc_all=qw/pbuf/;
# Набор готовых шаблонов - Если пользователь не выбрал ни одного выводим general
given ($type) {
	when ( /silin/i) {
		@INDICATORS=qw/CPU_ALL MEMNEW IOADAPT NET FCREAD FCWRITE/;
		@twice_calc=qw//;
		@Dev_Adapt=qw//;
		@Custom_Metric=qw/FCRATIORW FCTOTALGB/;
		$SORTS=$SORTS_tmp||"CPU_ALL";
		$sort_num="1";
		$new_line_before_device=0, $indent_device=1, $max_on_line_snapsh=9, $indent_metrics=1;
	}
	when ( /neterror/i) {
		@INDICATORS=qw//;
		@twice_calc=qw//;
		@Dev_Adapt=qw/NETERROR/;
		@Custom_Metric=qw//;
		$SORTS=$SORTS_tmp||"LPARNAME";
		$sort_num="0";
		$new_line_before_device=1, $indent_device=4, $max_on_line_snapsh=5, $indent_metrics=4;
	}
	when (/general$/i) {
		@INDICATORS=qw/CPU_ALL PAGING MEMNEW PROC PCPU_ALL/;
		@twice_calc=qw//;
		@Dev_Adapt=qw//;
		$SORTS=$SORTS_tmp||"CPU_ALL";
		$SHOW_EC="$YES";
		@Custom_Metric=qw//;
		$new_line_before_device=0, $indent_device=1, $max_on_line_snapsh=8, $indent_metrics=1;
	}
	when ( /disk/i) {
		@INDICATORS=qw/FCREAD FCWRITE IOADAPT FCXFERIN FCXFEROUT/;
		@twice_calc=qw/pbuf/;
		@Dev_Adapt=qw/IOADAPT DISKBUSY DISKSERV DISKWAIT DISKREAD DISKWRITE /;
		@Custom_Metric=qw/FCRATIORW FCTOTALGB FCXFERTOTAL/;
		$sAVG_MAX="avg";
		$SORTS=$SORTS_tmp||"FCTOTALGB";
		$new_line_before_device=1, $indent_device=4, $max_on_line_snapsh=5, $indent_metrics=4;
	}
	when ( /IO/i) {
		@INDICATORS=qw/FCREAD FCWRITE IOADAPT FCXFERIN FCXFEROUT NET/;
		@twice_calc=qw/pbuf/;
		@Dev_Adapt=qw/IOADAPT DISKBUSY DISKSERV DISKWAIT DISKREAD DISKWRITE NET/;
		@Custom_Metric=qw/FCRATIORW FCTOTALGB FCXFERTOTAL/;
		$sAVG_MAX="avg";
		$SORTS=$SORTS_tmp||"FCTOTALGB";
		$new_line_before_device=1, $indent_device=4, $max_on_line_snapsh=5, $indent_metrics=4;
	}
	when (/general1/i) {
		@INDICATORS=qw/CPU_ALL PAGING MEMNEW PROC PCPU_ALL/;
		@twice_calc=qw//;
		@Dev_Adapt=qw//;
		$SORTS=$SORTS_tmp||"CPU_ALL";
		$SHOW_EC="$YES";
		@Custom_Metric=qw/Entitled/;
		$new_line_before_device=0, $indent_device=1, $max_on_line_snapsh=8, $indent_metrics=1;
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
		@Custom_Metric=split/ /,"$user_cust"||qw//;
		$new_line_before_device =  $no_new_line eq '0' ? '1' : '0' ; # Если опции -nonl нету, то печатаем символ новой строки после хостнейма и перед выводом каждого девайса. 
		$indent_device=4, $max_on_line_snapsh=5, $indent_metrics=2;
	}
	default {print "Неправильное значения Типа"}
};

# Выбор сортировки
given ( $SORTS ) {
# Сортировка для числовых значений
	when(/CPU$/i)		{	$SORTS="CPU_ALL";		$SORTS1="CPU_ALL";		$sort_num="1";	}
	when(/SCPU$/i)		{	$SORTS="SCPU_ALL";		$SORTS1="SCPU_ALL";		$sort_num="1";	}
	when(/PCPU$/i)		{	$SORTS="PCPU_ALL";		$SORTS1="PCPU_ALL";		$sort_num="1";	}
	when(/MEM$/i)		{	$SORTS="MEMNEW";		$SORTS1="MEMNEW";		$sort_num="1";	}
	when(/pagesp$/i)	{	$SORTS="PAGING";		$SORTS1="PAGING";		$sort_num="1";	}
	when(/pbuf$/i)		{	$SORTS="pbuf";			$SORTS1="pbuf";			$sAVG_MAX="avg";$sort_num="2";	}
	when(/DISKBUSY$/i)	{	$SORTS="DISKBUSY";		$SORTS1="DISKBUSY";		$sort_num="1";	}
	when(/DISKSERV$/i)	{	$SORTS="DISKSERV";		$SORTS1="DISKSERV";		$sort_num="1";	}
	when(/DISKWAIT$/i)	{	$SORTS="DISKWAIT";		$SORTS1="DISKWAIT";		$sort_num="1";	}
	when(/DISKXFER$/i)	{	$SORTS="DISKXFER";		$SORTS1="DISKXFER";		$sort_num="1";	}
	when(/NETERROR$/i)	{	$SORTS="NETERROR";		$SORTS1="NETERROR";		$sort_num="1";	}
	when(/FCXFERIN$/i)	{	$SORTS="FCXFERIN";		$SORTS1="FCXFERIN";		$sort_num="1";	}
	when(/FCXFEROUT$/i)	{	$SORTS="FCXFEROUT";		$SORTS1="FCXFEROUT";	$sort_num="1";	}
	when(/FCREAD$/i)	{	$SORTS="FCREAD";		$SORTS1="FCREAD";		$sort_num="1";	}
	when(/FCWRITE$/i)	{	$SORTS="FCWRITE";		$SORTS1="FCWRITE";		$sort_num="1";	}
	when(/PhysAlloc|PhysicalCPU|EC|entitled|PoolBusy|LPAR/i)	
	{	$SORTS='LPAR';			$SORTS1='EC';	$sort_num="1"; 	$sAVG_MAX="max"}
	when(/FCXFERTOTAL$/i){	$SORTS="FCXFERTOTAL";	$SORTS1="FCXFERTOTAL";	$sort_num="1";	}
	when(/.*TOTALGB$/i) {	$SORTS="$_";			$SORTS1="$_";			$sort_num="1";	$sAVG_MAX="avg"}
	when(/FCRATIORW$/i)	{	$SORTS="FCRATIORW";		$SORTS1="FCRATIORW";	$sort_num="1";	$sAVG_MAX="max"}
# Сортировка для алфовитных значений
	when(/time$|date$/i)		{	$SORTS="Data";			$SORTS1="Data";			$sort_num="0";	}
	when(/serial$/i)	{	$SORTS="SN";			$SORTS1="SN";			$sort_num="0";	}
	when(/name$/i)		{	$SORTS="LPARNAME";		$SORTS1="LPARNAME";		$sort_num="0";	}
# Надеемся что пользователь знает что делает
	default 			{ 	$SORTS=$_;				$SORTS1=$_;				$sort_num="1";	}
};


# PhysicalCPU|EC|entitled|PoolBusy
# my $new_line, my $max_dev, my $max_snap;
sub save_json{
	my $array=shift;
	foreach (@{$array}) {
		# print Dumper($_);
		my $name=$_->{FILENAME};
		open my $fh, ">", "$name.json";
		print $fh encode_json($_);
		close $fh;
	}
}

sub open_json{
	my @sorts;
	my $FILE_PATH;
	my $cc=1;
	my $json= scalar @json;
	foreach (@json) {
		print "$_: Обработано файлов...............", $cc++, " из $json  \n" ;
		# print Dumper($_);
		open my $fh, "<", "$_";
		# open(JSON, "<:utf8", "$_") or die "Can't open this file $!\n";
		push(@sorts, decode_json(<$fh>));
		close $fh;
	}
	return @sorts;
}

sub choice_indent{
	given (shift){
		when (/IOADAPT/)	{	$max_on_line_dev=${max_dev}||3;	}
		when (/NETERROR/)	{	$max_on_line_dev=${max_dev}||6;	}
		when (/SEACHPHY/)	{	$max_on_line_dev=${max_dev}||3;	}
		when (/SEACLITRAFFIC/){	$max_on_line_dev=${max_dev}||2;	}
		when (/NPIV/)		{	$max_on_line_dev=${max_dev}||5;	}
		when (/SEA/)		{	$max_on_line_dev=${max_dev}||2;	}
		default				{	$max_on_line_dev=${max_dev}||4	}
	};
}

# FCXFERTOTAL - сумма FCXFERIN и FCXFEROUT за один снепшот

# my @INDICATORS=qw/LPAR CPU_ALL PAGING MEMNEW/; # Общий список индикаторов по которому должны собираться метрики для каждого такта(SNAPSHOTS) в отличие от Dev_Adapt, 
# создаваться хеши для каждого девайся (en0,en1 ..) не будут
# my @twice_calc=qw/pbuf/;	# Список метрик для которых есть только два значения(Сбор при старте nmon и сбор при завершении nmon)
# my @Dev_Adapt=qw/DISKSERV/; # Список метрик для девайсов и адаптеров для каждого такта(SNAPSHOTS)
# my @Custom_Metric=qw//; # Пользовательские метрики, созданые из обратоки текущих ; При парсинге не учитываются
my $regex;
sub create_regex{ $regex = join ('|', @INDICATORS, @Dev_Adapt, "ZZZZ") }

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

sub check_on_double_name {
	# Некоторые метрики имеют двойное название и их нужно отсеить, иначе скрипт не сможет создать верные метрики
	return 1 if m/TOP,%CPU Utilisation/; 
}

sub change_position{
	my @data_all=@_;
	if ( $data_all[0]  eq "TOP" )  {
	# Некоторые структры имеют отлитчный порядок, приводим его к общему
		my $tmp1=$data_all[1],	my$tmp2=$data_all[2];
		splice (@data_all, 1,2 , $tmp2,$tmp1);
	}
	return @data_all;

}
sub structure_create {
	my $lparname=shift;
	my $string=shift;
	my $gather=shift||$NO;
	my $snapshots=\%{$lparname->{SNAPSHOTS}};
	my $result=\%{$lparname->{RESULT}};
	my @tmp=change_position(map s/\s//rg, split/,/,"$string");
	my @a_cap;
	my $lp=$#tmp;

	return if check_on_double_name($string); #check on double name

	@a_cap=@tmp[2..$#tmp];
	%{$lparname->{RESULT}->{$tmp[0]}}=general_value  ;
	# %{$lparname->{RESULT}->{$tmp[0]}{general}{$tmp[0]}}=general_value  ;
	$lparname->{RESULT}->{$tmp[0]}{a_cap}=\@a_cap;
	foreach ( @a_cap ) { 
		%{$lparname->{RESULT}->{$tmp[0]}{$_}} = general_value  ;
	}
	push(@Dev_Adapt, $tmp[0]) if ($gather == $YES)
}

sub fill_structure {
	my $lparname=shift;
	my $snapshots=\%{$lparname->{SNAPSHOTS}};
	my $result=\%{$lparname->{RESULT}};
	# my @data_all=split/,/,"@_";
	my @data_all=change_position(split/,/,"@_");
	my %data;
	# @data_all=change_position(\@data_all);

	my @a_cap=@{$result->{$data_all[0]}->{a_cap}};
	my $snap_num=$data_all[1] ;

	my $count=2;
	foreach my $part (@a_cap) {	$data{$part}=$data_all[$count++];} 
	if ( $data_all[0] eq "TOP") {
			$snapshots->{$snap_num}{$data_all[0]}{$data_all[2]}=\%data;
		} else {
			$snapshots->{$snap_num}{$data_all[0]}=\%data;
	}

}

sub Process_Statistic{
	...
}


sub search_value{
	my $lparname=shift;
	my $snapshots=$lparname->{SNAPSHOTS};
	my $result=$lparname->{RESULT};
	my $tmp_ref=$lparname->{TMP};
	# my $config=$lparname->{CONFIG};
	# my $result={};
	# my $SAN=$lparname->{SAN};
	my $load_sum;
	my $PS=$tmp_ref->{"PageSize"};
	my $DN=$tmp_ref->{"DeviceName"};
	my $Entitled_Capacity;
	if ( exists $result->{CONFIG}{HARDWARE}{BBBL}{"Entitled Capacity"} ){
		$result->{Entitled_Capacity}=$Entitled_Capacity=$result->{CONFIG}{HARDWARE}{BBBL}{"Entitled Capacity"};
	}
	my $count=1;
	foreach my $snap (keys %$snapshots) {
		foreach my $indicator ( @INDICATORS ) {
		# print $indicator,"\n";
			my $load=$snapshots->{$snap}->{$indicator};
			my $avgsub = sub {
				my $IND_SUB_CLASS=shift||$indicator;
				$result->{$indicator}->{general}{$IND_SUB_CLASS}{max}=0 	if (!defined $result->{$indicator}->{general}{$IND_SUB_CLASS}{max});
				$result->{$indicator}->{general}{$IND_SUB_CLASS}{min}=99999 if (!defined $result->{$indicator}->{general}{$IND_SUB_CLASS}{min});
				if ($load_sum > $result->{$indicator}->{general}{$IND_SUB_CLASS}{max}) {
						$result->{$indicator}->{general}{$IND_SUB_CLASS}{max}=$load_sum;
						$result->{$indicator}->{general}{$IND_SUB_CLASS}{max_snap}=$snap;
						$result->{$indicator}->{general}{$IND_SUB_CLASS}{vremya}=$snapshots->{$snap}->{ZZZZ}->{time};
					}
				if ($load_sum < $result->{$indicator}->{general}{$IND_SUB_CLASS}{min}) {
						$result->{$indicator}->{general}{$IND_SUB_CLASS}{min}=$load_sum;
						$result->{$indicator}->{general}{$IND_SUB_CLASS}{min_snap}=$snap;
						$result->{$indicator}->{general}{$IND_SUB_CLASS}{min_vremya}=$snapshots->{$snap}->{ZZZZ}->{time};
					}
					$result->{$indicator}->{general}{$IND_SUB_CLASS}{sum}+=$load_sum;
					$result->{$indicator}->{general}{$IND_SUB_CLASS}{count}++;
			};

			given ($indicator) {

# Нестандартный подсчет значений
				# when (/ZZZZ/	) 	{ $load_sum=$load->{"User%"}		+	$load->{"Sys%"};					&$avgsub}
				when (/^CPU_ALL/  or /^CPU\d\d/	) 	{ $load_sum=$load->{"User%"}		+	$load->{"Sys%"};					&$avgsub}
				when (/^SCPU_ALL/ or /^SCPU\d\d/) 	{ $load_sum=$load->{"User"}			+	$load->{"Sys"}; 					&$avgsub}
				when (/^PCPU_ALL/ or /^PCPU\d\d/) 	{ 
					$load_sum=$load->{"User"} +	$load->{"Sys"};
					$result->{$indicator}->{general}{PCPU_ALL}{time}++ if ($load_sum > $Entitled_Capacity);
					&$avgsub;
					}
				when (/^MEMNEW/					)	{ $load_sum=100 - $load->{"Free%"};											&$avgsub} # 100 - Free 
				when (/^PAGING/					)	{ $load_sum=$PS - $load->{"$DN"}; 											&$avgsub}
				when (/^PROC$/					)	{ $load_sum=$load->{"Runnable"}; 											&$avgsub}
				when (/^LPAR/ )	{ 
					if ( $SHOW_phys == $YES) {
						$load_sum=$load->{"PhysicalCPU"};
						$result->{$indicator}->{general}{PhysicalCPU}{time}++ if ($load_sum > $Entitled_Capacity);
						&$avgsub("PhysicalCPU");
					}
					if ( $SHOW_phys_against_entitle == $YES) {
						$load_sum=eval(sprintf("%.2f",$load->{"PhysicalCPU"} / $load->{entitled}* 100));
						$result->{$indicator}->{general}{'PhysAlloc%'}{time}++ if ($load_sum > $CPU_MAX);
						&$avgsub("PhysAlloc%");
					}
					if ( $SHOW_EC == $YES) {
						$load_sum=$load->{"VP_User%"} + $load->{"VP_Sys%"};
						$result->{$indicator}->{general}{EC}{time}++ if ($load_sum > $EC_MAX);
						&$avgsub("EC");
					}
					if ( $SHOW_entitled_level == $YES) {
						$load_sum=$load->{entitled};
						&$avgsub("entitled");
					}
					if ( $SHOW_PoolBusy == $YES) {
						$load_sum=$result->{CONFIG}{HARDWARE}{BBBL}{'Pool CPU'}-$load->{PoolIdle}; # 
						&$avgsub("PoolBusy");
					}
				}
				when (/^FCXFER/) {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						$result->{$indicator}->{general}{$indicator}{avg}+=$load_sum;
						&$avgsub();
						# &$avgsub("FCXFERTOTAL"); 
					}
				}
# Стандартный подсчет значений
				default	{ 
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "0");
						&$avgsub();
					}
				}
			}
		}

		foreach my $Dev_Adapt ( @Dev_Adapt ) {
		$count++;

			my $load=$snapshots->{$snap}->{$Dev_Adapt};
			my $avgsub = sub { 
				my $device=shift;
				if ($load_sum > $result->{$Dev_Adapt}->{$device}->{max}) {
						$result->{$Dev_Adapt}->{$device}->{max}		=$load_sum;
						$result->{$Dev_Adapt}->{$device}->{max_snap}=$snap;
						$result->{$Dev_Adapt}->{$device}->{vremya}	=$snapshots->{$snap}->{ZZZZ}->{time};
					}
				if ($load_sum < $result->{$Dev_Adapt}->{$device}->{min}) {
						$result->{$Dev_Adapt}->{$device}->{min}		=$load_sum;
						$result->{$Dev_Adapt}->{$device}->{min_snap}=$snap;
						$result->{$Dev_Adapt}->{$device}->{min_vremya}	=$snapshots->{$snap}->{ZZZZ}->{time};
					}
				$result->{$Dev_Adapt}->{$device}->{sum}+=$load_sum;
				$result->{$Dev_Adapt}->{$device}->{count}++;
			};
			my $TOPSUB = sub {
				my $PID=shift;
				my $dev=shift;
				$result->{$Dev_Adapt}->{$PID}->{$dev}->{avg}=0 	if (!defined $result->{$Dev_Adapt}->{$PID}->{$dev}->{avg});
				$result->{$Dev_Adapt}->{$PID}->{$dev}->{max}=0 	if (!defined $result->{$Dev_Adapt}->{$PID}->{$dev}->{max});
				$result->{$Dev_Adapt}->{$PID}->{$dev}->{max_snap}=0 if (!defined $result->{$Dev_Adapt}->{$PID}->{$dev}->{max_snap}); 
				$result->{$Dev_Adapt}->{$PID}->{$dev}->{vremya}=0 if (!defined $result->{$Dev_Adapt}->{$PID}->{$dev}->{vremya}); 
				$result->{$Dev_Adapt}->{$PID}->{$dev}->{min}=99999 if (!defined $result->{$Dev_Adapt}->{$PID}->{$dev}->{min}); 
				$result->{$Dev_Adapt}->{$PID}->{$dev}->{min_snap}=99999 if (!defined $result->{$Dev_Adapt}->{$PID}->{$dev}->{min_snap}); 
				$result->{$Dev_Adapt}->{$PID}->{$dev}->{min_vremya}=99999 if (!defined $result->{$Dev_Adapt}->{$PID}->{$dev}->{min_vremya}); 
				if ($load_sum > $result->{$Dev_Adapt}->{$PID}->{$dev}->{max}) {
						$result->{$Dev_Adapt}->{$PID}->{$dev}->{max}	=$load_sum;
						$result->{$Dev_Adapt}->{$PID}->{$dev}->{max_snap}=$snap;
						$result->{$Dev_Adapt}->{$PID}->{$dev}->{vremya}	=$snapshots->{$snap}->{ZZZZ}->{time};
					}
				if ($load_sum < $result->{$Dev_Adapt}->{$PID}->{$dev}->{min}) {
						$result->{$Dev_Adapt}->{$PID}->{$dev}->{min}		=$load_sum;
						$result->{$Dev_Adapt}->{$PID}->{$dev}->{min_snap}=$snap;
						$result->{$Dev_Adapt}->{$PID}->{$dev}->{min_vremya}	=$snapshots->{$snap}->{ZZZZ}->{time};
					}
				$result->{$Dev_Adapt}->{$PID}->{$dev}->{sum}+=$load_sum;
				$result->{$Dev_Adapt}->{$PID}->{$dev}->{count}++;
			};
			given ( $Dev_Adapt ) {
# Для подсчета требуются доп действия
				when (/DISKBUSY/) { 
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						next if ($load_sum <= "1") and ( $zero == "0"); # Пропускаем значения меньше единицы 
						&$avgsub($_); 
					}
				}
				when (/TOP/) { 
					foreach my $PID ( keys %{$load}) {
						foreach ( keys %{$load->{$PID}}) {
							$load_sum=$load->{$PID}->{$_};
							$result->{$Dev_Adapt}->{$PID}->{$_}->{avg}+=$load_sum and next if (! looks_like_number($load_sum));
							$load_sum=0 if ( $load_sum eq "");
							next if ($load_sum <= "0");
							&$TOPSUB($PID,$_) 
						}
					}
				}
# Если для подсчета не требуется дополнительных действий
				default {
					foreach ( keys %{$load}) {
						$load_sum=$load->{$_};
						# print "$Dev_Adapt - $_  - $load_sum\n" if (! defined $load_sum);
						$result->{$Dev_Adapt}->{$_}->{avg}=$load_sum and next if (! looks_like_number($load_sum));
						$load_sum=0 if ( $load_sum eq "");
						next if ($load_sum <= "0");
						&$avgsub($_); 
					}
				}
			}
		}
	}

# Postprocessing	
	foreach ( @twice_calc) {
		my $ref=$result->{$_};
		given ($_) {
			when (/pbuf/) {$result->{pbuf}{avg}=$tmp_ref->{pbuf}->{"pbuf_finish"} - $tmp_ref->{pbuf}->{"pbuf_begin"}} # Скоколько накапало за один день
		}
	}
	my $index=0;
	foreach ( @Custom_Metric) {
		my $ref=$result->{$_};
		given ($_) {
			when (/FCXFERTOTAL/){ $result->{$_}->{general}{$_}{avg}=eval(sprintf("%.2f", $result->{FCXFEROUT}{general}{FCXFEROUT}->{sum}	+	$result->{FCXFERIN}{general}{FCXFERIN}->{sum}));	}
			when (/FCTOTALGB/) 	{ $result->{$_}->{general}{$_}{avg}=eval(sprintf("%.2f",($result->{FCREAD}{general}{FCREAD}->{sum} 	+ 	$result->{FCWRITE}{general}{FCWRITE}-> {sum})/1048576));}
			when (/NETTOTALGB/)	{ $result->{$_}->{general}{$_}{avg}=eval(sprintf("%.2f",($result->{$_}{general}{$_}->{sum}/1048576)));}
			when (/SEATOTALGB/)	{ my $metrics=$_=~ s/^(.*)TOTALGB/$1/r; (skeep(\@Custom_Metric, $result,$metrics, $index) == 0 ) ?  $result->{$_}->{avg}=eval(sprintf("%.2f",($result->{$metrics}{general}{$metrics}->{sum}/1048576))) : next }
			when (/FCRATIORW/) 	{ # Сложить IO со всех адаптеров следующих метрик FCXFERIN и FCXFEROUT
					$result->{$_}->{general}{$_}{max}=eval(sprintf("%.2f",$result->{FCWRITE}{general}{FCWRITE}->{sum} * 100 /($result->{FCREAD}{general}{FCREAD}->{sum}+$result->{FCWRITE}{general}{FCWRITE}->{sum})));
					$result->{$_}->{general}{$_}{avg}=eval(sprintf("%.2f",100-$result->{$_}{general}{$_}->{max}));
			}
			when (/Entitled/) {
				$result->{$_}->{general}{$_}{avg}=$result->{Entitled_Capacity}
			}
		}
		$index++;
	}
	$index=0;
	foreach my $ind ( @INDICATORS){
		map  { (skeep(\@INDICATORS, $result->{$ind}{general},$_, $index) == 0 ) ? $result->{$ind}{general}{$_}->{"avg"}=eval(sprintf("%.2f",$result->{$ind}{general}{$_}->{"sum"} / $result->{$ind}{general}{$_}->{"count"})): next} keys %{$result->{$ind}{general}} ;
		$index++;
	} 
	$index=0;
	foreach my $Dev_Adapt ( @Dev_Adapt ){
		next if ( skeep(\@Dev_Adapt, $result, $Dev_Adapt, $index) == 1 );
		foreach (@{$result->{$Dev_Adapt}{a_cap}}) {
			next if (! looks_like_number($result->{$Dev_Adapt}{$_}{"avg"}));
			$result->{$Dev_Adapt}{$_}{"avg"}=eval(sprintf("%.2f",$result->{$Dev_Adapt}{$_}{sum} / $result->{$Dev_Adapt}{$_}{count}))
		}
		$index++;
	} 
# print Dumper($result);
print "Число обработанных строк $count\n" if ($bench == 1);

}

sub skeep {
	my $array=shift;
	my $ref=shift;
	my $metric=shift;
	my $index=shift;
	if (! exists $ref->{$metric}->{sum}) { 
		# splice(@{$array}, $index, 1);
		return 1
	}
	return 0;
}

sub server_strcture {
	# AAA
	# SerialNumber
	# XXXXXX
	# my $tmp=shift;
	# my $SerialNumber=$tmp =~ s/^AAA,SerialNumber,//r;
	# $SERVER{$SerialNumber}=();
	# printf "It's BBBL - @_ \n";
	...
}

sub lparname_structure{
	my $lparname=shift,	my $data=shift, my $SerialNumber=shift, my $LPAR=shift, my $filename=shift, my $cpus=shift;
	my %cpu,my %scpu,my %pcpu, my %lpar_stats;
	my %snapshots;
	my %result;
	my $count=1;
	my @ZZZZ=("time","date");

	$result{LPARNAME}=			$LPAR;
	$result{SN}=				$SerialNumber;
	$result{Data}=				$data=~ s/-//gr;
	$result{ID}=				"$result{Data}$LPAR";
	$result{FILENAME}=			$filename;
	$result{CPUS}=				$cpus;
	$result{ZZZZ}{a_cap}=		\@ZZZZ;
	$lparname->{SNAPSHOTS}=		\%snapshots;
	$lparname->{RESULT}=		\%result;

	return $lparname;
}

sub output { 
	# Индикатор, Порог Крит среднее, Предупреждение среднее, Критическое максимальное, критическое предупреждение, Префикс, постфикс
	(my $indicator, my $crit_avg, my $warn_avg, my $crit_max, my $warn_max, my $prefix, my $postfix, my $skip, my $skip_avg)= (@_); 
	my $avg=	$indicator->{avg};
	my $max=	$indicator->{max}||"0";
	my $snap=	$indicator->{max_snap};
	my $time=	$indicator->{time};
	my $vremya=	$indicator->{vremya};

	$skip_avg=$skip if (! defined $skip_avg); 


	if ( $CVS_FROMATE == $NO)
	{
		print "${delimetr}${prefix}(",	GREEN,	"$avg",	"$postfix",	RESET,")" and return 1 if (! looks_like_number($avg)); # if a word
		return 0 if ($avg < $skip_avg) and ($max < $skip) and ( $zero == "0"); # Не печатаем если стоит флаг skip или 0 значение и нету флага zero

		if 		($avg > $crit_avg)	{ print "${delimetr}${prefix}(", 	RED,	"$avg", "$postfix",	RESET }
		elsif 	($avg > $warn_avg)	{ print "${delimetr}${prefix}(", 	YELLOW,	"$avg", "$postfix",	RESET }
		else 						{ print "${delimetr}${prefix}(",	GREEN,	"$avg",	"$postfix",	RESET }
		if ( $max > "0") {
			if 		($max > $crit_max) 	{ print 			RED, 	"/$max","$postfix)",	RESET }
			elsif 	($max > $warn_max) 	{ print 			YELLOW, "/$max","$postfix)",	RESET }
			else 					 	{ print 			GREEN,  "/$max","$postfix)",	RESET }
		}else {print ")"}
		print "x$time" 	if ($SHOW_time		== $YES) 	and (defined $time 	);
		print "_$snap" 	if ($SHOW_SNAPSHOTS == $YES)	and (defined $snap 	);
		print "_$vremya"if ($SHOW_vremya	== $YES) 	and (defined $vremya);
		return 1
	} 
	# elsif ( $EXCEL_FORMATE ==$YES) { 
	# } 
	else {
		my $time=	$indicator->{time}||0;
		print ",$avg";
		return 0 if ($avg < $skip_avg) and ($max < $skip) and ( $zero == "0"); # Не печатаем если стоит флаг skip или 0 значение и нету флага zero
		print ",$max" if ($max > "0");
		print ",$time" 	if ($SHOW_time		== $YES) and  need_count($prefix);
	}
}
sub need_count{
	my $metric=shift;
	return 1 if ($metric eq "CPU_ALL");
	return 1 if ($metric eq "PCPU_ALL");
	return 1 if ($metric eq "LPAR");
	return 1 if ($metric eq "EC");
	return 1 if ($metric eq "PhysAlloc");
	return 1 if ($metric eq "PhysicalCPU");
	return 0;
}

sub save_cvs{
	my $INDICATORS=shift;
	my $twice_calc=shift;
	my $Dev_Adapt=shift;
	my $metrics=shift;
	# my $need_count = sub { };
######## Печатаем шапку
	print "Date,Serial,hostname";
	foreach my $ind (@{$INDICATORS}){ map {print ",avg-$_,max-$_"; print ",count" if $SHOW_time == $YES and need_count($_)	} keys %{$metrics->{$ind}->{general} } };
	map {print ",$_" } @{$twice_calc};
	foreach my $dev (@{$Dev_Adapt}) { map {print ",dev-avg-$_,dev-max-$_"	} sort @{$metrics->{$dev}->{a_cap}}};
	print "\n";
######################################################### 

# PhysicalCPU"
# PhysAlloc%
# EC
}

# Шаблоны ток для основных параметров
sub value_for_metricks {
	my %metrics=@_;
	# print Dumper(\%metrics);
	my $ind=	$metrics{IND};
	my $device=	$metrics{DEV}||"$ind";
	my $cpus=	$metrics{CPUS}||0;
	my $Entitled_Capacity=	$metrics{Entitled_Capacity}||0;
	# print "ind - $ind\tdevice - $device\tcpus - $cpus";
# Среднее критическое, Среднее предупреждение, Критическое максиммальное, Предупредение максимальное, префикс, постфикс, skip, skip_avg
# =========== CPU ================
	return("60", "50", ,"90", "60", "$device", 	"%",	"0"	)										if ( $ind eq "CPU_ALL"	);	
	return("60", "50", ,"90", "50", "$device",	"",	"0"	)											if ( $ind eq "LPAR" 	);
	return("60", "50", ,"90", "50", "$device",	"",	"0"	)											if ( $ind eq "EC" 		);
	return("100", "100", ,"200", "200", "$device",	"",	"0"	)										if ( $ind eq 'PhysAlloc%');
	return("60", "90", ,"40", "70", "$device",	"%",	"0"	)										if ( $ind eq "SCPU_ALL"	);
	return("60", "90", ,"40", "70", "$device",	" core","0"	)										if ( $ind eq "PCPU_ALL"	);
# =========== MEM ================
	return("80", "70", "80", "70", "$device", "%", "0"		)										if ( $ind eq "MEMNEW"	);
# =========== Page ===============
	return("512", "70", "512", "70", "$device", "MB", "0")											if ( $ind eq "PAGING"	);
# =========== Pbuf ===============
	return("1000", "70", "512", "70", "Pbuf", " IO blocks", "0")									if ( $ind eq "pbuf"		);
# =========== DISK ===============
	return("70",		"50",		"70",		"50",		"$device",	" %",	"60"		)		if ( $ind eq "DISKBUSY"	);
	return("100",		"50",		"15",		"5",		"$device",	" ms",	"1000", "10")		if ( $ind eq "DISKSERV"	);
	return("2",			"1",		"2",		"1",		"$device",	" ms",	"0.1"		)		if ( $ind eq "DISKWAIT"	);
	return("100000",	"100000",	"100000",	"100000",	"$device",	" IOs",	"0"			)		if ( $ind eq "DISKXFER"	);
	return("50000",		"25000",	"80000",	"25000",	"$device",	" KBs",	"0"			)		if ( $ind eq "DISKREAD"	);
	return("10000",		"8000",		"10000",	"8000",		"$device",	" KBs",	"0"			)		if ( $ind eq "DISKWRITE");
# =========== NET ===========
	return("2",		"1",	"2",	"1",	"$device",		" ms",	"0")							if ( $ind eq "NETERROR"	);
# =========== FC =================
	return("1400",	"600",	"1400",	"600",	"$device",		" IOs",	"0")							if ( $ind eq "FCXFERIN"	);
	return("1400",	"600",	"1400", "600",	"$device",		" IOs",	"0")							if ( $ind eq "FCXFEROUT");
	return("50000",	"25000","80000","25000","$device",		" KBs",	"0")							if ( $ind eq "FCREAD"	);
	return("100000","80000","100000","80000","$device",		" KBs",	"0")							if ( $ind eq "FCWRITE"	);
	return("1400",	"1000",	"1400",	"600",	"$device",		" IO",	"0")							if ( $ind eq "FCXFERTOTAL");
	return("1400",	"1000",	"1400",	"600",	"$device",		" GB",	"0")							if ( $ind eq "FCTOTALGB");
	return("100",	"100",	"100",	"100",	"Read/Write", 	" %",	"0")							if ( $ind eq "FCRATIORW");
# ============= IOADAPT ========================
	return("100000",		"80000",		"100000",	"80000",		"$device",	"",	"0"	)		if ( $ind eq "IOADAPT"	);
# ============= PROC ========================
	return($cpus/1.3,		$cpus/2,		$cpus/1.3,	$cpus/2,		"$device${cpus}",	"",	"0"	)		if ( $ind eq "PROC"	);
	
	return($Entitled_Capacity/1.3,		$Entitled_Capacity/2,		$Entitled_Capacity/1.3,	$Entitled_Capacity/2,		"$device(${Entitled_Capacity})",	"",	"0"	)		if ( $ind eq "PhysicalCPU"	);
# ============= Хотелось бы знать что именно пользователь хочет вывести, но мы не знаем, так что, просто нечего не раскрашиваем
	return("99999999999",	"99999999999",	"99999999999",	"99999999999",	"$device",	"",	"0");

}


# Новая версия вывода отчета , добавлена сортировка
sub report1{ 
	my $sorts=shift;
	my @new_arr;
	@new_arr=sort  { $b->{$SORTS} cmp $a->{$SORTS} } @{$sorts} 							if ($sort_num == 0); # SORTS - a DATA (string line)
	@new_arr=sort  { $b->{$SORTS}{general}{$SORTS1}{$sAVG_MAX} <=> $a->{$SORTS}{general}{$SORTS1}{$sAVG_MAX} } @{$sorts} 	if ($sort_num == 1); # SORTS - a global value , metric by sorting
	@new_arr=sort  { $b->{$SORTS}{$sAVG_MAX} <=> $a->{$SORTS}{$sAVG_MAX} } @{$sorts} 	if ($sort_num == 2); # PBUF
	my $was_shown_cover=$NO;
	my $show_cover_each_line=$NO;
	foreach (@new_arr) {
		my $count=1; # Число выведенных метрик
		# Стандартные значения которые должна содержать каждая LPAR
		my $ID=$_->{ID};
		my $sn=$_->{SN};
		my $date=$_->{Data};
		my $lparname=$_->{LPARNAME};
		##############################################
		my $lpar_ref=$_; # ссылка на LPAR
		my $cpus=$lpar_ref->{CPUS};
		my $Entitled_Capacity=$lpar_ref->{Entitled_Capacity};
		my %metrics; # Сылки на метрики
		my @full_array=(@INDICATORS, @twice_calc, @Dev_Adapt, @Custom_Metric);
		my @snapshots=(@INDICATORS, @Custom_Metric);
		# my @new_arr=(@Custom_Metric,@Dev_Adapt );
		my @keys=(keys %{$_});
		foreach (@full_array) {if ( $_ ~~ @keys ) {$metrics{$_}=$lpar_ref->{$_}}}

		if ($CVS_FROMATE==$YES and $was_shown_cover == $NO or $show_cover_each_line == $YES  ) {	
			save_cvs(\@INDICATORS,\@twice_calc, \@Dev_Adapt,\%metrics);  
			$was_shown_cover=$YES; 
		}
		print "$date";
		if ($CVS_FROMATE==$NO)	{print " $sn $lparname","\n"x$new_line_before_device,"${delimetr}"x$indent_metrics; } 
		else 					{print ",$sn,$lparname","\n"x$new_line_before_device;								}


		foreach ( @snapshots ) {
			next if ($_ eq "");
			# print $_;
			foreach my $general_ind (keys %{$metrics{$_}{general}}) {
				# print "__${count}__";
				print "\n","$delimetr"x$indent_metrics and $count=2 if ( $count++ > $max_on_line_snapsh);
				print ""; output($metrics{$_}{general}{$general_ind}, value_for_metricks(IND => $general_ind, CPUS => $cpus, Entitled_Capacity => $Entitled_Capacity))
				# print ""; output($metrics{$_}{general}{$general_ind}, value_for_metricks(IND => $general_ind, CPUS => $cpus))
				# if ($CVS_FROMATE==$NO) { print ""; output($metrics{$_}, value_for_metricks(IND => $_, CPUS => $cpus)) }
				# else { print_cvs($metrics{$_}) }
			}
		}

		foreach ( @twice_calc ) {
			next if ($_ eq "");
			print "\n","$delimetr"x$indent_metrics and $count=2 if ( $count++ > $max_on_line_snapsh);
			print ""; output($metrics{$_}, value_for_metricks(IND => $_, CPUS => $cpus, Entitled_Capacity => $Entitled_Capacity))
		}		
		# $count=0;
		foreach ( @Dev_Adapt ) {
			choice_indent($_);
			$count=1; 
			#  Делаем начальный отступ и пишем имя метрики
			my $device=$_;
			print "\n" if ($new_line_before_device == $YES) ;
			print "","$delimetr"x$indent_device, $device,":\n"x$new_line_before_device,"$delimetr"x$indent_device if ($CVS_FROMATE==$NO);
			my $result=undef;
			if ( exists ($metrics{$device}{"a_cap"}[0])) {
				foreach (sort ( @{$metrics{$device}{"a_cap"}})) {
					$result=output($metrics{$device}{$_}, value_for_metricks(IND =>$device, DEV => $_, CPUS => $cpus, Entitled_Capacity => $Entitled_Capacity));
					# else { $result=print_cvs($metrics{$device}{$_}); }
					print "\n","$delimetr"x$indent_device and $count=1 if ( ($count=$result + $count) > $max_on_line_dev);
				}
			} else { print "$delimetr"x$indent_device ,"0"}
			print "\n" if ($new_line_before_device == $YES) ;
		}
		print "\n";

	}
}

# my prepare_for_excel{

# }


sub parse_nmon{
	my @sorts;
	my $files= scalar @files;
	my $cc=1;
	foreach my $FILE_PATH (@files) {
		# system("clear");
		print "$FILE_PATH: Обработано файлов...............", $cc++, " из $files  \n" ;
		open(NMON, "<:utf8", "$FILE_PATH") or die "Can't open this file $!\n";
		my $filename=$FILE_PATH;
		$filename=~ s/.+\/(\w+_\w+).nmon/$1/;
		my $file=<NMON>;
		my $SerialNumber=0,	my $lparname=0,	my $data=0; # Данные о lpar
		# my %RESULT;
		my %lparname;
		my @head;
		my $PageSize=0,	my $DeviceName=0; # Page Space
		my $pbuf_begin=undef, my $pbuf_finish=undef;
		my $BBSEA;
		my $finished_gather=0;
		my $cpus;
		my $Entitled_Capacity;
		my $BBBL_gather_finished=$NO;
		my %BBBL;
 		if ($requiered_gather eq $YES ) { @INDICATORS=(); @twice_calc=(); @Custom_Metric=(); @Dev_Adapt=();	} # Each stap we clear array for new file if --gather 
 		create_regex; 
		my $tparse0, my $tparse1, my $tdparse 				if ($bench == 1);
		$tparse0 = Benchmark->new 							if ($bench == 1);
PARSE:	while (<NMON>) {
		    chomp;                  # no newline
		    if (!exists $SERVER{$data}{$SerialNumber}{$lparname}) {
			    $data=$_ 		 =~ s/^AAA,date,//r 																		and next PARSE	if /^AAA,date,/os;
			    $cpus=$_ 		 =~ s/^AAA,cpus,\d+,(\d+)/$1/r 																and next PARSE	if /^AAA,cpus,/os;
			    $SerialNumber=$_ =~ s/^AAA,SerialNumber,//r 																and next PARSE	if /^AAA,SerialNumber,/os;
				$lparname=$_ 	 =~ s/^AAA,NodeName,//r																		and
				$SERVER{$data}{$SerialNumber}{$lparname}=lparname_structure(\%lparname, $data, $SerialNumber, $lparname, $filename, $cpus,)	and next PARSE 	if /^AAA,NodeName,/os;
			}
			
			$SERVER{$data}{$SerialNumber}{$lparname}{RESULT}{CONFIG}{HARDWARE}{"$1"}{"$3"}=$5 and next PARSE if /^(BBBL),(\w+),(\w+(\s+\w+)*?),(\d+(.\d)*)/;

			# Данные о размере Paging Space
			if ($PageSize eq 0) {
				if ( /^BBBP,\d+,lsps -a,"(hd\d+)\s+hdisk\d{1,3}\s+rootvg\s+(\d+)MB.*/os ) {
					($DeviceName, $PageSize)=($1,$2);
					$SERVER{$data}{$SerialNumber}{$lparname}{"TMP"}{"PageSize"}=	$PageSize;
					$SERVER{$data}{$SerialNumber}{$lparname}{"TMP"}{"DeviceName"}=	$DeviceName||"hd6";
					next PARSE;
				}
			}

			# Сбор данных по PBUF
			if ( ! defined $pbuf_begin ) {
				if (/^BBBP,\d+,vmstat\s-v,\"\s+(\d+)\spending disk I\/Os blocked with no pbuf\"/os) {
					$pbuf_begin=$1;
					$SERVER{$data}{$SerialNumber}{$lparname}{"TMP"}{"pbuf"}{"pbuf_begin"}=$pbuf_begin;
					next PARSE;
				}
			}
			if ($finished_gather == $NO and $requiered_gather == $YES) {
				# next PARSE if (/^ZZZZ/);
		    	if  (! (/^(AAA|BBB|ZZZZ|UARG)/) ) 	{structure_create(\%lparname,  $_, 1); 	}
		    	if  (/ZZZZ,T0001/)	{
			    	$finished_gather=1; 
					push(@INDICATORS, @indicator_all);
					push(@Custom_Metric, @custom_all);
					push(@twice_calc, @twice_calc_all);
		    		create_regex;		
		    	}
		    	else 
		    	{ next PARSE }
			}
			# Сбор snapshots, выполняется только после того как создана структура
			
		    if  ( /^($regex)/os) {
		    	# print $_,"\n";
				if 		( /^\w+\d{0,2},(T\d?|\d+,T\d?)/os 		)	{fill_structure		(\%lparname,  $_)	}
				elsif 	( ! /^(AAA|\w+\d{0,2},(T\d?|\d+,T\d?))/os)	{structure_create	(\%lparname,  $_)	}
				next PARSE;
		 	}
			if ( ! defined $pbuf_finish ) {
				if (/^BBBP,\d+,ending\svmstat\s-v,\"\s+(\d+)\spending disk I\/Os blocked with no pbuf\"/os) {
					$pbuf_finish=$1;
					$SERVER{$data}{$SerialNumber}{$lparname}{"TMP"}{"pbuf"}{"pbuf_finish"}=$pbuf_finish;
					next PARSE;
				}
			}			
		} 
		# print Dumper($lparname{CONFIG}) and exit 0;
																								$tparse1 = Benchmark->new 								if ($bench == 1);
																								$tdparse = timediff($tparse1, $tparse0) 				if ($bench == 1);
																								print "PARSE NMON Files",timestr($tdparse),"\n" 		if ($bench == 1);


																								my $tcalc0, my $tcalc1, my $tdcalc 						if ($bench == 1);
																								$tcalc0 = Benchmark->new 								if ($bench == 1);

# print Dumper(\%lparname);
		search_value(\%lparname);
		close NMON or warn $! ? "Error closing sort pipe: $!" : "Exit status $? from sort";
		undef $lparname{SNAPSHOTS};

																								$tcalc1 = Benchmark->new  								if ($bench == 1);
																								$tdcalc = timediff($tcalc1, $tcalc0)  					if ($bench == 1);

																								print "Расчет всех снепшотов:",timestr($tdcalc),"\n"  	if ($bench == 1);

																								my $tpush0, my $tpush1, my $tdpush  					if ($bench == 1);
																								$tpush0 = Benchmark->new  								if ($bench == 1);

		push(@sorts, $lparname{RESULT});

																								$tpush1 = Benchmark->new  								if ($bench == 1);
																								$tdpush = timediff($tpush1, $tpush0)  					if ($bench == 1);
																								print "push NMON Files",timestr($tdpush),"\n"  			if ($bench == 1);
																								my $size_dev=scalar @Dev_Adapt  						if ($verbose == 1);
																								my $size_ind=scalar @INDICATORS  						if ($verbose == 1);
																								print "Размер @Dev_Adapt = $size_dev\n"  				if ($verbose == 1);
																								print "Размер @INDICATORS = $size_ind\n"  				if ($verbose == 1);
																								print "\n"												if ($verbose == 1);
	}
	return @sorts;
}

																								$tinit_fin = Benchmark->new  									if ($bench == 1);
																								$tdif_init = timediff($tinit_fin, $tinit)  						if ($bench == 1);
																								print "Time to prepare",timestr($tdif_init),"\n" 				if ($bench == 1);


#_____________________________________MAIN_____________________________________________#
{
	# Создаем массив файлов
	# my (@files)=@ARGV;

	my @sorts;
	@sorts=parse_nmon 		if (@files);
	@sorts=open_json 		if (@json);
	print Dumper(\@sorts) 	if ($dump==1);
	save_json(\@sorts) 		if ($requiered_gather==$YES);
	if ($verbose == 1) {
		print "Настройки сортировки:","\n";
		print "\t","Sorts - $SORTS","\n\t", "sAVG_MAX = $sAVG_MAX","\n";
		print "Настройки Форматирования:","\n";
		print "\t","new_line_before_device = $new_line_before_device", "\n\t", "indent_device = $indent_device", "\n\t", "max_on_line_snapsh = $max_on_line_snapsh", "\n\t", "indent_metrics = $indent_metrics\n";
		print "Выбранные метрики:","\n";
		print "\t","INDICATORS = @INDICATORS","\n\t", "twice_calc = @twice_calc","\n\t", "Dev_Adapt = @Dev_Adapt","\n\t", "Custom_Metric = @Custom_Metric","\n";
	}

# my $treport = Benchmark->new  									if ($bench == 1);
	report1(\@sorts) 		if ($requiered_gather==$NO);


}
$tfinished = Benchmark->new  									if ($bench == 1);
$tdfinished = timediff($tfinished, $tstart)  					if ($bench == 1);
print "Finished, time to waste",timestr($tdfinished),"\n\n" 	if ($bench == 1);



__END__

=encoding utf-8
=head1 NAME

sample - Простой парсер NMON файлов

=head1 SYNOPSIS

Example: check_perf.pl -f /path/to/dir/file* -s LPAR -t general --dump 

=head1 OPTIONS
   -help           brief help message
   -man            full documentation
   -files -f       Список NMON которые необходимо проверить. К примеру /NMON/18021[678]/* 
   -json  -j       Список JSON которые необходимо проверить. К примеру /JSON/18021[678]/* 
   -sort           Выбор столбца для сортировки. По умолчанию LPAR
   -type           Набор шаблонов для сбора статистики. По умолчанию general
   -dump           Вывод готового хеша содержащий данные прошедшие сортировку и парсинг.  


=head1 DESCRIPTION

Скрипт для быстрого анализа NMON файлов. Парсит и B<вывод> метрики по определенным параметрам.

=cut

=head2 OPTIONS

	-help -h 			brief help message

	-man 				full documentation

	-files				Список NMON которые необходимо проверить. К примеру /NMON/18021[678]/* 

	-json -j			Список JSON которые необходимо проверить. К примеру /JSON/18021[678]/* 

	-sort -s			Выбор столбца для сортировки. По умолчанию LPAR. 
					Предопределенные типы сортировки: LPAR,CPU,MEM,pagesp,pbuf,DISKSERV,FCRATIORW,time,serial,name,SCPU,PCPU,DISKBUSY,DISKWAIT,DISKXFER,FCXFERIN,FCXFEROUT,FCREAD,FCWRITE,FCXFERTOTAL
					Если в качестве шаблона используются adv, то можно указать любой тип сортировки из собираемых данных

	-type -t 			Набор шаблонов для сбора статистики. По умолчанию general.
					Доступные шаблоны:
					neterror 	- Вывод ошибок на сетевых интерфейсах. Возможно доверять этим данным не стоит.
					general 	- Вывод метрик по LPAR CPU PAGING MEM.
					disk 		- Вывод метрик по FCTOTALGB FCRATIORW. 
					adv 		- Не использовать шаблон, задать параметры вручную. Параметры задаются через -id , -dev, -cu

	-dump				Вывод готового хеша содержащий данные прошедшие сортировку и парсинг.  

	-cvs 				Вывод в CVS формате.

	-F 				Разделитель столбцов.

	-dev -device 			Выбор пользовательских метрик типа Dev_Adapt. Необходим ключ -t adv.

	-id -identificator		Выбор пользовательских метрик типа identificator. Необходим ключ -t adv.

	-cu -custom 			Выбор пользовательских метртк типа custom.

	-zero 				Выводить все значения метрик, даже если они ровны 0 или меньше порогового значения.

	-no_new-line -nonl		Все метрики типа Dev_Adapt выводить с новой строки.

	-md 				Количество метрик типа Dev_Adapt в одной строке.

	-ms 				Количестов метрик типа INDICATORS в одной строке.

	-verbose			Подробный вывод.

	-bench 				Benchmarks.

	-gather 			Сбор статистики по всем метрикам которые есть в файле NMON и сохранение их в текущию(./) дирикторию.


	На основе NMON файла скрипт создает 4 типа данных которые хранятся в следующих массивах:
	@twice_calc - Данный массив создан для хранения и обработки метрик которые собираются дважды в начале файле и в конце файла. В NMON файле они хранятся за тегами BBBP

	@Dev_Adapt	- Данный массив хранит значения всех показателей одного индикатора. К примеру если в NMON файле есть индикатор FCREAD, который собирает данные с 4 адаптеров(fc0,fc1,fc2,fc3), 	
	тогда - статистика будет расчитываться для каждого отдельного показателя.

	@INDICATORS	- Данный массив хранит метрику являющимся средним значением суммы всех показатлей какого либо индикатора. К примеру если в NMON файле есть индикатор FCREAD,
	который собирает данные с 4 адаптеров(fc0,fc1,fc2,fc3), то статистика будет расчитываться от суммы всех четырех адаптеров. 
	Так же, для метрик из данного массива могут быть выполнены все операции требующие нестандартных операций на обработке каждого снепшота.  
	К примеру, 	есть метрика MEMNEW, которая для каждого снепшота выполняет следующее 'when (/^MEMNEW/)	{ $load_sum=100 - $load->{"Free%"} - $load->{"FScache%"}; &$avgsub}'

	@Custom_Metric - Данный массив хранит метрики которые рассчитываются после обработки всех снепшотов к примеру: FCRATIORW - на основе рассчитанных метрик FCREAD FCWRITE расчитывает соотношения операций чтение\запись на диск,  
	FCTOTALGB и FCXFERTOTAL считает общий объем трафика в GB и IO запросах.


=cut
