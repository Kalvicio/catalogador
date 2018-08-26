#!perl
END { print "Tiempo de Ejecución: ", time() - $^T, " segundos\n" }
$|=1;
use strict;
use warnings;
use Time::HiRes;
use POSIX;

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
  my $tiempoLegible = $tiempoTotal;
  my @unidadesDeMedida = (1,60,60,24);
  my @unidadesDeMedidaSigla = ('seg','min','hora','día');
  my $indice = 0;

  my ($segundoTotal, $microsegundos) = split(/\./, $tiempoTotal);
  if($segundoTotal > 0){
    foreach my $unidad (@unidadesDeMedida) {
      if($segundoTotal >= $unidad){
        $segundoTotal = floor($segundoTotal / $unidad);
print "Ind: ".$indice." - ".$segundoTotal."\n";
        if($indice == 0){
          $tiempoLegible = $segundoTotal.".".$microsegundos." ".$unidadesDeMedidaSigla[$indice].".";
        }else{
          $tiempoLegible = $segundoTotal." ".$unidadesDeMedidaSigla[$indice].", ".$tiempoLegible;
        }
      }else{
        $segundoTotal = 0;
      }
      $indice++;
    }
  }else{
    $tiempoLegible = "0.".$microsegundos." ".$unidadesDeMedidaSigla[$indice].".";
  }
  
  $tiempoLegible = $tiempoLegible." (".$tiempoTotal.")";

  return $tiempoLegible;
}


1;
