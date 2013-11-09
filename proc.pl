#!/usr/bin/perl
use Getopt::Std;
getopts("p:w:",\%options);

if(!defined $options{p})
{
	print "Error startup program. Read file README.\n";
	exit;
}

#инициализация
@memory = (); #память
$ip = 0; #указатель команд
$regcom = 0; #регистр команд
$ir = 0; #индексный регистр
$prznk = 0; #признак. Входит в состав RON
$CYM = 0; #Содержимое регистра общего назаначения
$COUNT = 96; #сколько первых байт при выводе памяти надо выводить
%signal = (
	pusk => 1,
	vzap1 => 0,
	zam1 => 0,
	zam2 => 0,
	chist => 0,
	op => 0,
	vyb => 0,
	zapp => 0,
	pereh => 0
); # hash сигналов

#загрузка информации о целостноти проводов.
%wires =(
	pusk => 1,
	vzap1 => 1,
	zam1 => 1,
	zam2 => 1,
	chist => 1,
	op => 1,
	vyb => 1,
	zapp => 1,
	pereh => 1,
	adrcom => 1,
	kop => 1,
	a => 1,
	kom => 1,
	ind => 1,
	cym => 1,
	prznk =>1,
	rez1 => 1,
	pr => 1,
	ia => 1,
	sp => 1,
	mult_vyb => 1,
	mult_chist => 1,
	mult_pereh =>1
); #продода

if(defined $options{w})
{
	open(G,'<',$options{w}) or die "couldn't open file $options{w}\n";
	while(<G>)
	{
		$wires{$1} = $2 if(/^\s*(.+)\s+([01])\s*$/);
	}
}
close(G);

#загрузка программы в память
open (F,'<',$options{p}) or die "couldn't open file $options{p}\n";
while(<F>)
{
	push @memory, hex foreach(/\w{1,2}/g);
}
close(F);

push @memory,0 foreach($#memory...65535);
my $IA = 0, $SP = 0;

#логика работы процессора
while($signal{pusk} && $wires{pusk})
{
	$regcom = $ip if($wires{adrcom} && $wires{kom});
	inc_ip() if($wires{adrcom});
	deccom($memory[$regcom],$prznk) if($wires{kop} && $wires{prznk});
	$IA = addAdrIR(($memory[$regcom+1] << 8) + $memory[$regcom+2]) if($wires{ind} && $wires{a});
	$SP = ($memory[$IA] << 8) + $memory[$IA+1] if($wires{ia}); 
	@res_alu = alu(mult($SP * $wires{sp},$IA*$wires{ia},($signal{vyb} * $wires{vyb})),$CYM) if($wires{cym} && $wires{mult_vyb});
	$ir = mult(($res_alu[0] * $wires{rez1}),0,($signal{chist} * $wires{chist})) if($wires{zam2} && $signal{zam2});
	($CYM,$prznk) = @res_alu if($wires{zam1} && $signal{zam1});
	if($wires{zapp}&& $wires{rez1} && $wires{ia} && $signal{zapp})
	{
		my $prom = $CYM;
		$memory[$IA] = ($prom >> 8);
		$memory[$IA+1] = ($prom & 0xff);
	}
	$ip = mult($ip,$IA*$wires{ia},($signal{pereh}*$wires{pereh}));
}

print_result();

sub inc_ip()
{
	$ip += 3;
}

sub deccom($,$)
{
	my ($cop,$prz) = @_;
	$signal{op} = $wires{op} * ($cop >> 4);
	my ($i,$p) = ($signal{op} != 0xf) ? (($cop & 0xc),($cop & 0x3)):(0,4);
	$signal{pusk} = ($cop != 0xFF) ? 1:0;
	$signal{vzap1} = ($p == 3) ? 1:0;
	$signal{zam1} = ($p == 1) ? 1:0;
	$signal{zam2} = ($p != 3) ? 1:0;
	$signal{chist} = (!($p==2 || $p == 3)) ? 1:0;
	$signal{vyb} = $i;
	$signal{zapp} = ($p == 0) ? 1:0;
	$signal{pereh} = (($cop == 0xfe) || 
		(($cop == 0xf0) && (($prz & 2) == 0)) ||
			(($cop == 0xf1) && (($prz & 1) == 1))) ? 1:0;
}
sub addAdrIR($)
{
	return $ir + $_[0]; 
}
sub mult($,$,$)
{
	return ($_[2] == 0) ? $_[0]:$_[1];
}
sub alu($,$)
{
	my $result = ($signal{op} == 0) ? $_[1] : 
	($signal{op} == 1) ? $_[0]:
		($signal{op} == 2) ? $_[0] + $_[1] : 
			($signal{op} == 3) ? $_[1] - $_[0] : 
				$_[0] ;
	my $pr = ($result == 0) ? 1 :
		($result > 0) ? 2 : 3;
	return ($result,$pr);
}
sub print_result
{
	print "\n\n----Result----\n\n";
	print "RON: CYM: ",sprintf("%04X",$CYM),"; PRZNK: ",sprintf("%02b",$prznk),"\n";
	print "IR: ",sprintf("%04X",$ir),"\n";
	print "IP: ",sprintf("%04X",$ip),"\n";
	print "Memory:";
	foreach $i (0..($COUNT-1))
	{

		print "\n",sprintf("%05X",$i).' 'x4 if(!($i&0xf));
		print sprintf("%02X",$memory[$i]).' ';
	}
	print "\n\n--------------\n\n";
}