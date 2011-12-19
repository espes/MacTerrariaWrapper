($skriptName = 'xactxtract');
($skriptVersion = 0.97);
sub BEGIN {
    require(5.01);
}
use Math::BigInt;
use lib ('./t');
use xaWma;
use xaXwb;
use xaXsb;
use constant ('IS_SCRIPT', 0);
use constant ('DEBUG', 0);
use constant ('DINFO1', 0);
use constant ('XAXT_HELP', 0);
use constant ('XAXT_CHECKSUM', 1);
use constant ('XAXT_INJECT', 2);
use constant ('XAXT_XTRACT', 3);
use constant ('XAXT_INFO', 4);
use constant ('XAXT_SAFE', 1);
use constant ('XAXT_XMODE_INFO', 1);
use constant ('XAXT_XMODE_CONV', 2);
use constant ('XAXT_IS_XWB', 2);
use constant ('XAXT_IS_XSB', 4);
use constant ('RIFF_WAVE_PCM', 1);
use constant ('RIFF_WAVE_XBOX_ADPCM', 105);
use constant ('WAVEBANKMINIFORMAT_TAG_PCM', 0);
use constant ('WAVEBANKMINIFORMAT_TAG_XMA', 1);
use constant ('WAVEBANKMINIFORMAT_TAG_ADPCM', 2);
use constant ('WAVEBANKMINIFORMAT_TAG_WMA', 3);
BEGIN {
    $^H{'feature_say'} = q(1);
    $^H{'feature_state'} = q(1);
    $^H{'feature_switch'} = q(1);
}
binmode(STDOUT, ':encoding(cp850)');
($xaxt_mode = 0);
($xtractmode = 3);
($xaxt_safemode = 0);
(@infiles = ());
(my($myWavName), $myXsbName, $myXwbName, $myCueName, $infoName, ($myVol = 90));
(my $arg = join(' ', @ARGV));
if (($arg =~ /-safe/)) {
    shift(@ARGV);
    ($xaxt_safemode = 1);
}
'???';
do {
    given ($ARGV[0]) {
        when (/^-x/) {
            ($xaxt_mode = 3);
            ($xtractmode = substr($ARGV[0], 2, 1));
            (@infiles = @ARGV[1 .. $#ARGV]);
            ($infoName = $ARGV[1]);
            break;
        }
        when ('-c') {
            ($xaxt_mode = 1);
            (@infiles = @ARGV[1 .. $#ARGV]);
            ($infoName = $ARGV[1]);
            break;
        }
        default {
            if (($#ARGV > (-1))) {
                (@infiles = @ARGV);
                ($xaxt_mode = 4);
                ($infoName = $ARGV[0]);
            }
            else {
                say("\n", uc($skriptName), " v$skriptVersion by Nachgrimm (aka Liandril)");
                say('Tool zum Auslesen von XACT Soundbanks(.xsb) und Extrahieren von Wavebanks(.xwb)');
                say("Aufrufm\366glichkeiten:");
                say("$skriptName <FILENAME>.xsb/xwb     ....liefert Infos zur Soundbank/Wavebank");
                say("$skriptName -c  <FILENAME>.xsb     ....korrigiert Checksumme der Soundbank");
                say("$skriptName -x  <FILENAME>.xwb     ....extrahiert .xWMAs aus Wavebank");
                say("$skriptName -x2 <FILENAME>.xwb     ....extrahiert u. konvertiert in .wav");
                say("F\374r die Option -x2 muss sich das Programm xWMAEncode.exe (Teil des");
                say('Microsoft DirectX SDK) im selben Verzeichnis befinden.');
                say(q[Sollte extrahieren einer .xwb mit 'Out of Memory' error scheitern, dann:]);
                say("$skriptName -safe -x2 <FILENAME>.xwb ..exrahiere+konvertiere im 'Safe Mode'");
                exit;
            }
        }
    }
};
my($infileTyp);
($infoName =~ /.x(w|s)b$/);
(my $endung = $&);
if (($endung =~ /\.xsb/)) {
    ($infileTyp = 4);
}
if (($endung =~ /\.xwb/)) {
    ($infileTyp = ($infileTyp | 2));
}
'???';
if ((($xaxt_mode == 3) and ($xtractmode & 2))) {
    if ((not -e('xWMAEncode.exe'))) {
        ($xWMAEncodeError = "Das zum Konvertieren der .xwma Dateien in .wav Dateien benoetigte Programm \nxWMAEncode.exe konnte im akt. Verzeichnis nicht gefunden werden. xWMAEncode\nist Teil des frei erhaeltlichen Microsoft DirectX SDK(Version Maerz 2009).\n\nThe tool xWMAEncode.exe (necessary to convert the .xwma files to .wav) wasn't\nfound in the current directory. xWMAEncode is part of the freely obtainable\nMicrosoft DirectX SDK (Version: March 2009).\n");
        die($xWMAEncodeError);
    }
}
($hasWildcard = 0);
do {
    ($hasWildcard = (($#infiles > 0) ? 1 : 0));
    (my(@temp) = grep(/.x(w|s)b$/, @infiles));
    (@infiles = @temp)
};
'???';
my($aktfile);
if (($xaxt_mode == 2)) {
    print("Leider ist das Einf\374gen von Wavedateien (noch) nicht m\366glich, da die Hashfunktion von XSB unbekannt ist\n");
    exit;
}
((my $wbNum = 0), ($wmaExtracted = 0));
($sbNum = 0);
my(@res);
foreach $aktfile (@infiles) {
    if (($infileTyp == 2)) {
        (++$wbNum);
        (($xaxt_mode == 3) and ($wmaExtracted += xtractXwb($aktfile)));
        if (($xaxt_mode == 4)) {
            (my $xwb = 'xaXwb'->new($aktfile));
            $xwb->readHeader;
            (my(@tmp) = $xwb->info);
            (@res = map({($res[$_] + $tmp[$_]);} (0 .. $#tmp)));
            $xwb->close;
        }
        (($xaxt_mode == 1) and print(($aktfile . " hat keine Checksumme(Option nur f\374r .xsb Dateien sinnvoll)\n")));
    }
    elsif (($infileTyp == 4)) {
        (my $xsb = 'xaXsb'->new($aktfile));
        $xsb->readAll;
        if (($xaxt_mode == 4)) {
            (++$sbNum);
            (my(@tmp) = $xsb->info);
            (@res = map({($res[$_] + $tmp[$_]);} (0 .. $#tmp)));
        }
        if (($xaxt_mode == 1)) {
            (my $changed = $xsb->recalcChecksum);
            if ($changed) {
                $xsb->renameWriteAndClose('_org');
                print(((' ' . ($aktfile . '_org')) . "=Backup der Orginaldatei\n"));
            }
        }
        (($xaxt_mode == 3) and print(($aktfile . ": Extrahieren aus Soundbanks nicht m\366glich\n")));
        $xsb->close;
    }
    else {
        print("$aktfile ist weder eine .xsb noch eine .xwb Datei ?!?\n");
    }
}
if (($hasWildcard and ($xaxt_mode == 4))) {
    if (($infileTyp == 2)) {
        print("Insgesamt: $wbNum Wavebank(s) (davon $res[0] streaming); WAVES: ");
        say("$res[1] PCMs, $res[2] XMAs, $res[3] ADPCMs, $res[4] WMAs");
    }
    elsif (($infileTyp == 4)) {
        print("Insgesamt: $sbNum Soundbanks mit $res[0] Standard-Cues, $res[1] ExtraCues und $res[2] Sounds\n");
    }
}
elsif ((($hasWildcard and ($xaxt_mode == 3)) and ($infileTyp == 2))) {
    print("Insgesamt: $wmaExtracted (x)WMA Dateien aus $wbNum Wavebanks extrahiert.\n");
}
exit;
sub xtractXwb {
    BEGIN {
        $^H{'feature_say'} = q(1);
        $^H{'feature_state'} = q(1);
        $^H{'feature_switch'} = q(1);
    }
    (my $infileName = shift(@_));
    ($infileName =~ /\.xwb$/);
    (my $dirName = $`);
    (my $outfileName = ($dirName . '_'));
    ($dirName = ('./' . $dirName));
    (&mk_subdirs($dirName, 511) and die("Konnte Verzeichnis $dirName nicht anlegen"));
    ($dirName .= '/');
    (my $xwb = 'xaXwb'->new($infileName, $xaxt_safemode));
    (my $numWaves = $xwb->readHeader);
    ($| = 1);
    print("$infileName : ");
    ($| = 0);
    $xwb->readRest;
    (my($wdFlags), $wdDur, $wdTyp, $wdChan, $wdRate, $wdAlign, $wdPCM16, $wdOff, $wdLen);
    my($waveData);
    my(@outWMAfiles);
    my($outNonWMAFiles);
    (my $infoStep = int(($numWaves / 10)));
    ($infoStep = (($infoStep < 1) ? 1 : $infoStep));
    (my(@infoXtractText) = split(//, 'Extracted ', 0));
    (my(@infoConvText) = split(//, 'Converted ', 0));
    (($xtractmode & 1) and print("$numWaves Waves. Writing:\n"));
    my($extractedFiles);
    my($infoFileName);
    for ((my $i = 0); ($i < $numWaves); (++$i)) {
        (($wdFlags, $wdDur, $wdTyp, $wdChan, $wdRate, $wdAlign, $wdPCM16, $wdOff, $wdLen) = $xwb->readWaveInfo($i));
        ($waveData = $xwb->readWaveData($wdOff, $wdLen));
        ($infoFileName = ($outfileName . sprintf('%05d', $i)));
        (my $outfileNameFull = ($dirName . $infoFileName));
        if (($wdTyp == 3)) {
            (my $wma = 'xaWma'->new(($outfileNameFull . '.xwma')));
            ($waveData = $xwb->readWaveData($wdOff, $wdLen));
            $wma->writeXWma($i, ($infoFileName . '.xwma'), $wdFlags, $wdDur, $wdTyp, $wdChan, $wdRate, $wdAlign, $wdPCM16, $wdOff, $wdLen, (\$waveData), ($xtractmode & 1));
            $wma->flush;
            $wma->close;
            push(@outWMAfiles, $outfileNameFull);
        }
        elsif (($wdTyp == 0)) {
            (my $wma = 'xaWma'->new(($outfileNameFull . '.wav')));
            ($waveData = $xwb->readWaveData($wdOff, $wdLen));
            $wma->writePCM($i, ($infoFileName . '.xwma'), $wdFlags, $wdDur, $wdTyp, $wdChan, $wdRate, $wdAlign, $wdPCM16, $wdOff, $wdLen, (\$waveData), ($xtractmode & 1));
            $wma->flush;
            $wma->close;
            (++$outNonWMAFiles);
        }
        else {
            ();
        }
        if ((not (($xtractmode & 1) || ($i % $infoStep)))) {
            print($infoXtractText[int(($i / $infoStep))]);
        }
    }
    (my $extractedFiles = ($#outWMAfiles + 1));
    ($infoStep = int(($extractedFiles / 10)));
    ($infoStep = (($infoStep < 1) ? 1 : $infoStep));
    if (($xtractmode & 2)) {
        my($encodeParas);
        if ((not ($xtractmode & 1))) {
            print('& ');
        }
        for ((my $j = 0); ($j < $extractedFiles); (++$j)) {
            ($encodeParas = (((('"' . $outWMAfiles[$j]) . '.xwma" "') . $outWMAfiles[$j]) . '.wav"'));
            `xWMAEncode $encodeParas`;
            (unlink(($outWMAfiles[$j] . '.xwma')) or print((('Datei ' . $outWMAfiles[$j]) . ".xwma konnte nicht gel\366scht werden: $!\n")));
            if (($xtractmode & 1)) {
                print((('CONVERT ' . $outWMAfiles[$j]) . ".xwma to .wav\n"));
            }
            else {
                if ((not ($j % $infoStep))) {
                    print($infoConvText[int(($j / $infoStep))]);
                }
            }
        }
    }
    if ((not ($xtractmode & 1))) {
        print((((' ' . $extractedFiles) + $outNonWMAFiles) . " Files\n"));
    }
    $xwb->close;
    return(($extractedFiles + $outNonWMAFiles));
}
sub typ2String {
    BEGIN {
        $^H{'feature_say'} = q(1);
        $^H{'feature_state'} = q(1);
        $^H{'feature_switch'} = q(1);
    }
    (my $typ = shift(@_));
    given ($wdTyp) {
        when ((($_ < 0) or ($_ > 3))) {
            print("UNBEKANNTER AUDIOTYP $_\n");
        }
        when (($_ == 0)) {
            return('PCM ');
        }
        when (($_ == 1)) {
            return('XMA ');
        }
        when (($_ == 2)) {
            return('ADPCM');
        }
        when (($_ == 3)) {
            return('WMA');
        }
        default {
            return("UNBEKANNTES FORMAT($wdTyp)?!?");
        }
    }
}
sub mk_subdirs {
    BEGIN {
        $^H{'feature_say'} = q(1);
        $^H{'feature_state'} = q(1);
        $^H{'feature_switch'} = q(1);
    }
    (my $anzahl = @_);
    (my($dir), $rights);
    if (($anzahl == 1)) {
        ($dir = shift(@_));
        ($$rights = 511);
    }
    elsif (($anzahl == 2)) {
        (($dir, $rights) = @_);
    }
    (my(@dirs) = split(m[/], $dir, 0));
    (my $akdir = '');
    ($dir =~ s/^\s+//);
    ($dir =~ s/\s+$//);
    ($dir =~ s[^/][]);
    ($dir =~ s[/$][]);
    foreach $_ (@dirs) {
        ($akdir .= $_);
        if ((not -e($akdir))) {
            (my $res = mkdir($akdir, $rights));
            (($res != 1) and return(1));
        }
        ($akdir .= '/');
    }
    return(0);
}
