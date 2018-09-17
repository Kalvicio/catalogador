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

use File::Spec::Functions;
use File::MimeInfo;
use File::Copy;
use File::Path;




my $t0 = Benchmark->new;
my $tiempoInicial = [Time::HiRes::gettimeofday()]; # Inicializamos el contador de tiempo

my $debug = 10000000;


my $reIPv4 = qr/(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))/i;
my $reDominio = qr/(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])/;
my $reExtraerRuta = qr/(.+)?([\/])([^\/]+)([\.])([^\.]+)$/;

use constant _LP => 'lp'; 
use constant _RUTA => 'o';
use constant _RUTA_DEST => 'd';
use constant _RUTA_DEST_RW => 'rw';
use constant _RUTA_DEST_BASE => 'base';
use constant _REMOTO => 'or';
use constant _REMOTO_DEST => 'dr';
use constant _USUARIO => 'usr';
use constant _PASSWORD => 'pwd';
use constant _PM => 'pm';
use constant _RENOMBRAR => 'rn';


use constant _VD_LPD_L => 100;
use constant _VD_LPD_R => 20;
use constant _VD_PM => '/mnt';
use constant _VD_RW => '/__procesado'; # Ruta de Trabajo
use constant _VD_RW_BASE => '/original'; # Ruta de Trabajo


my $reExtIgnorarTmp = '\.db$|\.nometanoexif$';
my $reExtIgnorar = qr/$reExtIgnorarTmp/;



my %klv_argumentos;
my %listaDeArchivos;

$klv_argumentos{&_LP} = _VD_LPD_R; # Límite max de procesos simultáneos
$klv_argumentos{&_RUTA} = undef; # Ruta a procesar
$klv_argumentos{&_RUTA_DEST} = undef; # Ruta de destino
$klv_argumentos{&_REMOTO} = undef; # Indica si la ruta es remota (1) o local (otro valor)
$klv_argumentos{&_REMOTO_DEST} = undef; # Indica si la ruta es remota (1) o local (otro valor)
$klv_argumentos{&_USUARIO} = undef; # Usuario de computador remoto
$klv_argumentos{&_PASSWORD} = undef; # Password del computador remoto
$klv_argumentos{&_PM} = _VD_PM; # Punto de montaje
$klv_argumentos{&_RENOMBRAR} = undef; # Extensión o tipo de archivo para renombrar


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
      $klv_argumentos{&_RUTA} = catfile($valor);
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
      $klv_argumentos{&_RUTA_DEST} = catfile($valor);
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
    if($clave eq _RENOMBRAR){
      my @temp = split(/[,]/,$valor);
      foreach (@temp){
        $klv_argumentos{&_RENOMBRAR}{lc($_)} = lc($_);
      }
    }
  }
}






#sleep (int(rand(120)));
if(defined($klv_argumentos{&_RUTA})){
  my $error = 1;
  if(!defined($klv_argumentos{&_RUTA_DEST})){
    $klv_argumentos{&_RUTA_DEST} = $klv_argumentos{&_RUTA};
    $klv_argumentos{&_RUTA_DEST_RW} = $klv_argumentos{&_RUTA_DEST}._VD_RW;
    $klv_argumentos{&_RUTA_DEST_BASE} = $klv_argumentos{&_RUTA_DEST_RW};
    $error = &crearDirectorio($klv_argumentos{&_RUTA_DEST_BASE});

    $klv_argumentos{&_RUTA_DEST_BASE} = $klv_argumentos{&_RUTA_DEST_BASE}._VD_RW_BASE;
    $error = &crearDirectorio($klv_argumentos{&_RUTA_DEST_BASE});

    if($klv_argumentos{&_REMOTO} == 0){
      $klv_argumentos{&_LP} = _VD_LPD_L;
      $klv_argumentos{&_REMOTO_DEST} = 0;
    }
  }


  
  
  say "Error: ".$error;
  if($error == 0){
say Dumper(\%klv_argumentos);
    say "procesar!";
    eval {
      my %listaDeArchivos;
      %listaDeArchivos = &recorrerDirectorioLista($klv_argumentos{&_RUTA});
      if(scalar(keys %listaDeArchivos) > 0){
        &procesarArchivos(\%listaDeArchivos);
      }
    };
    if($@){
      say Dumper(\$@);
    }
  }
  
  
}
say Dumper(\%klv_argumentos);





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

