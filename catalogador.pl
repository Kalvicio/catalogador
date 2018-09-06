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

my $debug = 10000000;


my $reIPv4 = qr/(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))/i;
my $reDominio = qr/(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])/;

use constant _LP => 'lp'; 
use constant _RUTA => 'ruta';
use constant _RUTA_DEST => 'ruta_dest';
use constant _REMOTO => 'remoto';
use constant _REMOTO_DEST => 'remoto_dest';
use constant _USUARIO => 'usr';
use constant _PASSWORD => 'pwd';
use constant _PM => 'pm';


use constant _VD_LPD_L => 100;
use constant _VD_LPD_R => 20;
use constant _VD_PM => '/mnt';

my %klv_argumentos;

$klv_argumentos{&_LP} = _VD_LPD_R; # Límite max de procesos simultáneos
$klv_argumentos{&_RUTA} = undef; # Ruta a procesar
$klv_argumentos{&_RUTA_DEST} = undef; # Ruta de destino
$klv_argumentos{&_REMOTO} = undef; # Indica si la ruta es remota (1) o local (otro valor)
$klv_argumentos{&_REMOTO_DEST} = undef; # Indica si la ruta es remota (1) o local (otro valor)
$klv_argumentos{&_USUARIO} = undef; # Usuario de computador remoto
$klv_argumentos{&_PASSWORD} = undef; # Password del computador remoto
$klv_argumentos{&_PM} = _VD_PM; # Punto de montaje


say "Procesar argumentos" if $debug >= 100;
foreach my $arg (@ARGV){
  my ($clave, $valor) = split(/\=/, $arg);
  $clave =~ s/^[\s]+|[\s]+$//igs;
  $clave =~ s/^\-//igs;
  $clave =~ s/^[\s]+|[\s]+$//igs;

  $valor =~ s/^[\s]+|[\s]+$//igs;
  $valor =~ s/^\'|\'$//igs;
  $valor =~ s/^[\s]+|[\s]+$//igs;
  
  $clave = lc($clave);
  say $clave." = ".$valor if $debug >= 1000;
  if(exists($klv_argumentos{$clave})){
    if($clave eq _RUTA){
      $valor =~ s/\\/\//igs;
      $valor =~ s/\/$//igs;
      $klv_argumentos{&_RUTA} = $valor;
      if($valor =~ /\/\/($reIPv4|$reDominio)/igs ){
        $klv_argumentos{&_REMOTO} = 1;
      }elsif(-e $valor){
        $klv_argumentos{&_REMOTO} = 0;
      }else{
        $klv_argumentos{&_RUTA} = undef;
        $klv_argumentos{&_REMOTO} = undef;
      }
    }

    if($clave eq _RUTA_DEST){
      $valor =~ s/\\/\//igs;
      $valor =~ s/\/$//igs;
      $klv_argumentos{&_RUTA_DEST} = $valor;
      if($valor =~ /\/\/($reIPv4|$reDominio)/igs ){
        $klv_argumentos{&_REMOTO_DEST} = 1;
      }elsif(-e $valor){
        $klv_argumentos{&_REMOTO_DEST} = 0;
      }else{
        $klv_argumentos{&_RUTA_DEST} = undef;
        $klv_argumentos{&_REMOTO_DEST} = undef;
      }
    }

    if($clave eq _LP){
      if(($valor > 0)){
        $klv_argumentos{&_LP} = $valor;
      }else{
        $klv_argumentos{&_LP} = _VD_LPD_R;
      }
    }

    if($clave eq _USUARIO){
      $klv_argumentos{&_USUARIO} = $valor;
    }
    if($clave eq _PASSWORD){
      $klv_argumentos{&_PASSWORD} = $valor;
    }
    if($clave eq _PM){
      $klv_argumentos{&_PM} = $valor;
    }

  }
}


say Dumper(\%klv_argumentos);



#sleep (int(rand(120)));
if(defined($klv_argumentos{&_RUTA})){
  say "procesar!";
}





my ($user, $system, $child_user, $child_system) = times;
say "++++++++++++++\n",
    "+ FINALIZADO +\n",
    "++++++++++++++" if $debug >= 1;
say "Tiempo: ".&formatearTiempo(Time::HiRes::tv_interval($tiempoInicial)) if $debug >= 1;
say "Tiempo de usuario para $$ fue $user\n",
    "Tiempo de sistema para $$ fue $system\n",
    "Tiempo de usuario para todos los procesos hijos fue $child_user\n",
    "Tiempo de sistema para todos los procesos hijos fue $child_system" if $debug >= 100;

my $t1 = Benchmark->new;
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