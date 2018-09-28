#!perl
$|=1;
#use sigtrap 'handler' => \&sigtrap, 'HUP', 'INT','ABRT','QUIT','TERM', 'KILL';
use sigtrap 'handler' => \&sigtrap, qw(any normal-signals error-signals stack-trace);
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
use Digest::MD5 qw(md5 md5_hex md5_base64);
use Term::ANSIColor;
use Image::ExifTool qw(:Public);

print color('rgb111');
my $msg = '';
my $parent = 1;

my $t0 = Benchmark->new;
my $tiempoInicial = [Time::HiRes::gettimeofday()]; # Inicializamos el contador de tiempo

my $debug = 10000000;


my $reIPv4 = qr/(?:(?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2})[.](?:25[0-5]|2[0-4][0-9]|[0-1]?[0-9]{1,2}))/i;
my $reDominio = qr/(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])/;
my $reExtraerRuta = qr/(.+)?([\/])([^\/]+)([\.])([^\.]+)$/;

my $reGpsNmea = qr/\$(GP|LC|OM|II)[a-zA-Z]{3,},/; # Tipo: GPS, Extensión: NMEA


sub detectarTipoDeArchivo {
  my $ruta = shift;
  
  my $archivoRuta = undef;
  my $archivoNombre = undef;
  my $archivoExt = undef;
  my $archivoTipo = undef;
  my $archivoSubTipo = undef;
  my $archivoContenido = '';
  my $nuevaRuta = $ruta;
  my $moverArchivo = 0;

  ($archivoTipo, $archivoSubTipo) = split('/',mimetype($ruta));
  if($ruta =~ /$reExtraerRuta/igs){
    $archivoRuta = ($1);
    $archivoNombre = ($3);
    $archivoExt = ($5);
    if(length(trim($archivoExt)) <= 0){
      $archivoExt = '';
    }
  }else{
    $archivoExt = '_ni';
    $moverArchivo = 1;
  }

  if(length($archivoTipo) <= 0){
    $archivoTipo = '_ni';
  }

  if($archivoExt eq 'gpx'){
      $archivoTipo = 'gps';
      $archivoSubTipo = 'gpx';
  }elsif($archivoExt eq 'kml'){
      $archivoTipo = 'gps';
      $archivoSubTipo = 'kml';
  }elsif($archivoExt eq 'kmz'){
      $archivoTipo = 'gps';
      $archivoSubTipo = 'kmz';
  }

if($archivoTipo eq 'text'){
    $archivoContenido = &leerArchivo($ruta);

    if($archivoContenido =~ /$reGpsNmea/igs){ # Tipo: GPS, Extensión: NMEA
      $archivoTipo = 'gps';
      $archivoSubTipo = 'nmea';
      if($archivoExt ne 'nme'){
        $archivoExt = 'nme';
        $moverArchivo = 1;
      } 
    }
    $archivoContenido = undef;
  }

  if($moverArchivo == 1){
    $nuevaRuta = $ruta.'.'.$archivoExt;
    &moverArchivo($ruta, $nuevaRuta);
  }

  return $nuevaRuta, $archivoTipo, $archivoSubTipo, $archivoExt;
}

sub leerArchivo {
	my $ruta = shift;
	my $archivo = '';
	if(open flC, "<$ruta"){
		my @entire_file=<flC>; #Slurp!
		$archivo = join("",@entire_file);
		#$archivo =~ s/(\$)/\\$/igs;
		close flC;
	}
	return $archivo;
}

sub mostrarMensaje {
  my $mensaje = shift;
  my $tipo = shift;
  my $print = shift;
  my $reset = shift;
  my $error = 0;

  if($tipo < 0){
    $tipo = 0;
  }elsif($tipo > 9){
    $tipo = 9;
  }

  if(!defined($print)){
    $print = 0;
  }

  if(!defined($reset)){
    $reset = 0;
  }


  if($tipo == 0){
    print color('rgb050');
  }elsif($tipo == 1){
    print color('rgb151');
  }elsif($tipo == 2){
    print color('rgb252');
  }elsif($tipo == 3){
    print color('rgb353');
  }elsif($tipo == 4){
    print color('rgb454');
  }elsif($tipo == 5){
    print color('rgb040');
  }elsif($tipo == 6){
    print color('rgb030');
  }elsif($tipo == 7){
    print color('rgb020');
  }elsif($tipo == 8){
    print color('rgb222');
  }elsif($tipo == 9){
    print color('rgb500');
  }else{
    print color('rgb111');
  }

  if($print == 1){
    print $mensaje;
  }else{
    say $mensaje;
  }

  if($reset != 1){
    print color('rgb111');
  }

  return $error;
}