sub crearDirectorio {
  my $ruta = shift;
  my $error = 0;
	my $intentoMkDir = 0;
  while($intentoMkDir <= 3 && !(-e $ruta)){
    $intentoMkDir++;
    if (!(-e $ruta)) {
      system("sudo mkdir '".$ruta."'");
      system("sudo chmod 777 '".$ruta."'");
      $error = 0;
    }
  }
  if($intentoMkDir > 3){
    $error = 1;
  }
	
  return $error;
}

sub recorrerDirectorioLista {
	my $directorio  = shift;
  #my %listaDeArchivos;
	eval {
		if($directorio !~ /\/$/igs){
			$directorio .= "/";
		}
    #&comprobarDirectorio($directorio);
		
		my $indice = 0;

		if($directorio ne $klv_argumentos{&_RUTA_DEST_RW}.'/'){
			if(opendir DIR, $directorio){
				say "R: ".$directorio if $debug >= 100;
				my @archivos = readdir DIR;
				close   DIR;
				my $archivoCantidad = scalar(@archivos);
				my $archivoIndicePadding = length($archivoCantidad);
				foreach my $archivo (sort { lc($a) cmp lc($b) } @archivos) {
					next if $archivo eq "."  or  $archivo eq "..";

					my $fichero = $directorio.$archivo;
					if (-f $fichero) {
						#if($fichero =~ /([^\.]+)$/igs){
            #say $fichero if $debug >= 1000;
						if($fichero !~ /$reExtIgnorar/igs){
               if($fichero =~ /$reExtraerRuta/igs){
                my $info = '';
                $indice++;
                my $archivoTamano = -s $fichero;
                if($archivoTamano > 0){
                  my ($mime_type, $mime_ext) = split('/',mimetype($fichero));
                  $mime_type = lc(trim($mime_type));
                  if(length($mime_type) <= 0){
                    $mime_type = 'misc';
                  }
                  my $error = &crearDirectorio($klv_argumentos{&_RUTA_DEST_BASE}.'/'.$mime_type);
                  if($error == 0){
                    $listaDeArchivos{$archivoTamano.'_-_'.$fichero}{$mime_type}{$fichero} = $fichero;
                  }
                  
                  #say "++ ".$fichero." ".$mime_type if $debug >= 1000;
                }else{
                  #say "-0 ".$fichero if $debug >= 1000;
                  &eliminar($fichero);
                  unlink $fichero;
                }
              }else{
                #say "-- ".$fichero if $debug >= 1000;
              }
						}else{
              #say "-t ".$fichero if $debug >= 1000;
							&eliminar($fichero);
							unlink $fichero;
						}
					}
					elsif (-d $fichero) {
						&recorrerDirectorioLista($fichero);
					}
				}

			}else{
				say "ERROR: al abrir el directorio ".$directorio.": ".$! if $debug >= 1;
			}
		}
	};
	if($@){
		say Dumper(\$@);
	}
	return %listaDeArchivos;
}

