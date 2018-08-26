#!perl
END { print "Tiempo de Ejecución: ", time() - $^T, " segundos\n" }
$|=1;
use strict;
use warnings;
use Time::HiRes;
use POSIX;
use Data::Dumper;

my $tiempoInicial = [Time::HiRes::gettimeofday()]; # Inicializamos el contador de tiempo

sleep (int(rand(120)));


my ($user, $system, $child_user, $child_system) = times;
print "Tiempo de Ejecución: ".&formatearTiempo(Time::HiRes::tv_interval($tiempoInicial))."\n";
    #"user time for $$ was $user\n",
    #"system time for $$ was $system\n",
    #"user time for all children was $child_user\n",
    #"system time for all children was $child_system\n";

exit(0);

sub formatearTiempo {
  my $tiempoTotal = shift;
  my ($tiempoEnSegundos, $microsegundos) = split(/\./,$tiempoTotal);
  return sprintf "%d días, %d horas, %d minutos y %d.%s segundos (%s)",(gmtime $tiempoEnSegundos)[7,2,1,0],$microsegundos, $tiempoTotal;
  #return sprintf "%d días, %d horas, %d minutos y %f segundos\n",(gmtime $tiempoEnSegundos)[7,2,1,0];
}


1;