sub sigtrap(){
  if($parent == 1){
    my ($user, $system, $child_user, $child_system) = times;
    $msg = "++++++++++++++\n".
        "+ FINALIZADO +\n".
        "++++++++++++++\n";
    &mostrarMensaje($msg, 0) if $debug >= 1;

    $msg = "Tiempo: ".&formatearTiempo(Time::HiRes::tv_interval($tiempoInicial))."\n".
        "Tiempo de usuario para $$ fue $user\n".
        "Tiempo de sistema para $$ fue $system\n".
        "Tiempo de usuario para todos los procesos hijos fue $child_user\n".
        "Tiempo de sistema para todos los procesos hijos fue $child_system";
    &mostrarMensaje($msg, 1) if $debug >= 2;

    my $t1 = Benchmark->new;
    my $td = timediff($t1, $t0);
    $msg = "Tiempo: ".timestr($td);
    &mostrarMensaje($msg, 0) if $debug >= 1;
    print color('reset');
    exit(1);
  }else{
    exit(0);
  }
}


use constant _LIMITE_PROCESO => 'lp'; 
use constant _RUTA => 'o';
use constant _RUTA_DESTINO => 'd';
use constant _RUTA_DESTINO_RW => 'rw';
use constant _RUTA_DESTINO_BASE => 'base';
use constant _REMOTO => 'or';
use constant _REMOTO_DESTINO => 'dr';
use constant _USUARIO_ORIGEN => 'usr';
use constant _PASSWORD_ORIGEN => 'pwd';
use constant _USUARIO_DESTINO => 'usrd';
use constant _PASSWORD_DESTINO => 'pwdd';
use constant _PUNTO_MONTAJE_ORIGEN => 'pm';
use constant _PUNTO_MONTAJE_DESTINO => 'pmd';
use constant _REMOTO_FILESYSTEM_ORIGEN => 'fs';
use constant _REMOTO_FILESYSTEM_DESTINO => 'fsd';
use constant _RENOMBRAR => 'rn';
use constant _VERBOSE => 'verbose';


use constant _VD_LIMITE_PROCESOD_L => 10;
use constant _VD_LIMITE_PROCESOD_R => 10;
use constant _VD_PUNTO_MONTAJE_ORIGEN => '/mnt';
use constant _VD_PUNTO_MONTAJE_DESTINO => '/mnt';
use constant _VD_RW => '/__procesado'; # Ruta de Trabajo
use constant _VD_RW_BASE => '/original'; # Ruta de Trabajo
use constant _VD_REMOTO_FILESYSTEM_ORIGEN => 'cifs';
use constant _VD_REMOTO_FILESYSTEM_DESTINO=> 'cifs';


my $reExtIgnorarTmp = '\.db$|\.nometanoexif$|\.nometanoexif_exiftool_tmp$';
my $reExtIgnorar = qr/$reExtIgnorarTmp/;



my %klv_argumentos;
my %listaDeArchivos;

$klv_argumentos{&_LIMITE_PROCESO} = _VD_LIMITE_PROCESOD_R; # Límite max de procesos simultáneos
$klv_argumentos{&_RUTA} = undef; # Ruta a procesar
$klv_argumentos{&_RUTA_DESTINO} = undef; # Ruta de destino
$klv_argumentos{&_REMOTO} = undef; # Indica si la ruta es remota (1) o local (otro valor)
$klv_argumentos{&_REMOTO_DESTINO} = undef; # Indica si la ruta es remota (1) o local (otro valor)
$klv_argumentos{&_USUARIO_ORIGEN} = undef; # Usuario de computador remoto origen
$klv_argumentos{&_PASSWORD_ORIGEN} = undef; # Password del computador remoto origen
$klv_argumentos{&_USUARIO_DESTINO} = undef; # Usuario de computador remoto destino
$klv_argumentos{&_PASSWORD_DESTINO} = undef; # Password del computador remoto destino
$klv_argumentos{&_PUNTO_MONTAJE_ORIGEN} = _VD_PUNTO_MONTAJE_ORIGEN; # Punto de montaje origen
$klv_argumentos{&_PUNTO_MONTAJE_DESTINO} = _VD_PUNTO_MONTAJE_DESTINO; # Punto de montaje destino

$klv_argumentos{&_REMOTO_FILESYSTEM_ORIGEN} = _VD_REMOTO_FILESYSTEM_ORIGEN; # Punto de montaje origen
$klv_argumentos{&_REMOTO_FILESYSTEM_DESTINO} = _VD_REMOTO_FILESYSTEM_DESTINO; # Punto de montaje destino

$klv_argumentos{&_RENOMBRAR} = undef; # Extensión o tipo de archivo para renombrar
$klv_argumentos{&_VERBOSE} = $debug; # Extensión o tipo de archivo para renombrar