sub procesarArchivos {
	#my $directorio = shift;
  my %listaDeArchivos = %{shift()};
  say "Procesar Archivos";
  #print Dumper(\%listaDeArchivos);
	eval {
		#my $tamanoLimite = (1024 ** 2) * 20 * $klv_argumentos{&_LP};
		#my $tamanoTotal = 0;
		my $exif = "";
		my @archivosOrdenados = sort by_archivoTamano keys %listaDeArchivos;

		if (scalar(@archivosOrdenados) > 0) {
			my $indice = 0;

			my %kids;
      my $forks = 0;

			foreach my $archivoTamanoTmp (@archivosOrdenados) {
        my ($archivoTamano, $dummy) = split(/_-_/,$archivoTamanoTmp);
				my %ficheroListaTipo = %{$listaDeArchivos{$archivoTamanoTmp}};
        foreach my $archivoTipo (keys %ficheroListaTipo){
          my %ficheroLista = %{$listaDeArchivos{$archivoTamanoTmp}{$archivoTipo}};
          foreach my $fichero (keys %ficheroLista){
            #print ">".$fichero."\n";
            if (-f $fichero) {
              #&comprobarDirectorio($directorio);
              
              #my $archivoTamanoSuma = -s $fichero;
              
              #$tamanoTotal = $tamanoTotal + $archivoTamanoSuma;
              
              #print ">>> ".$tamanoLimite." - ".$tamanoTotal." - ".$archivoTamanoSuma."\n";
              
              #while( scalar(keys %kids) >= $klv_argumentos{&_LP} ) {

                $indice++;
                eval {
                  my $pid = fork;
                  if (not defined $pid || $pid == -1) {
                    #warn 'Could not fork';
                    next;
                  }elsif ($pid) {
                    $forks++;
                    $kids{$pid}{'fichero'} = $fichero;
                    #$kids{$pid}{'tamano'} = $archivoTamanoSuma;
                    #say "In the parent process PID ($$), Child pid: $pid Num of fork child processes: $forks";
                  }else {
                    my $errorCode = 0;
                    eval {
                      #say "procesando ".$indice.": ".$fichero." (".&prettyBytes($archivoTamano).")" if $debug >= 1;
                      #&comprobarDirectorio($directorio);
                      
                      my $archivoNuevo = &extraerExif($fichero, $archivoTipo);
                      my $infoArchivo = '';
                      $infoArchivo .= $indice." D: ".$archivoNuevo.' << ' if $debug >= 1;
                      $infoArchivo .= "O: ".$fichero.'' if $debug >= 1;
                      $infoArchivo .= " (T: ".&prettyBytes($archivoTamano).")" if $debug >= 1;
                      $infoArchivo .= " (Tipo: ".$archivoTipo.")" if $debug >= 1;

                      
                      say $infoArchivo if $debug >= 1;
                    };
                    if($@){
                      print Dumper(\$@);
                      $errorCode = 1;
                    }
                    exit($errorCode);
                  }
                };
                if($@){
                  print Dumper(\$@);
                }
                
              #while ($tamanoTotal > $tamanoLimite || scalar(keys %kids) >= $klv_argumentos{&_LP}){
              while (scalar(keys %kids) >= $klv_argumentos{&_LP}){
                #&comprobarDirectorio($directorio);
                foreach my $kid (keys %kids) {
                  #print "Parent: Waiting on $kid\n";
                  my $pid = waitpid(-1, WNOHANG);
                  if($pid){
                    my $localtime = localtime;
                    #print $kids{$kid}." (".$kid.") procesado con código de error: ".$?." - ".$localtime."\n";
                    #$tamanoTotal = $tamanoTotal - $kids{$pid}{'tamano'};
                    say $kids{$kid}{'fichero'}." (".$kid.") procesado con código de error: ".$?." - ".$localtime."";
                    #print ".";
                    delete $kids{$kid};
                    
                    #print "Faltan ".(scalar(keys %kids))." procesos por terminar\n";
                  }
                  if(scalar(keys %kids) < $klv_argumentos{&_LP}){
                                      #print ">>>>>>>> ".$tamanoLimite." - ".$tamanoTotal." - ".$archivoTamanoSuma."\n";
                    last;
                  }
                }
              }
                
            }
          }
        }
			}

			while( scalar(keys %kids) > 0 ) {
			#while ($tamanoTotal > $tamanoLimite || scalar(keys %kids) >= $klv_argumentos{&_LP}){
				foreach my $kid (keys %kids) {
					#print "Parent: Waiting on $kid\n";
					my $pid = waitpid(-1, WNOHANG);
					if($pid){
						my $localtime = localtime;
						#$tamanoTotal = $tamanoTotal - $kids{$pid}{'tamano'};
						say $kids{$kid}{'fichero'}." (".$kid.") procesado con código de error: ".$?." - ".$localtime."";
            #print ".";
						delete $kids{$kid};
						#print "Faltan ".(scalar(keys %kids))." procesos por terminar\n";
					}
					if(scalar(keys %kids) <= 0){
					#if($tamanoTotal <= $tamanoLimite || scalar(keys %kids) <= 0){
						last;
					}
				}
			}
			while ( (waitpid(-1, WNOHANG)) > 0) { }
			say "\nProcesado!";
			# while (wait() != -1) {}
		}else{
			print "Nada para procesar.\n";
		}
	};
	if($@){
		print Dumper(\$@);
	}
  if(&moverArchivo($klv_argumentos{&_RUTA_DEST_BASE}, $klv_argumentos{&_RUTA_DEST}._VD_RW_BASE) == 0){
    &eliminar($klv_argumentos{&_RUTA_DEST_RW});
    rmdir $klv_argumentos{&_RUTA_DEST_RW};
  }
  
  my %archivoDatos;
	return %archivoDatos;
}

