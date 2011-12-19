#line 1 "xaXsb.pm"
package xaXsb;

my $skriptName=		"xactXtract(xaXsb)";
my $skriptVersion=	0.97;

use 5.010;
use Math::BigInt;
use lib "./t";
use xaX_b;
@ISA=(xaX_b);

use constant XSB_HEADERSIZE    =>      0x008a;
use constant XSB_TOOLVERSION    =>      45;
use constant XSB_FORMATVERSION    =>      43;

use constant XTRA_WARNUNG => "WARNUNG! .xsb-Datei enthält unbekannte Strukturen. Ausgabe-Infos und Einfügen eventuell fehlerhaft\n";

my $DEBUG = 0;
my $WORD  = 2;
my $DWORD = 4;
my $QWORD = 8;
my $GUID  = 16;

sub new {
	my ($class, $iXsbname)=@_;
	my $this = {};
	$this->{HD} = ();
	$this->{CNAME}=$class;
	$this->{XSBFNAME}=$iXsbname;
	$this->{XSBFSIZE}=-s $iXsbname;
		
	bless($this, $class);
	$this->SUPER::openIF($iXsbname);
	return $this;
}

sub get {
	my ($this, $key)=@_;
	return ($this->{HD}->{$key});
}
sub set {
	if ($#_ % 2) { die $this->getCName."set: hat eine gerade Anzahl von Parametern @_"; }
	my $this = shift;
	my $key, $value;
	while (@_) {
		$key=shift;
		$value=shift;
		if (exists ($this->{HD}{$key}))	{
			if ($DEBUG) { say "addHD: lösche $key"; }
			delete $this->{HD}{$key}
		}	
		$this->{HD}->{$key}=$value;
	}	
}
sub getNum {
	my $hashref=$_[0]->getHeader();
	return (keys %$hashref);
	}

sub getCName  {		return $_[0]->{CNAME};		}
sub getIFName {		return $_[0]->{XSBFNAME}; 	}
sub getIFSize {		return $_[0]->{XSBFSIZE};	}

sub open {
	my ($this, $iXsbname)=@_;
	$this->{XSBFNAME} = $iXsbname;
	$this->{XSBFSIZE} =-s $iXsbname;
	$this->{HD} = [];
	$this->SUPER::openIF($iXsbname);
	return $this;
}

sub close {
	$_[0]->{HD}= undef;
	$_[0]->SUPER::closeIF();
}
sub readIF  { 	return $_[0]->SUPER::readIF();   }
sub readAll {
	my $this=shift;
	my $xsbSize=$this->readIF();
	if ($xsbSize < XSB_HEADERSIZE) { die $this->getCName().":".$this->getIFName()." ist zu klein für eine .xsb-Datei"; }
	my $dwSignature=$this->readStr(0,4);
	if ($dwSignature ne 'SDBK') { die $this->getIFName()."(Signatur: $dwSignature ) ist keine XACT-Soundbank"; }
	my $wVersion=$this->readW(4);
	my $wHeaderVersion=$this->readW(6);
	if (($wVersion != XSB_TOOLVERSION) and ($wHeaderVersion != XSB_FORMATVERSION)) {
		print "WARNUNG: ".$this->getIFName()." hat Toolversion $wVersion und Formatversion $wHeaderVersion.\n";
		print "$skriptName unterstuetzt nur die Versionen ",XSB_TOOLVERSION," und ",XSB_FORMATVERSION,"\n";
	}
	my $xtraChunkOff=$this->readL(0x32);

	my $xtraChunk2Off=$this->readL(0x36);

	my $soundChunkOff=$this->readL(0x46);
	my $cueChunkOff=$this->readL(0x22);
	my $unknownChunkOff=$this->readL(0x3e);
	my $cueNamTabOff=$this->readL(0x42);
	my $cueNamOff=$this->readL(0x2a);
	my $wbNamChunkOff=$this->readL(0x3a);
	if ($wbNamChunkOff != XSB_HEADERSIZE) { say "Warnung! Wavebank-Namenstabelle an unerwarteter Position: $wbNamChunkOff" };

	my $hasSoundChunk=$this->chunkExists($soundChunkOff);
	my $hasCueChunk=$this->chunkExists($cueChunkOff);
	my $hasCueNamTab=$this->chunkExists($cueNamTabOff);
	my $hasCueNamChunk=$this->chunkExists($cueNamOff);
	my $hasUnknownChunk=$this->chunkExists($unknownChunkOff);
	my $hasXtraChunk=$this->chunkExists($xtraChunkOff);
	my $haxXtraChunk2=$this->chunkExists($xtraChunk2Off);
	die $this->getIFName()." fehlt Cue Chunk oder Sound Chunk(?!?)" if ( (! $hasSoundChunk) || (! $hasCueChunk ));
	if   ($xtraChunkOff != 0xffffffff) { 
		if ($DEBUG) { print "Extra-Chunk gefunden(".hexStr($xtraChunkOff).")".XTRA_WARNUNG;  }
		}
	else { $xtraChunkOff=0; }
	if   ($xtraChunk2Off != 0xffffffff) { 
		if ($DEBUG) { print "Extra-Chunk2 gefunden(".hexStr($xtraChunk2Off).")".XTRA_WARNUNG; }
	}
	else { $xtraChunk2Off=0; }
	my $wNumStdCues=$this->readW(0x13);
	my $wNumXtraCues=$this->readW(0x15);
	my $numSounds=$this->readW(0x1c);	
	my $numWBs=unpack('C',$this->readB(0x1b));
	my $wCueSum=$this->readW(0x19);
	my $cueNamLen=$this->readW(0x1e);

	
	$this->{HD} = {
		dwVersion		=> $wVersion,
	    	dwHeaderVersion	       	=> $wHeaderVersion,
	    	numStdCues             	=> $wNumStdCues,
	    	numXtraCues            	=> $wNumXtraCues,
	    	realCueSum		=> ($this->readW(0x13) + $this->readW(0x15)),
	    	cueSum             	=> $wCueSum,
	    	numSounds             	=> $numSounds,
	    	numWBs             	=> $numWBs,
	    	wbNamChunkOff          	=> $this->readL(0x3a),	  
	    	xtraChunkOff           	=> $xtraChunkOff,
	    	xtraChunk2Off          	=> $xtraChunk2Off,
	    	soundChunkOff          	=> $soundChunkOff,
	    	cueChunkOff            	=> $cueChunkOff,
	    	unknownChunkOff        	=> $unknownChunkOff,
	    	cueNamTabOff          	=> $cueNamTabOff,
	    	cueNamOff            	=> $cueNamOff,
	    	cueNamLen            	=> $cueNamLen,	    		    		    		    		    	  		    	
	 };

	if ($DEBUG) { say "0x13: $wNumStdCues, 0x15: $wNumXtraCues, 0x19: $wCueSum, Sounds: $numSounds, WaveBanks: $numWBs"; }
	my @wbNames;
	for(my $i=0; $i < $numWBs; $i++) {
		$wbNames[$i]=$this->denull($this->readStr($wbNamChunkOff+ $i * 64,64));
	}
	$this->{HD}->{'arrWbNames'}=\@wbNames;
	if ($DEBUG) { say "Wavebanks: @wbNames"; }	
	my @cOff=( $soundChunkOff , $cueChunkOff, $unknownChunkOff, $cueNamTabOff, $cueNamOff);
	foreach (@cOff) {
		$this->SUPER::isInFile($_);
	}
	my $soundChunkLen=( $cueChunkOff > $soundChunkOff ? $cueChunkOff - $soundChunkOff : die $this->getIFName()." hat unbek. Struktur: CueChunk vor SoundChunk");

	my $nextChunkOff=
		($xtraChunkOff) ? $xtraChunkOff:
		($xtraChunk2Off) ? $xtraChunk2Off: $unknownChunkOff; 
		
	if ($nextChunkOff == 0xffffffff) {
		if ((! $hasCueNamChunk) && (! $hasCueNamChunk)) {
			say "WARNUNG: ".$this->getIFName()." hat keinen CueName Chunk";
		} else {
			die $this->getIFName()." hat CueNamTable oder CueNameChunk, aber keinen IndexChunk -> Datei nicht interpretierbar";
		}
		$nextChunkOff=$this->getIFSize();
	}
	
	my $cueChunkLen=$nextChunkOff - $cueChunkOff;
	my $cueChunkLen2=$wNumStdCues * 5 + $wNumXtraCues * 15;
	if ($cueChunkLen != $cueChunkLen2) {
		print "WARNUNG! Die cueChunkgroesse von ".$this->getIFName()." ist $cueChunkLen, sollte aber $wNumStdCues * 5 + $wNumXtraCues * 15=$cueChunkLen2 sein\n";	
	}
	my $xtraChunkLen=
		($xtraChunkOff==0) ? 0 :
		($xtraChunk2Off) ? $xtraChunk2Off-$xtraChunkOff : $unknownChunkOff-$xtraChunkOff; 
	my $xtraChunk2Len=($xtraChunk2Off==0) ? 0 : $unknownChunkOff-$xtraChunk2Off;	
	my $unknownChunkLen=( $cueNamTabOff > $unknownChunkOff ? $cueNamTabOff - $unknownChunkOff : 0);
	my $cueNamTabLen=( $cueNamOff > $cueNamTabOff ? $cueNamOff - $cueNamTabOff : 0);

	my $soundChunk=$this->readChunk($soundChunkOff,$soundChunkLen);
	my $cueChunk=$this->readChunk($cueChunkOff, $cueChunkLen);
	my $xtraChunk= $hasXtraChunk ? $this->readChunk($xtraChunkOff, $xtraChunkLen) : "";
	my $xtraChunk2= $hasXtraChunk2 ? $this->readChunk($xtraChunk2Off, $xtraChunk2Len) : "";
	my $unknownChunk=$hasUnknownChunk ? $this->readChunk($unknownChunkOff, $unknownChunkLen) : "";
	my $cueNamTab=$hasCueNamTab ? $this->readChunk($cueNamTabOff,$cueNamTabLen) : "";
	my $cueNam=$hasCueNamChunk ? $this->readChunk($cueNamOff,$cueNamLen) : "";
		

	if ($DEBUG) { 
		print "soundChunkOff $soundChunkOff, soundChunkLen $soundChunkLen";
		print "cueChunkOff $cueChunkOff, cueChunkLen $cueChunkLen\n";
		print "xtraChunkOff $xtraChunkOff, xtraChunkLen $xtraChunkLen";
		print "xtraChunk2Off $xtraChunk2Off, xtraChunk2Len $xtraChunk2Len\n";	
		print "unknownChunkOff $unknownChunkOff, unknownChunkLen $unknownChunkLen";
		print "cueNamTabOff $cueNamTabOff, cueNamTabLen $cueNamTabLen\n";	
		print "cueNamOff $cueNamOff, cueNamLen $cueNamLen\n";
	}
	
	if ($DEBUG) { print "unknownChunk:\n",printBufferHex($unknownChunk); }
	my @cueNames=split /\x00/,$cueNam;
	$this->set('soundChunkLen',$soundChunkLen, 'cueChunkLen',$cueChunkLen, 'xtraChunkLen', $xtraChunkLen,
	     'xtraChunk2Len',$xtraChunk2Len, 'unknownChunkLen',$unknownChunkLen, 'cueNamTabLen',$cueNamTabLen);
	$this->{HD}->{'arrCueNames'}=\@cueNames;
}


sub injectCue {
	my ($this,$myCueName,$myXwb,$myWavIndex,$myVolOptional)=@_;	
	my @wbNames=@{$this->{HD}->{'arrWbNames'} };
	if (! checkByteValue($myVol)) { die "Volume muss zwischen 0 und 255 liegen. Eingabe war $myVol"; }

	my $myXwbIndex=-1;
	for (my $i=0; $i < @wbNames; $i++) {
		if ($myXwb ~~ $wbNames[$i]) {
			$myXwbIndex=$i;
			last;
		}
	}
	if ($myXwbIndex==-1) { die $this->getIFName()." referenziert NICHT die Wavebank $myXwb, nur @wbNames"; }
	say "Wavebank $myXwb hat in ".$this->getIFName()." den Index $myXwbIndex";
	if (! $this->checkByteValue($myXwbIndex)) { die "Die angegebene Wavebank $myXwb konnte im WavebankChunk von $inputfilename nicht gefunden werden"; }
	


	
	my $cueNamOff=$this->get('cueNamOff');
	my $cueNamLen=$this->get('cueNamLen');
	my $myCueName=$myCueName.pack('C',0);
	my $myCueNameLen=length($myCueName);
	my $myCueNameOff=$cueNamOff+$cueNamLen;
	$this->inject($myCueNameOff,$myCueName,"cueName");
	
	my $myCueNameTabEntry=pack "C*", unpack('C4',pack('V',$myCueNameOff)), 0xff, 0xff;
	$this->inject($cueNamOff,$myCueNameTabEntry,"CueNameTabEntry");

	my $indexChunkOff=$this->get('unknownChunkOff');
	my $indexChunkLen=$this->get('unknownChunkLen');
	my $tmpCueSum=$this->get('cueSum');
	if ($tmpCueSum != ($indexChunkLen / 2)) { die "injectCue: indexChunk ist nicht doppelt so lang ($indexChunkLen) wie CueSumme $tmpCueSum\n"; }
	
	my $numXtraCues=$this->readW(0x15);
	my $numStdCues=$this->get('numStdCues');
	my $myStdCueIndex= $numStdCues;
	my @tmpIndexChunk;
	for(my $i=0; $i < $tmpCueSum; $i++) {
		$tmpIndexChunk[$i]=$this->readW($indexChunkOff+ (2 * $i));
	}	
	say "indexChunk: @tmpIndexChunk";
	my $myStdCueIndexPos=-1;
	for (my $i=0; $i < @tmpIndexChunk; $i++) {
		if ($myStdCueIndex - 1 == $tmpIndexChunk[$i]) {
			$myStdCueIndexPos=$i;
			last;
		}
	}
	$myStdCueIndexPos= ($myStdCueIndexPos == -1) ? $indexChunkLen : ( ($myStdCueIndexPos + 1) *2);
	my $myIndexEntry=pack "C*", unpack('C2',pack('v',$myStdCueIndex));

	my $cueChunkOff=$this->get('cueChunkOff'); 
	
	my $myCueOff=$cueChunkOff + 5*$numStdCues;

	my $myCue=pack "C*",0x04, unpack('C4',pack('V',$cueChunkOff));
	$this->inject($myCueOff,$myCue,"Cue");
	$myVol=$myVolOptional ? $myVolOptional : 0x5a;
	print "myVol: $myVol , ".pack('C',$myVol)." myXwbIndex: $myWavIndex\n";
	my $mySound=pack "C*",0x00, 0x01, 0x00, $myVol, 0x00, 0x00, 0x00, 0x0C, 0x00, unpack('C2',pack('v',$myWavIndex)), $myXwbIndex;
	
	$this->inject($cueChunkOff, $mySound,"Sound");
	$numStdCues++;
	$this->writeW(0x13,$numStdCues);
	my $cueSum=$numStdCues+$numXtraCues > 16 ? ($numStdCues+$numXtraCues ) : 16;
	$numSounds=1 + $this->readW(0x1c);
	$cueNamLen += $myCueNameLen;
	$this->writeW(0x19, $cueSum);
	$this->writeW(0x1c, $numSounds); 
	$this->writeW(0x1e, $cueNamLen);
	$this->set('numStdCues',$numStdCues, 'cueSum',$cueSum, 'numSounds', $numSounds,
	'cueNamLen',$cueNamLen, 'realCueSum',($numStdCues+$numXtraCues));

	say "Korrigiere Offsets....";
	
	$this->corrPointer(0x22,"cueChunkOffset");
	if ($this->get('xtraChunkOff')) { $this->corrPointer(0x32,"xtraChunkOffset"); }
	if ($this->get('xtraChunk2Off')) { $this->corrPointer(0x36,"xtraChunk2Offset"); }
	$this->corrPointer(0x3e,"unknownChunkOffset");
	$this->corrPointer(0x42,"cueNamTabOffset");
	$this->corrPointer(0x2a,"cueNamOffset");
	$this->set('cueChunkOff',$this->readL(0x22), 'unknownChunkOff',$this->readL(0x3e), 
	     'cueNamTabOff',$this->readL(0x42), 'cueNamOff',$this->readL(0x2a));
	     


	my $cueNamTabOff=$this->get('cueNamTabOff');
	my $offset;
	print "Korrigiere CueNamTab:";
	for (my $i=0; $i < ($numStdCues+$numXtraCues -1); $i++) {
		$offset=$this->readL($cueNamTabOff + $i*6);
		print "(Entry $i: pos(".($cueNamTabOff + $i*6).")= $offset->";
		$offset=$this->corrOffsetAfter($offset); 
		print "$offset )";
		$this->writeL($cueNamTabOff + $i*6,$offset);
	}
	$offset=$this->corrOffsetBefore($this->readL($cueNamTabOff + ($numStdCues+$numXtraCues -1)*6));
	$this->writeL($cueNamTabOff + ($numStdCues+$numXtraCues -1)*6,$offset);
	print "\n";
	$this->recalcChecksum();
}

sub recalcChecksum {
	my $this = shift;
	my $checksum=$this->calcFCS16old();
	my $oldChecksum=$this->readW(0x08);
	if ($checksum == $oldChecksum) {
		print $this->getIFName()." : Checksumme $oldChecksum ist bereits korrekt\n";
		return 0;
	} else {
		print $this->getIFName()." : Ändere Checksumme: $oldChecksum -> $checksum\n";
		$this->writeW(0x08,$checksum);
		return 1;
	}
}
sub info {
	my $this = shift;
	my $fcs=$this->calcFCS16();
	if ($fcs != $this->readW(8)) { die "Checksumme falsch. Berechnet ".dhexStr($fcs).", in Datei: ".$this->getIFName(); }
	my @res=$this->info4Release();
	print "\n";
	return @res;
}

sub info4Debug {
	my $this = shift;
	print "\XSB-INFO";

	print "\n".$this->getIFName()." : Version (".$this->get('dwVersion').",".$this->get('dwHeaderVersion')."), ";
	print $this->get('numStdCues')." Std-Cues,";
	say $this->get('numXtraCues')." ExtraCues, angegeb.Cue-Summe: ".$this->get('cueSum');
	my @wbNames=@{$this->{HD}->{'arrWbNames'} };
	print "Nutzt ".$this->get('numWBs')." Wavebank(s): @wbNames\n";
	my @cueNames=@{$this->{HD}->{'arrCueNames'} };
	print "".($#cueNames +1)." Cues: @cueNames\n";
	my $hashdataref=($this->{HD}) ? $this->{HD} : return 0;
	my %hd=%$hashdataref;
	if ($DEBUG) { print map { "$_ => $hd{$_}\n" } keys %hd; }

		
	return 1;
}
sub info4Release { 
	my $this = shift;
	my $numStdCues=$this->get('numStdCues');
	my @wbNames=@{$this->{HD}->{'arrWbNames'} };
	print "\nINFO ".$this->getIFName();
	print ": Version (".$this->get('dwVersion').",".$this->get('dwHeaderVersion')."), ";
	say "$numStdCues StdCues,".$this->get('numXtraCues')." ExtraCues, ".$this->get('numSounds')." Sounds";
	say  $this->get('numWBs')." Wavebank(s): @wbNames";

	my $xtraChunks= ($this->get('xtraChunkLen')) ? 1 : 0;
	$xtraChunks+=($this->get('xtraChunk2Len'))   ? 1 : 0;
	my $realCueSum=$this->get('realCueSum');
	my $cueSum=$this->get('cueSum');
	my $warning=0;		
	if ($xtraChunks) { 
		say "Extra-Chunk(s) gefunden ($xtraChunks)";
		$warning+=$xtraChunks; 
	}

	my $cueChunkOff=$this->get('cueChunkOff');
	my $cueChunkLen=$this->get('cueChunkLen');
	my $cueChunk=$this->readChunk($cueChunkOff, $cueChunkLen);
	my @cueNames=@{$this->{HD}->{'arrCueNames'} };
	my $cue, $sound, $soundOff, $soundLen, $wbNam, $wavIndex;
	say "Cue-Name                      |Soundtyp | Wavebankname+Index";
	say "------------------------------|---------|----------------------------------";
	for (my $i=0; $i<$numStdCues; $i++) {
		printf "%-30s",$cueNames[$i];
		$cue=$this->readStr($cueChunkOff + $i * 5, 5);
		if ($DEBUG) { say "Cue: ".printBufferHex($cue); }
		($sound, $soundOff, $soundLen)=$this->getSoundFromStdCue($cue);
		if ($soundLen != 12) { say " NonStd,$soundLen\B"; }
		else {
			($wbNam,$wavIndex)=$this->getWBFromStdSoundPos($soundOff);
			printf "%-11s %-30s\n", "->Std->", $wbNam."_".$wavIndex;
		}
	}
	return ($numStdCues, $this->get('numXtraCues'), $this->get('numSounds')); 
}


sub info4Table {
	my $this = shift;
	my $numStdCues=$this->get('numStdCues');
	print $this->getIFName()."\t";
	print "$numStdCues \t".$this->get('numXtraCues')."\t";
	print $this->get('cueSum')."\t".$this->get('numSounds')."\t".$this->get('numWBs');
	
	print "\t".$this->get('soundChunkOff')."\t".$this->get('soundChunkLen');
	print "\t".$this->get('cueChunkOff')."\t".$this->get('cueChunkLen');
	print "\t".$this->get('xtraChunkOff')."\t".$this->get('xtraChunkLen');
	print "\t".$this->get('xtraChunk2Off')."\t".$this->get('xtraChunk2Len');
	print "\t".$this->get('unknownChunkOff')."\t".$this->get('unknownChunkLen');
	print "\t".$this->get('cueNamTabOff')."\t".$this->get('cueNamTabLen');
	print "\t".$this->get('cueNamOff')."\t".$this->get('cueNamLen');
	
	my $xtraChunks= ($this->get('xtraChunkLen')) ? 2 : 0;
	$xtraChunks+=($this->get('xtraChunk2Len'))   ? 4 : 0;
	my $realCueSum=$this->get('realCueSum');
	my $cueSum=$this->get('cueSum');
	my $warning=0;		
	if ($cueSum != $realCueSum) {
		$warning+=1;
	} 
	if ($xtraChunks) { 
		$warning+=$xtraChunks; 
	}
	
	print "\t".$this->readW(0x10)."\t".$this->readBVal(0x12);
	print "\t".$this->readW(0x17)."\t".$this->readW(0x20);
	my $unOff=$this->readL(0x26);
	my $unOff2=$this->readL(0x2e);
	print "\t".hexStr($unOff)."\t".hexStr($unOff2);
	print "\n";
	
			
	my $cueChunkOff=$this->get('cueChunkOff');
	my $cueChunkLen=$this->get('cueChunkLen');
	my $cueChunk=$this->readChunk($cueChunkOff, $cueChunkLen);
	my @cueNames=@{$this->{HD}->{'arrCueNames'} };
	my $cue, $sound, $soundOff, $soundLen, $wbNam, $wavIndex;
	for (my $i=0; $i<$numStdCues; $i++) {
		$cue=$this->readStr($cueChunkOff + $i * 5, 5);
		if ($DEBUG) { say "Cue: ".printBufferHex($cue); }
		($sound, $soundOff, $soundLen)=$this->getSoundFromStdCue($cue);
		if ($soundLen != 12) { 
		}
		else {
			($wbNam,$wavIndex)=$this->getWBFromStdSoundPos($soundOff);
		}
	}
}
sub getSoundFromStdCue {
	my ($this,$cue)=@_;
	if (length($cue) != 5) { die "getSoundFromStdCue: StdCue $cue hat falsche Länge ".length($cue); }
	my $soundPos=unpack('L',substr($cue,1,4));
	return $this->getSoundFromPos($soundPos);
}
sub getSoundFromPos {
	my ($this,$soundPos)=@_;
	if ($DEBUG) { print "Soundpos: $soundPos,"; }
	my $soundLength=$this->readBVal($soundPos + 7);
	my $sound=$this->readStr($soundPos,$soundLength); 
	
	if ($DEBUG) { print "SoundLen: $soundLength,"; }
	if ($soundLength != 12) {
		if ($DEBUG) { print "kein StdSound"; }
	}
	if ($DEBUG) { say "\nSound: ".printBufferHex($sound); }
	return ($sound, $soundPos, $soundLength);	
}

sub getWBFromStdSoundPos {
	my ($this,$soundPos)=@_;
	if ($this->readBVal($soundPos + 7) != 12) { die "getWBFromStdSound: StdSound ($soundPos) hat falsche Länge"; }
	my $wavIndex=$this->readW($soundPos + 9);
	my $wbNum=$this->readBVal($soundPos + 11);
	my @wbNames=@{$this->{HD}->{'arrWbNames'} };
	my $wb=$wbNames[$wbNum];
	if ($DEBUG) { say "soundPos: $soundPos, wavIndex: $wavIndex, wbNum $wbNum, wbName $wb"; }
	return ($wb, $wavIndex);
}

sub readCue {
	my ($this,$cIndex)=@_;
	my $realCueSum=$this->get('realCueSum'), $numStdCues=$this->get('numStdCues');
	my $myCue, @myCueOff;
	if ($cIndex+1 > $realCueSum) { die "readCue mit Index. $cIndex aufgerufen, aber nur $realCueSum Cues vorhanden"; }
	if ($cIndex < $numStdCues) {
		$myCue=$this->readStr($this->get('cueChunkOff') + 5*$cIndex, 5);
		$myCueOff[0]=$this->readL($this->get('cueChunkOff') + 5*$cIndex +1);
		return ($myCue, @myCueOff);
	}
	print "Non-Standard Cues können noch nicht gelesen werden(CueIndex $cIndex)";
	return  ($myCue, @myCueOff);
	}
sub readChunk {
	my ($this,$position, $len)=@_;
	return $this->readStr($position,$len);
}
sub chunkExists {
	my ($this,$offs)=@_;
	if ( ($offs == 0) || ($offs == 0xffffffff) ) { return 0; }	
	return ($this->SUPER::isInFile($offs) ? 1 : 0);
}

sub calcFCS16old {
	my $this = shift;
	my $dataLen=$this->getDSize();
	if ($dataLen < XSB_HEADERSIZE) { die "calcFCS16: ".$this->getIFName()." Pufferinhalt zu klein: $dataLen"; }
	my @arrFCS16 = ( 0x0, 0x1189, 0x2312, 0x329B, 0x4624, 0x57AD, 0x6536, 0x74BF, 0x8C48,
	0x9DC1, 0xAF5A, 0xBED3, 0xCA6C, 0xDBE5, 0xE97E, 0xF8F7, 
     	0x1081, 0x108, 0x3393, 0x221A, 0x56A5, 0x472C, 0x75B7, 0x643E, 0x9CC9,
	0x8D40, 0xBFDB, 0xAE52, 0xDAED, 0xCB64, 0xF9FF, 0xE876, 
     	0x2102, 0x308B, 0x210, 0x1399, 0x6726, 0x76AF, 0x4434, 0x55BD, 0xAD4A,
	0xBCC3, 0x8E58, 0x9FD1, 0xEB6E, 0xFAE7, 0xC87C, 0xD9F5, 
     	0x3183, 0x200A, 0x1291, 0x318, 0x77A7, 0x662E, 0x54B5, 0x453C, 0xBDCB,
	0xAC42, 0x9ED9, 0x8F50, 0xFBEF, 0xEA66, 0xD8FD, 0xC974, 
     	0x4204, 0x538D, 0x6116, 0x709F, 0x420, 0x15A9, 0x2732, 0x36BB, 0xCE4C,
	0xDFC5, 0xED5E, 0xFCD7, 0x8868, 0x99E1, 0xAB7A, 0xBAF3, 
     	0x5285, 0x430C, 0x7197, 0x601E, 0x14A1, 0x528, 0x37B3, 0x263A, 0xDECD,
	0xCF44, 0xFDDF, 0xEC56, 0x98E9, 0x8960, 0xBBFB, 0xAA72, 
     	0x6306, 0x728F, 0x4014, 0x519D, 0x2522, 0x34AB, 0x630, 0x17B9, 0xEF4E,
	0xFEC7, 0xCC5C, 0xDDD5, 0xA96A, 0xB8E3, 0x8A78, 0x9BF1, 
     	0x7387, 0x620E, 0x5095, 0x411C, 0x35A3, 0x242A, 0x16B1, 0x738, 0xFFCF,
	0xEE46, 0xDCDD, 0xCD54, 0xB9EB, 0xA862, 0x9AF9, 0x8B70, 
     	0x8408, 0x9581, 0xA71A, 0xB693, 0xC22C, 0xD3A5, 0xE13E, 0xF0B7, 0x840,
	0x19C9, 0x2B52, 0x3ADB, 0x4E64, 0x5FED, 0x6D76, 0x7CFF, 
     	0x9489, 0x8500, 0xB79B, 0xA612, 0xD2AD, 0xC324, 0xF1BF, 0xE036,
	0x18C1, 0x948, 0x3BD3, 0x2A5A, 0x5EE5, 0x4F6C, 0x7DF7, 0x6C7E, 
     	0xA50A, 0xB483, 0x8618, 0x9791, 0xE32E, 0xF2A7, 0xC03C, 0xD1B5,
	0x2942, 0x38CB, 0xA50, 0x1BD9, 0x6F66, 0x7EEF, 0x4C74, 0x5DFD, 
     	0xB58B, 0xA402, 0x9699, 0x8710, 0xF3AF, 0xE226, 0xD0BD, 0xC134,
	0x39C3, 0x284A, 0x1AD1, 0xB58, 0x7FE7, 0x6E6E, 0x5CF5, 0x4D7C, 
     	0xC60C, 0xD785, 0xE51E, 0xF497, 0x8028, 0x91A1, 0xA33A, 0xB2B3,
	0x4A44, 0x5BCD, 0x6956, 0x78DF, 0xC60, 0x1DE9, 0x2F72, 0x3EFB, 
     	0xD68D, 0xC704, 0xF59F, 0xE416, 0x90A9, 0x8120, 0xB3BB, 0xA232,
	0x5AC5, 0x4B4C, 0x79D7, 0x685E, 0x1CE1, 0xD68, 0x3FF3, 0x2E7A, 
     	0xE70E, 0xF687, 0xC41C, 0xD595, 0xA12A, 0xB0A3, 0x8238, 0x93B1,
	0x6B46, 0x7ACF, 0x4854, 0x59DD, 0x2D62, 0x3CEB, 0xE70, 0x1FF9, 
     	0xF78F, 0xE606, 0xD49D, 0xC514, 0xB1AB, 0xA022, 0x92B9, 0x8330,
	0x7BC7, 0x6A4E, 0x58D5, 0x495C, 0x3DE3, 0x2C6A, 0x1EF1, 0xF78);
	my $fcs=65535;
	my $arrPointer, $arrElement, $actDatabyte;
	for (my $i=18; $i < $dataLen; $i++) {
		$actDatabyte=$this->readBVal($i);
		$arrPointer=($fcs ^ $actDatabyte) & 0xff;
		$arrElement=$arrFCS16[$arrPointer];
		$fcs=int($fcs / 256);
		$fcs=$fcs ^ $arrElement;
	}
	my $fcsComplement= $fcs ^ 65535;
	my $fcsHigh=$fcsComplement & 0xff;
	$fcsComplement=int($fcsComplement/256);
	my $fcsLow=$fcsComplement & 0xff;
	$fcs=$fcsLow * 256 + $fcsHigh;
	return $fcs;
}
sub calcFCS16 {
	my $this = shift;

	my $dataLen=$this->getDSize() -18;
	my $data=$this->readStr(18,$dataLen);
	if ($dataLen < XSB_HEADERSIZE) { die "calcFCS16: ".$this->getIFName()." Pufferinhalt zu klein: $dataLen"; }
	return $this->calcFCS16FromByteString($data);
}

sub calcFCS16FromByteString {
	my ($this,$myString)=@_;
	my $dataLen=length($myString);	
	my @arrFCS16 = ( 0x0, 0x1189, 0x2312, 0x329B, 0x4624, 0x57AD, 0x6536, 0x74BF, 0x8C48,
	0x9DC1, 0xAF5A, 0xBED3, 0xCA6C, 0xDBE5, 0xE97E, 0xF8F7, 
     	0x1081, 0x108, 0x3393, 0x221A, 0x56A5, 0x472C, 0x75B7, 0x643E, 0x9CC9,
	0x8D40, 0xBFDB, 0xAE52, 0xDAED, 0xCB64, 0xF9FF, 0xE876, 
     	0x2102, 0x308B, 0x210, 0x1399, 0x6726, 0x76AF, 0x4434, 0x55BD, 0xAD4A,
	0xBCC3, 0x8E58, 0x9FD1, 0xEB6E, 0xFAE7, 0xC87C, 0xD9F5, 
     	0x3183, 0x200A, 0x1291, 0x318, 0x77A7, 0x662E, 0x54B5, 0x453C, 0xBDCB,
	0xAC42, 0x9ED9, 0x8F50, 0xFBEF, 0xEA66, 0xD8FD, 0xC974, 
     	0x4204, 0x538D, 0x6116, 0x709F, 0x420, 0x15A9, 0x2732, 0x36BB, 0xCE4C,
	0xDFC5, 0xED5E, 0xFCD7, 0x8868, 0x99E1, 0xAB7A, 0xBAF3, 
     	0x5285, 0x430C, 0x7197, 0x601E, 0x14A1, 0x528, 0x37B3, 0x263A, 0xDECD,
	0xCF44, 0xFDDF, 0xEC56, 0x98E9, 0x8960, 0xBBFB, 0xAA72, 
     	0x6306, 0x728F, 0x4014, 0x519D, 0x2522, 0x34AB, 0x630, 0x17B9, 0xEF4E,
	0xFEC7, 0xCC5C, 0xDDD5, 0xA96A, 0xB8E3, 0x8A78, 0x9BF1, 
     	0x7387, 0x620E, 0x5095, 0x411C, 0x35A3, 0x242A, 0x16B1, 0x738, 0xFFCF,
	0xEE46, 0xDCDD, 0xCD54, 0xB9EB, 0xA862, 0x9AF9, 0x8B70, 
     	0x8408, 0x9581, 0xA71A, 0xB693, 0xC22C, 0xD3A5, 0xE13E, 0xF0B7, 0x840,
	0x19C9, 0x2B52, 0x3ADB, 0x4E64, 0x5FED, 0x6D76, 0x7CFF, 
     	0x9489, 0x8500, 0xB79B, 0xA612, 0xD2AD, 0xC324, 0xF1BF, 0xE036,
	0x18C1, 0x948, 0x3BD3, 0x2A5A, 0x5EE5, 0x4F6C, 0x7DF7, 0x6C7E, 
     	0xA50A, 0xB483, 0x8618, 0x9791, 0xE32E, 0xF2A7, 0xC03C, 0xD1B5,
	0x2942, 0x38CB, 0xA50, 0x1BD9, 0x6F66, 0x7EEF, 0x4C74, 0x5DFD, 
     	0xB58B, 0xA402, 0x9699, 0x8710, 0xF3AF, 0xE226, 0xD0BD, 0xC134,
	0x39C3, 0x284A, 0x1AD1, 0xB58, 0x7FE7, 0x6E6E, 0x5CF5, 0x4D7C, 
     	0xC60C, 0xD785, 0xE51E, 0xF497, 0x8028, 0x91A1, 0xA33A, 0xB2B3,
	0x4A44, 0x5BCD, 0x6956, 0x78DF, 0xC60, 0x1DE9, 0x2F72, 0x3EFB, 
     	0xD68D, 0xC704, 0xF59F, 0xE416, 0x90A9, 0x8120, 0xB3BB, 0xA232,
	0x5AC5, 0x4B4C, 0x79D7, 0x685E, 0x1CE1, 0xD68, 0x3FF3, 0x2E7A, 
     	0xE70E, 0xF687, 0xC41C, 0xD595, 0xA12A, 0xB0A3, 0x8238, 0x93B1,
	0x6B46, 0x7ACF, 0x4854, 0x59DD, 0x2D62, 0x3CEB, 0xE70, 0x1FF9, 
     	0xF78F, 0xE606, 0xD49D, 0xC514, 0xB1AB, 0xA022, 0x92B9, 0x8330,
	0x7BC7, 0x6A4E, 0x58D5, 0x495C, 0x3DE3, 0x2C6A, 0x1EF1, 0xF78);
	my $fcs=65535;
	my $arrPointer, $arrElement, $actDatabyte;
	for (my $i=0; $i < $dataLen; $i++) {
		$actDatabyte=unpack('C',substr($myString,$i,1));
		$arrPointer=($fcs ^ $actDatabyte) & 0xff;
		$arrElement=$arrFCS16[$arrPointer];
		$fcs=int($fcs / 256);
		$fcs=$fcs ^ $arrElement;
	}
	my $fcsComplement= $fcs ^ 65535;
	my $fcsHigh=$fcsComplement & 0xff;
	$fcsComplement=int($fcsComplement/256);
	my $fcsLow=$fcsComplement & 0xff;
	$fcs=$fcsLow * 256 + $fcsHigh;
	return $fcs;
	}
sub dhexStr {
	my $value=shift;
	return "$value(\$".hexStr($value).")";
}
sub hexStr {
	my $value=shift;
	return sprintf("%x",$value);
}

sub printBufferHex {
	my $buffer=shift;
	my $newline=16;
	my $counter=0;
	my $result="";
	my @resBuffer=unpack('C*',$buffer);
	foreach (@resBuffer) {
		$result=$result.sprintf("%02x ",$_);
		if ($counter < $newline) { $counter++; }
		else {
			$result=$result."\n";
			$counter=0;
			}
	}
	return $result;
	}


sub denull {
    my ($this,$string)=@_;
    $string =~ s/\0//g if defined $string;
    return $string;
}

sub checkByteValue {
	my ($this,$myVal)=@_;
	return (($myVal > -1) && ($myVal < 256)) ? 1 : 0;
}
sub readB {
	return $_[0]->SUPER::readString($_[1], 1);   }
sub readBVal {
	$_[0]->SUPER::readByte($_[1]);   }	
sub readW {
	return $_[0]->SUPER::readWord($_[1]);   }
sub readL {	
	return $_[0]->SUPER::readLong($_[1]);   }
sub readStr {
	return $_[0]->SUPER::readString($_[1],$_[2]);   }
sub getDSize {
	return $_[0]->SUPER::getDSize();	}
	
sub writeB {
	$_[0]->SUPER::writeByte($_[1],$_[2]);   }
sub writeW {
	$_[0]->SUPER::writeWord($_[1],$_[2]);   }
sub writeL {
	$_[0]->SUPER::writeLong($_[1],$_[2]);   }
sub writeStr {
	$_[0]->SUPER::writeString($_[1],$_[2],$_[3]);   }
sub writeBytes {
	$_[0]->SUPER::writeBytes($_[1],$_[2],$_[3]);   }
		
sub inject {
	$_[0]->SUPER::inject($_[1],$_[2],$_[3]);   }
sub infoInject {	
	$_[0]->SUPER::infoInject(); 	}
sub corrOffsetAfter {
	return $_[0]->SUPER::corrOffsetAfter($_[1]);   }	
sub corrOffsetBefore {
	return $_[0]->SUPER::corrOffsetBefore($_[1]);   }	
sub corrPointer {
	return $_[0]->SUPER::corrPointer($_[1],$_[2]);   }		
sub renameWriteAndClose {
	return $_[0]->SUPER::IFRenameWriteAndClose($_[1]);   }	
	
	
1;