#say "Procesar argumentos" if $debug >= 100;
foreach my $arg (@ARGV){
  my ($clave, $valor) = split(/\=/, $arg);
  $clave =~ s/^[\s]+|[\s]+$//igs;
  $clave =~ s/^\-//igs;
  $clave =~ s/^[\s]+|[\s]+$//igs;

  $valor =~ s/^[\s]+|[\s]+$//igs;
  $valor =~ s/^\'|\'$//igs;
  $valor =~ s/^[\s]+|[\s]+$//igs;
  
  $clave = lc($clave);
  #say $clave." = ".$valor if $debug >= 1000;
  if(exists($klv_argumentos{$clave})){
    if($clave eq _RUTA){
      $valor =~ s/\\/\//igs;
      $valor =~ s/\/$//igs;
      $klv_argumentos{&_RUTA} = ($valor);
      if($valor =~ /\/\/($reIPv4|$reDominio)/igs ){
        $klv_argumentos{&_REMOTO} = 1;
      }else{
        $klv_argumentos{&_REMOTO} = 0;
      }#else{
      #  $klv_argumentos{&_RUTA} = undef;
      #  $klv_argumentos{&_REMOTO} = undef;
      #}
    }

    if($clave eq _RUTA_DESTINO){
      $valor =~ s/\\/\//igs;
      $valor =~ s/\/$//igs;
      $klv_argumentos{&_RUTA_DESTINO} = ($valor);
      if($valor =~ /\/\/($reIPv4|$reDominio)/igs ){
        $klv_argumentos{&_REMOTO_DESTINO} = 1;
      }else{
        $klv_argumentos{&_REMOTO_DESTINO} = 0;
      }#else{
      #  $klv_argumentos{&_RUTA_DESTINO} = undef;
      #  $klv_argumentos{&_REMOTO_DESTINO} = undef;
      #}
    }

    if($clave eq _LIMITE_PROCESO){
      if(($valor > 0)){
        $klv_argumentos{&_LIMITE_PROCESO} = $valor;
      }else{
        $klv_argumentos{&_LIMITE_PROCESO} = _VD_LIMITE_PROCESOD_R;
      }
    }

    if($clave eq _USUARIO_ORIGEN){
      $klv_argumentos{&_USUARIO_ORIGEN} = $valor;
    }
    if($clave eq _PASSWORD_ORIGEN){
      $klv_argumentos{&_PASSWORD_ORIGEN} = $valor;
    }
    if($clave eq _PUNTO_MONTAJE_ORIGEN){
      $klv_argumentos{&_PUNTO_MONTAJE_ORIGEN} = $valor;
    }
    if($clave eq _VERBOSE){
      $klv_argumentos{&_VERBOSE} = $valor;
    }
    if($clave eq _RENOMBRAR){
      my @temp = split(/[,]/,$valor);
      foreach (@temp){
        $klv_argumentos{&_RENOMBRAR}{lc($_)} = lc($_);
      }
    }
  }
}

if(defined($klv_argumentos{&_VERBOSE})){
  $debug = $klv_argumentos{&_VERBOSE};
}








#sleep (int(rand(120)));
if(defined($klv_argumentos{&_RUTA})){
  my $error = 1;
  if($klv_argumentos{&_REMOTO} == 1){
    $klv_argumentos{&_RUTA} = &conectarRed(0, $klv_argumentos{&_RUTA}, $klv_argumentos{&_PUNTO_MONTAJE_ORIGEN}, $klv_argumentos{&_USUARIO_ORIGEN}, $klv_argumentos{&_PASSWORD_ORIGEN}, $klv_argumentos{&_REMOTO_FILESYSTEM_ORIGEN});
  }

  if(-e $klv_argumentos{&_RUTA}){
    if(defined($klv_argumentos{&_RUTA_DESTINO})){

    }else{
      $klv_argumentos{&_RUTA_DESTINO} = $klv_argumentos{&_RUTA};
      $klv_argumentos{&_RUTA_DESTINO_RW} = $klv_argumentos{&_RUTA_DESTINO}._VD_RW;
      $klv_argumentos{&_RUTA_DESTINO_BASE} = $klv_argumentos{&_RUTA_DESTINO_RW};
      $error = &crearDirectorio($klv_argumentos{&_RUTA_DESTINO_BASE});

      $klv_argumentos{&_RUTA_DESTINO_BASE} = $klv_argumentos{&_RUTA_DESTINO_BASE}._VD_RW_BASE;
      $error = &crearDirectorio($klv_argumentos{&_RUTA_DESTINO_BASE});

      if($klv_argumentos{&_REMOTO} == 0){
        $klv_argumentos{&_LIMITE_PROCESO} = _VD_LIMITE_PROCESOD_L;
        $klv_argumentos{&_REMOTO_DESTINO} = 0;
      }
    }
    
    #say "Error: ".$error;
    if($error == 0){
  #say Dumper(\%klv_argumentos);
      &mostrarMensaje('Iniciando', 0) if $debug >= 1;
      eval {
        my %listaDeArchivos;
        &mostrarMensaje('Buscar Archivos', 0) if $debug >= 1;
        %listaDeArchivos = &recorrerDirectorioLista($klv_argumentos{&_RUTA});
        &mostrarMensaje("\n", 1, 1) if $debug == 4;
        if(scalar(keys %listaDeArchivos) > 0){
          &mostrarMensaje('Procesar Archivos', 0) if $debug >= 1;
          &procesarArchivos(\%listaDeArchivos);
        }
      };
      if($@){
        say Dumper(\$@);
      }
    }

    # say $klv_argumentos{&_RUTA};
    # say $klv_argumentos{&_REMOTO};
    # if($klv_argumentos{&_REMOTO} == 1){
    #   system ('sudo umount -f -r '.$klv_argumentos{&_RUTA}) if ( grep m{$klv_argumentos{&_RUTA}}, qx{/bin/mount} ) ;
    #   say 'desmontado';
    # }

  }else{
    &mostrarMensaje('Debe indicar una ruta válida', 9) if $debug >= 0;
  }
  
}else{
  &mostrarMensaje('Mostrar modo de uso', 9) if $debug >= 0;
}
say Dumper(\%klv_argumentos);