sub extraerExif {
	#my $directorio = shift;
	my $archivo = shift;
  my $archivoTipo = shift;

  my $archivoRutaDestino = $klv_argumentos{&_RUTA_DEST_BASE}.'/'.$archivoTipo;

  my $archivoNombreNuevoFinal = $archivo;



  my $archivoRuta = '';
  my $archivoNombre = '';
  my $archivoExt = '';

  if($archivo =~ /$reExtraerRuta/igs){
    $archivoRuta = ($1);
    $archivoNombre = ($3);
    $archivoExt = lc($5);
    if(length(trim($archivoExt)) <= 0){
      $archivoExt = '';
    }
  }

  my $archivoNombreNuevo = $archivoNombre;

#print ">> ---archivoNombre: ".$archivo."\n";
  
  if(defined($klv_argumentos{&_RENOMBRAR}{$archivoTipo}) || defined($klv_argumentos{&_RENOMBRAR}{$archivoExt})){
    my $fechaTmp = '';
    #my $exifTool = Image::ExifTool->new();
    #my %exifDatos;
    my $archivoNombreNuevo;

    
    eval {
      #$exifTool->Options(FixBase => '');   # "best guess" for fixing Maker offsets
      #$exifTool->ExtractInfo($archivo);
      #%exifDatos = &procesarInfoExif($archivo, $exifTool);
      #$archivoNombreNuevo = &crearNombreNuevoArchivo($archivo, $exifDatos{"fecha"}, $exifTool);
      #print ">> archivoNombreNuevo: ".$archivoNombreNuevo." ".$archivo."\n";
      #$archivoNombreNuevoFinal = &renombrarArchivo($archivo, $archivoNombreNuevo);
      #print ">> archivoNombreNuevoFinal: ".$archivoNombreNuevoFinal." ".$archivo."\n";
      $archivoNombreNuevo = $archivoNombre; # TEMPORAL, ELIMINAR AL FINAL
    };
    if($@){
      print Dumper(\$@);
    }

    $archivoNombreNuevoFinal = $archivo;
    #print "+";
  }else{
    $archivoNombreNuevo = $archivoNombre;
    #print "-";
  }

  
  $archivoNombreNuevoFinal = &renombrarArchivo($archivoRutaDestino, $archivoNombreNuevo, $archivoExt);
  $archivoRutaDestino = $archivoRutaDestino.'/'.$archivoNombreNuevoFinal.'.'.$archivoExt;

	return $archivoRutaDestino;
}

sub renombrarArchivo {
  my $archivoRuta = shift;
  my $archivoNombre = shift;
  my $archivoExt = shift;

  my $archivoNombreFinal = $archivoNombre;

  my $ruta = $archivoRuta.'/'.$archivoNombre.'.'.$archivoExt;
  my $cnt = 0;
  while (-f $ruta){
    $cnt++;
    $ruta = $archivoRuta.'/'.$archivoNombre.'_('.$cnt.').'.$archivoExt;
    $archivoNombreFinal = $archivoNombre.'_('.$cnt.').';
  }

  return $archivoNombreFinal;
}

sub moverArchivo {
  my $origen = shift;
  my $destino = shift;

  my $error = 1;
  if(-e $origen){
    if(!(-e $destino)){
      move ($origen, $destino);
      if(-e $destino){
        $error = 0;
      }
    }

  }

  return $error;
}


sub by_archivoTamano {
  # vars $a and $b automatically passed in

  # perl function 'stat' returns array of info on a file
  # 10th element of the stat array is last modified date,
  # returned as number of seconds since 1/1/1970.

  my ($archivoTamanoA, $dummyA) = split(/_-_/,$a);
  my ($archivoTamanoB, $dummyB) = split(/_-_/,$b);

  return $archivoTamanoA <=> $archivoTamanoB;
}


sub prettyBytes {
  my $size = $_[0];
  foreach ('b','kb','mb','gb','tb','pb'){
    return sprintf("%.2f",$size)."$_" if $size < 1024;
    $size /= 1024;
  }
}

sub trim {
  my $valor = shift;
  $valor =~ s/^[\s]+|[\s]+$//igs;
  return $valor;
}

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

sub eliminar {
	my $ruta = shift;
	my $err;
	chmod 777, $ruta;
	if(-d $ruta){
		rmdir $ruta;
	}else{
		if(-e $ruta){
			unlink $ruta;
		}
	}
	
	return $err;
}

1;