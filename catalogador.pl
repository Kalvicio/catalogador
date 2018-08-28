#!perl
END { print "Tiempo de Ejecución: ", time() - $^T, " segundos\n" }
$|=1;
use strict;
use warnings;
use Time::HiRes;
use POSIX;
use Data::Dumper;
use Benchmark qw(:hireswallclock);
use Benchmark::Forking;


my $t0 = Benchmark->new;


  my $debug = 1;
  my $tiempoInicial = [Time::HiRes::gettimeofday()]; # Inicializamos el contador de tiempo
  my %argumentos;

  foreach my $arg (@ARGV){
    #print $arg."\n";
    my ($clave, $valor) = split(/\:/, $arg);
    $clave =~ s/^[\s]+|[\s]+$//igs;
    $clave =~ s/\-|//igs;
    $clave =~ s/^[\s]+|[\s]+$//igs;

    $valor =~ s/^[\s]+|[\s]+$//igs;
    
    $clave = lc($clave);
    
    if($clave =~ /^o$|^p$|^t$|^s$|^h$|^help$/igs){
      $argumentos{$clave} = $valor;
      #print "Clave: ".$clave." - Valor: ".$valor."\n";
    }
  }



  sleep (int(rand(120)));


  #my ($user, $system, $child_user, $child_system) = times;
  print "Tiempo de Ejecución: ".&formatearTiempo(Time::HiRes::tv_interval($tiempoInicial))."\n";
      #"user time for $$ was $user\n",
      #"system time for $$ was $system\n",
      #"user time for all children was $child_user\n",
      #"system time for all children was $child_system\n";

my $t1 = Benchmark->new;
my $td = timediff($t1, $t0);

print Dumper(\$td);

print "Tiempo: ", timestr($td),"\n";

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