my ($user, $system, $child_user, $child_system) = times;
$msg = "++++++++++++++\n".
    "+ FINALIZADO +\n".
    "++++++++++++++\n";
&mostrarMensaje($msg, 0) if $debug >= 2;
$msg = "Tiempo: ".&formatearTiempo(Time::HiRes::tv_interval($tiempoInicial))."\n".
    "Tiempo de usuario para $$ fue $user\n".
    "Tiempo de sistema para $$ fue $system\n".
    "Tiempo de usuario para todos los procesos hijos fue $child_user\n".
    "Tiempo de sistema para todos los procesos hijos fue $child_system";
&mostrarMensaje($msg, 1) if $debug >= 2;

my $t1 = Benchmark->new;
my $td = timediff($t1, $t0);
$msg = "Tiempo: ".timestr($td);
&mostrarMensaje($msg, 0) if $debug >= 1;
print color('reset');
exit(0);

################## Funciones ##################

sub conectarRed {
  my $destino = shift;
  my $rutaRed = shift;
  my $rutaPuntoMontaje = shift;
  my $usuario = shift;
  my $password = shift;
  my $fileSystem = shift;
  my $rutaBase = '/__CATALOGADOR';
  my $rutaBaseOrigen = '/origen';
  my $rutaBaseDestino = '/destino';
  my $rutaLocal = undef;
  my @carpetas = split(/\//, $rutaRed);

  if(-d $rutaPuntoMontaje){
    $rutaLocal = $rutaPuntoMontaje.$rutaBase;
    my $error = &crearDirectorio($rutaLocal);
    if($error == 0){
      
      if(!defined($fileSystem)){
        $fileSystem = 'cifs';
      }
      if($destino == 1){
        $rutaLocal = $rutaLocal.$rutaBaseDestino;
      }else{
        $rutaLocal = $rutaLocal.$rutaBaseOrigen;
        
      }
      $error = &crearDirectorio($rutaLocal);
      if($error == 0){
        $rutaLocal = $rutaLocal.'/'.$carpetas[((scalar(@carpetas)) - 1)];
        $error = &crearDirectorio($rutaLocal);
        if($error == 0){
          #system ('sudo umount -f -r '.$rutaLocal) if ( grep m{$rutaLocal}, qx{/bin/mount} ) ;
          system ('sudo mount -t '.$fileSystem.' '.$rutaRed.' '.$rutaLocal.' -o rw,username='.$usuario.',password='.$password.'') if (!( grep m{$rutaLocal}, qx{/bin/mount} ));
        }
      }
    }
  }

  return $rutaLocal;
}

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
  my $archivoRuta = '';
  my $archivoNombre = '';
  my $archivoExt = '';
  #my %listaDeArchivos;
	eval {
		if($directorio !~ /\/$/igs){
			$directorio .= "/";
		}
    #&comprobarDirectorio($directorio);
		
		if($directorio ne $klv_argumentos{&_RUTA_DESTINO_RW}.'/'){
			if(opendir DIR, $directorio){
				#say "R: ".$directorio if $debug >= 100;
        &mostrarMensaje("*", 2, 1) if $debug == 3 || $debug == 4;
        &mostrarMensaje('Directorio: '.$directorio, 2) if $debug >= 6;
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
              #say $fichero;
              my ($archivoRuta, $archivoTipo, $archivoSubTipo, $archivoExt) = &detectarTipoDeArchivo($fichero);
              &mostrarMensaje('+', 3, 1) if $debug == 4;
              &mostrarMensaje('Archivo: '.$fichero.' '.$archivoTipo.'/'.$archivoSubTipo.'', 3) if $debug >= 7;
              my $archivoTamano = -s $archivoRuta;
              if($archivoTamano > 0){
                my $error = &crearDirectorio($klv_argumentos{&_RUTA_DESTINO_BASE}.'/'.$archivoTipo);
                if($error == 0){
                  $listaDeArchivos{$archivoTamano.'_-_'.uc(md5_hex($archivoRuta))}{$archivoTipo}{$archivoRuta} = $archivoRuta;
                }
                
                #say "++ ".$fichero." ".$archivoTipo if $debug >= 1000;
              }else{
                &mostrarMensaje('0', 2, 1) if $debug == 4;
                &eliminar($archivoRuta);
              }
						}else{
              #say "-t ".$fichero if $debug >= 1000;
							&eliminar($fichero);
						}
					}elsif (-d $fichero) {
						&recorrerDirectorioLista($fichero);
					}
				}

			}else{
        &mostrarMensaje("ERROR: al abrir el directorio ".$directorio.": ".$! , 9) if $debug >= 0;
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
  print color('rgb050');
  #print Dumper(\%listaDeArchivos);
	eval {
		#my $tamanoLimite = (1024 ** 2) * 20 * $klv_argumentos{&_LIMITE_PROCESO};
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
              
              #while( scalar(keys %kids) >= $klv_argumentos{&_LIMITE_PROCESO} ) {

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
                    print color('rgb050');
                    my $errorCode = 0;
                    $parent = 0;
                    eval {
                      #say "procesando ".$indice.": ".$fichero." (".&prettyBytes($archivoTamano).")" if $debug >= 1;
                      &mostrarMensaje('+', 1, 1, 1) if $debug >= 2 && $debug <= 4;
                      &mostrarMensaje("Procesando ".$indice.": ".$fichero." (".&prettyBytes($archivoTamano).")", 1) if $debug >= 5;
                      #&comprobarDirectorio($directorio);
                      
                      my $archivoNuevo = &procesarArchivo($fichero, $archivoTipo);
                      my $infoArchivo = '';
                      $infoArchivo .= $indice." D: ".$archivoNuevo.' << ' if $debug >= 1;
                      $infoArchivo .= "O: ".$fichero.'' if $debug >= 1;
                      $infoArchivo .= " (T: ".&prettyBytes($archivoTamano).")" if $debug >= 1;
                      $infoArchivo .= " (Tipo: ".$archivoTipo.")" if $debug >= 1;

                      
                      #say $infoArchivo if $debug >= 1;
                      &mostrarMensaje($infoArchivo, 1) if $debug >= 5;
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
                
              #while ($tamanoTotal > $tamanoLimite || scalar(keys %kids) >= $klv_argumentos{&_LIMITE_PROCESO}){
              while (scalar(keys %kids) >= $klv_argumentos{&_LIMITE_PROCESO}){
                #&comprobarDirectorio($directorio);
                foreach my $kid (keys %kids) {
                  #print "Parent: Waiting on $kid\n";
                  my $pid = waitpid(-1, WNOHANG);
                  if($pid){
                    my $localtime = localtime;
                    #print $kids{$kid}." (".$kid.") procesado con código de error: ".$?." - ".$localtime."\n";
                    #$tamanoTotal = $tamanoTotal - $kids{$pid}{'tamano'};
                    #say $kids{$kid}{'fichero'}." (".$kid.") procesado con código de error: ".$?." - ".$localtime."";
                    &mostrarMensaje('-', 1, 1, 1) if $debug >= 2 && $debug <= 4;
                    &mostrarMensaje($kids{$kid}{'fichero'}." (".$kid.") procesado con código de error: ".$?." - ".$localtime."", 1) if $debug >= 5;
                    #print ".";
                    delete $kids{$kid};
                    
                    #print "Faltan ".(scalar(keys %kids))." procesos por terminar\n";
                  }
                  if(scalar(keys %kids) < $klv_argumentos{&_LIMITE_PROCESO}){
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
			#while ($tamanoTotal > $tamanoLimite || scalar(keys %kids) >= $klv_argumentos{&_LIMITE_PROCESO}){
				foreach my $kid (keys %kids) {
					#print "Parent: Waiting on $kid\n";
					my $pid = waitpid(-1, WNOHANG);
					if($pid){
						my $localtime = localtime;
						#$tamanoTotal = $tamanoTotal - $kids{$pid}{'tamano'};
						#say $kids{$kid}{'fichero'}." (".$kid.") procesado con código de error: ".$?." - ".$localtime."";
            &mostrarMensaje('-', 1, 1, 1) if $debug >= 2 && $debug <= 4;
            &mostrarMensaje($kids{$kid}{'fichero'}." (".$kid.") procesado con código de error: ".$?." - ".$localtime."", 1) if $debug >= 5;
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
  &mostrarMensaje('Finalizando', 0) if $debug >= 1;
  if(&moverArchivo($klv_argumentos{&_RUTA_DESTINO_BASE}, $klv_argumentos{&_RUTA_DESTINO}._VD_RW_BASE) == 0){
    &eliminar($klv_argumentos{&_RUTA_DESTINO_RW});
    rmdir $klv_argumentos{&_RUTA_DESTINO_RW};
  }
  
  my %archivoDatos;
	return %archivoDatos;
}

sub procesarArchivo {
	#my $directorio = shift;
	my $archivo = shift;
  my $archivoTipo = shift;

  my $archivoRutaDestino = $klv_argumentos{&_RUTA_DESTINO_BASE}.'/'.$archivoTipo;

  my $archivoNombreNuevoFinal = $archivo;



  my $archivoRuta = '';
  my $archivoNombre = '';
  my $archivoExt = '';

  if($archivo =~ /$reExtraerRuta/igs){
    $archivoRuta = ($1);
    $archivoNombre = ($3);
    $archivoExt = ($5);
    if(length(trim($archivoExt)) <= 0){
      $archivoExt = '';
    }
  }

  my $archivoNombreNuevo = $archivoNombre;

#print ">> ---archivoNombre: ".$archivo."\n";
  
  if(defined($klv_argumentos{&_RENOMBRAR}{$archivoTipo}) || defined($klv_argumentos{&_RENOMBRAR}{$archivoExt})){
    my $fechaTmp = '';
    my $exifTool = Image::ExifTool->new();
    #my %exifDatos;
    #my $archivoNombreNuevo;

    
    eval {
      $exifTool->Options(FixBase => '');   # "best guess" for fixing Maker offsets
      &mostrarMensaje("ExifTool: ExtractInfo: ".$archivo."", 6) if $debug >= 10;
      my $info = $exifTool->ImageInfo($archivo);

      my $archivoFecha = &extraerFechaExif($archivo, $info);
      $archivoNombreNuevo = &crearNombreNuevoArchivo($archivo, $archivoFecha, $exifTool);
    };
    if($@){
      print Dumper(\$@);
    }
  }else{
    $archivoNombreNuevo = $archivoNombre;
  }

  
  $archivoNombreNuevoFinal = &renombrarArchivo($archivoRutaDestino, $archivoNombreNuevo, $archivoExt);
  $archivoRutaDestino = $archivoRutaDestino.'/'.$archivoNombreNuevoFinal.'.'.$archivoExt;

  my $errCnt = 0;

  while($errCnt <= 3 && &moverArchivo($archivo, $archivoRutaDestino) != 0){
    $errCnt++;
  }

  if(-e $archivoRutaDestino){
    &mostrarMensaje('Se movió '.$archivo.' >> '.$archivoRutaDestino, 1) if $debug >= 9;
  }else{
    &mostrarMensaje('Error al mover '.$archivo.' >> '.$archivoRutaDestino, 9) if $debug >= 0;
  }

	return $archivoRutaDestino;
}

sub procesarInfoExif {
	my $rutaArchivo = shift;
	my $exifTool = shift;
	my $archivoFecha = "";
	my %exifDatos;

	eval {
		$exifDatos{"fecha"} =  &extraerFechaExif($rutaArchivo, $exifTool);
	};
	if($@){
		print Dumper(\$@);
		#$errorCode = 1;
	}
	return %exifDatos;
}

sub extraerFechaExif {
	my $rutaArchivo = shift;
	my $exifTool = shift;
	my $archivoFecha = 0;

	eval {
		&mostrarMensaje("ExifTool: GetValue: DateTimeOriginal: ".$rutaArchivo."", 6) if $debug >= 10;
		#$archivoFecha = $exifTool->GetValue("DateTimeOriginal");
    $archivoFecha = &limpiarFecha($exifTool->{"DateTimeOriginal"});
		if(!defined($archivoFecha)) { #if(length($archivoFecha) <= 0 || $archivoFecha =~ /^[0]+$/igs){
      &mostrarMensaje("ExifTool: GetValue: CreateDate: ".$rutaArchivo."", 6) if $debug >= 10;
			#$archivoFecha = $exifTool->GetValue("CreateDate");
      $archivoFecha = &limpiarFecha($exifTool->{"CreateDate"});
			if(!defined($archivoFecha)) { #if(length($archivoFecha) <= 0 || $archivoFecha =~ /^[0]+$/igs){
        &mostrarMensaje("ExifTool: GetValue: ModifyDate: ".$rutaArchivo."", 6) if $debug >= 10;
				#$archivoFecha = $exifTool->GetValue("ModifyDate");
        $archivoFecha = &limpiarFecha($exifTool->{"ModifyDate"});
				if(!defined($archivoFecha)) { #if(length($archivoFecha) <= 0 || $archivoFecha =~ /^[0]+$/igs){
          &mostrarMensaje("ExifTool: GetValue: FileCreateDate: ".$rutaArchivo."", 6) if $debug >= 10;
					#$archivoFecha = $exifTool->GetValue("FileCreateDate");
          $archivoFecha = &limpiarFecha($exifTool->{"FileCreateDate"});
					if(!defined($archivoFecha)) { #if(length($archivoFecha) <= 0 || $archivoFecha =~ /^[0]+$/igs){
            &mostrarMensaje("ExifTool: Fecha Sistema: ".$rutaArchivo."", 6) if $debug >= 10;
						my $epoch_timestamp = (stat($rutaArchivo))[9];
						my @now = localtime($epoch_timestamp);
						if(length($now[0]) <= 1){
							$now[0] = '0'.$now[0];
						}
						if(length($now[1]) <= 1){
							$now[1] = '0'.$now[1];
						}
						if(length($now[2]) <= 1){
							$now[2] = '0'.$now[2];
						}
						if(length($now[3]) <= 1){
							$now[3] = '0'.$now[3];
						}
						# Convert zero-based-month to calendar month
						++$now[4];
						if(length($now[4]) <= 1){
							$now[4] = '0'.$now[4];
						}
						# Convert 1900-based-year to calendar year
						$now[5] += 1900;
						$archivoFecha = $now[5].$now[4].$now[3].$now[2].$now[1].$now[0];
					}
				}
			}
		}

		$archivoFecha =~ s/^[\s]+|[\s]+$//igs;
		$archivoFecha =~ s/\:/-/igs;
		$archivoFecha =~ s/[^0-9]+//igs;
		$archivoFecha =~ s/^[\s]+|[\s]+$//igs;

	};
	if($@){
		print Dumper(\$@);
	}
	return $archivoFecha;
}

sub limpiarFecha () {
  my $archivoFecha = shift;
  if(defined($archivoFecha)){
    $archivoFecha =~ s/^[\s]+|[\s]+$//igs;
    $archivoFecha =~ s/\:/-/igs;
    $archivoFecha =~ s/[^0-9]+//igs;
    $archivoFecha =~ s/^[\s]+|[\s]+$//igs;
    if(!($archivoFecha > 0)){
      $archivoFecha = undef;
    }elsif ($archivoFecha =~ /^[0]+$/igs){
      $archivoFecha = undef;
    }
  }

  return $archivoFecha;
}

sub crearNombreNuevoArchivo {
	my $archivo = shift;
	my $archivoFecha = shift;
	my $exifTool = shift;
	my $archivoNuevo;
	my $archivoFirma = &calcularFirmaArchivo($archivo, $exifTool);
	eval {
		if($archivo =~ /$reExtraerRuta/igs){
			my @etiquetas = (
				"Make",
				"Model"
			);
			my $ruta = $1;
			my $archivoNombreOriginal = $4;
			$archivoNombreOriginal =~ s/^[\s]+|[\s]+$//igs;
			my $ext = $6;

			$archivoFecha =~ s/^[\s]+|[\s]+$//igs;
			$archivoFecha =~ s/\:/-/igs;
			$archivoFecha =~ s/[^0-9]+//igs;
			$archivoFecha =~ s/^[\s]+|[\s]+$//igs;
			if(length($archivoFecha) <= 0){
				$archivoNuevo = $archivoNombreOriginal;
			}else{
				$archivoNuevo = $archivoFecha."_".$archivoFirma;
			}
			$archivoNuevo =~ s/^[\s]+|[\s]+$//igs;
			my $etiquetaValor;
			# foreach $etiqueta (@etiquetas){
				# if(length($exifTool->GetValue($etiqueta)) > 0){
					# $etiquetaValor = $exifTool->GetValue($etiqueta);
					# $etiquetaValor =~ s/^[\s]+|[\s]+$//igs;
					# $archivoNuevo = $archivoNuevo." - ".$etiquetaValor;
					# $archivoNuevo =~ s/^[\s]+|[\s]+$//igs;
				# }
			# }
		}
		if(length($archivoNuevo) <= 0){
			#$archivoNuevo = $ruta.$archivoNombreOriginal.".".lc($ext);
			#print ">>> Crear Nombre Nuevo ".$archivoNuevo."\n";
		}
	};
	if($@){
		print Dumper(\$@);
	}
	return $archivoNuevo;
}

sub calcularFirmaArchivo {
	my $ruta = shift;
  my $exifTool = shift;
	my $exifBk;
	my $digest = '';
	my %exifBK;
  &mostrarMensaje("calcularFirmaArchivo: ".$ruta."", 6) if $debug >= 10;
	eval {
		my $rutaTmp = $ruta.'.nometanoexif';
		if (-f $rutaTmp) {
			&eliminar($rutaTmp);
		}
    #&mostrarMensaje("calcularFirmaArchivo: Copia: ".$ruta."", 6) if $debug >= 10;
		#copy $ruta, $rutaTmp;
		#if (-f $rutaTmp) {
			chmod 777, $rutaTmp;
			$digest = &superQuickMD5($ruta, $rutaTmp, $exifTool);
		#}else{
    #  &mostrarMensaje("Error al copiar ".$rutaTmp , 9) if $debug >= 0;
		#	exit;
		#}
		&eliminar($rutaTmp);############################################### DESCOMENTAME CUANDO TERMINES!!!!!!
	};
	if($@){
		print Dumper(\$@);
	}
	return $digest;
}

sub superQuickMD5 {
	my $ruta = shift;
  my $rutaDestino = shift;
  my $exifTool = shift;
	my $md5 = new Digest::MD5->new;
	my $tamanoLimite = ((1024**2) * 10); #  1024**2 = 1MB
	my $digest = '';
	#my %exifBK;
	eval {
		if (-f $ruta) {
			#my $exifTool = new Image::ExifTool;
			#$exifTool->Options(FixBase => '');   # "best guess" for fixing Maker offsets
      #&mostrarMensaje("MD5: Image info: ".$ruta."", 6) if $debug >= 10;
			#my $info = $exifTool->ImageInfo($ruta);
			#$info = $exifTool->GetWritableTags();
			#$exifTool->SaveNewValues();
			# foreach (sort keys %$info) {
				# $exifBK{$_} = $info{$_};
				# $exifTool->SaveNewValues();
				# $exifTool->SetNewValue($_);
				
			# }
      &mostrarMensaje("MD5: SetNewValue: ".$ruta."", 6) if $debug >= 10;
			$exifTool->SetNewValue('*');

      &mostrarMensaje("MD5: WriteInfo: ".$ruta." >> ".$rutaDestino, 6) if $debug >= 10;
			my $copia = $exifTool->WriteInfo($ruta, $rutaDestino);
      &mostrarMensaje("MD5: WriteInfo: ".$ruta." >> ".$rutaDestino, 6) if $debug >= 10;
      if($copia != 1 && $copia != 2){
        &mostrarMensaje("MD5: Copia: ".$copia, 6) if $debug >= 10;
		    copy $ruta, $rutaDestino;
        if(-e $rutaDestino){
			      my $exifToolTmp = new Image::ExifTool;
			      $exifToolTmp->Options(FixBase => '');   # "best guess" for fixing Maker offsets
            my $info = $exifToolTmp->ImageInfo($rutaDestino);
            &mostrarMensaje("MD5: SetNewValue 2: ".$ruta."", 6) if $debug >= 10;
            $exifToolTmp->SetNewValue('*');
            &mostrarMensaje("MD5: WriteInfo 2: ".$ruta." >> ".$rutaDestino, 6) if $debug >= 10;
            $copia = $exifToolTmp->WriteInfo($rutaDestino);
            $copia = 1;
            &mostrarMensaje("MD5: Copia 2: ".$copia, 6) if $debug >= 10;
        }
      }

      if($copia == 1 || $copia == 2){
        if(open flC, "<$rutaDestino"){
          my $filesize = -s $rutaDestino;
          #if($filesize > 0 && $filesize <= $tamanoLimite){
            &mostrarMensaje("MD5: Archivo: ".$rutaDestino."", 6) if $debug >= 10;
            $digest = uc(md5_hex(<flC>));
            &mostrarMensaje("MD5: checksum: ".$digest." >> ".$rutaDestino."", 6) if $debug >= 10;
          # }else{
          # 	$fileSizePorcentaje = int($filesize * 0.25);
          # 	$blockSize = int($fileSizePorcentaje / 100);
          # 	$blockJumpSize = int($filesize / 100);
          # 	$md5->add( -s <flC> );
          # 	my $pos = 0;
          # 	#print "<<<< Checksum ".$ruta.">>>>\n";
          # 	until( eof flC ) {
          # 		seek flC, $pos, 0;
          # 		read( flC, my $block, $blockSize ) or last;
          # 		$md5->add( $block );
          # 		$pos += $blockJumpSize;
          # 	}
          # 	#print "<<<< FIN Checksum ".$ruta.">>>>\n";
          # 	$digest = uc($md5->hexdigest);
          # }
          close flC;
        }else{
          &mostrarMensaje("SuperQuickMD5: No se abrió el archivo".$rutaDestino , 9) if $debug >= 0;
          &eliminar($rutaDestino);
          exit;
        }
      }else{
        &mostrarMensaje("Error al copiar archivo ".$copia.": ".$ruta." >> ".$rutaDestino."", 9) if $debug >= 0;
        &eliminar($rutaDestino);
        exit;
      }
			# foreach (sort keys %exifBK) {
				# $exifTool->SetNewValue($_, $exifBK{$_});
			# }
			# #$exifTool->RestoreNewValues();
			# $exifTool->WriteInfo($ruta);
		}else{
      &mostrarMensaje("SuperQuickMD5: No es archivo ".$ruta , 9) if $debug >= 0;
			exit;
		}
	};
	if($@){
		print Dumper(\$@);
		exit;
	}
  &eliminar($rutaDestino);
  return $digest;
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
    $archivoNombreFinal = $archivoNombre.'_('.$cnt.')';
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

  return $archivoTamanoB <=> $archivoTamanoA;
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