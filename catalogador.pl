#!perl
$|=1;
use strict;
use warnings;
use 5.012;
use Time::HiRes;
use POSIX;
use Data::Dumper;
use Benchmark qw(:hireswallclock);
use Benchmark::Forking;

my $t0 = Benchmark->new;
my $tiempoInicial = [Time::HiRes::gettimeofday()]; # Inicializamos el contador de tiempo

my $debug = 10000;

use constant _LP => 'lp';

my %klv_argumentos;

$klv_argumentos{_LP} = 20;  # Límite max de procesos simultáneos

foreach my $arg (@ARGV){
  #print $arg."\n";
  my ($clave, $valor) = split(/\=/, $arg);
  $clave =~ s/^[\s]+|[\s]+$//igs;
  $clave =~ s/^\-//igs;
  $clave =~ s/^[\s]+|[\s]+$//igs;

  $valor =~ s/^[\s]+|[\s]+$//igs;
  $valor =~ s/^\'|\'$//igs;
  $valor =~ s/^[\s]+|[\s]+$//igs;
  
  $clave = lc($clave);
  
  if(exists($klv_argumentos{$clave})){
    if($clave == _LP){
      if(!($valor > 0)){
        $valor = 20;
      }
    }
    $klv_argumentos{$clave} = $valor;
    #print "Clave: ".$clave." - Valor: ".$valor."\n";
  }
}



sleep (int(rand(120)));





my $t1 = Benchmark->new;
my ($user, $system, $child_user, $child_system) = times;
say "++++++++++++++\n",
    "+ FINALIZADO +\n",
    "++++++++++++++";
say "Tiempo: ".&formatearTiempo(Time::HiRes::tv_interval($tiempoInicial)) if $debug >= 100;
say "Tiempo de usuario para $$ fue $user\n",
    "Tiempo de sistema para $$ fue $system\n",
    "Tiempo de usuario para todos los procesos hijos fue $child_user\n",
    "Tiempo de sistema para todos los procesos hijos fue $child_system" if $debug >= 100;

my $td = timediff($t1, $t0);
say "Tiempo: ", timestr($td), if $debug >= 100;

exit(0);

###### Funciones

sub formatearTiempo {
  my $tiempoTotal = shift;
  my ($tiempoEnSegundos, $microsegundos) = split(/\./,$tiempoTotal);
  return sprintf "%d días, %d horas, %d minutos y %d.%s segundos (%s)",(gmtime $tiempoEnSegundos)[7,2,1,0],$microsegundos, $tiempoTotal;
}

sub in_array {
  my ($arr,$search_for) = @_;
  foreach my $value (@$arr) {
    return 1 if $value eq $search_for;
  }
  return 0;
}


1;