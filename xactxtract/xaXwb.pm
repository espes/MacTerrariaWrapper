#line 1 "xaXwb.pm"
package xaXwb;

my $skriptName=		"xaXwb.pm";
my $skriptVersion=	0.97;

use 5.010;
use Math::BigInt;
use lib "./t";
use xaX_b;
@ISA=(xaX_b);



use constant XWB_HEADERSIZE  =>  52;
use constant WAVEBANK_TYPE_BUFFER    =>      0x00000000;
use constant WAVEBANK_TYPE_STREAMING  =>     0x00000001;
use constant WAVEBANK_TYPE_MASK     =>       0x00000001;

use constant WAVEBANKMINIFORMAT_TAG_PCM   =>   0x0;
use constant WAVEBANKMINIFORMAT_TAG_XMA   =>   0x1;
use constant WAVEBANKMINIFORMAT_TAG_ADPCM =>   0x2;
use constant WAVEBANKMINIFORMAT_TAG_WMA   =>   0x3;



sub new {
	my ($class, $iXwbname, $safeMode)=@_;
	my $this = {};
	$this->{HD} = ();
	$this->{CNAME}=$class;
	$this->{XWBFNAME}=$iXwbname;
	$this->{XWBFSIZE}=-s $iXwbname;
	$this->{SAFEMODE}=$safeMode;
	bless($this, $class);
	$this->SUPER::openIF($iXwbname);
	return $this;
}
sub getCName {
	my $this=shift;
	return $this->{CNAME};
}
sub getSafeMode {
	my $this=shift;
	return $this->{SAFEMODE};	
}
sub getIFName {
	my $this=shift;
	return $this->{XWBFNAME};
}
sub getIFSize {
	my $this=shift;
	return $this->{XWBFSIZE};	
}

sub open {
	my ($this, $iXwbname)=@_;
	$this->{XWBFNAME} = $iXwbname;
	$this->{XWBFSIZE} =-s $iXwbname;
	$this->{HD} = [];
	$this->SUPER::openIF($iXwbname);
	return $this;
}

sub close {
	my $this=shift;
	$this->SUPER::closeIF();
	$this->{HD}= undef;
}

sub injectWav {
	print "$this->{CNAME}:injectWav: TODO\n";
}

sub info	{
	my $this=shift;
	print "---WAVEBANK ".$this->getIFName().": ";
	my $headerref=($this->{HD}) ? $this->{HD} : return 0;
	my %header=%$headerref;
	print "Version (".$this->getHD('dwVersion').",".$this->getHD('dwHeaderVersion')."), Typ: ";
	my $isStreamingWB=$this->getHD('wbTyp');
	if ($isStreamingWB == WAVEBANK_TYPE_STREAMING) { print "Streaming"; }
	else { print "In-Memory"; }
	my $waves=   $this->getHD('dwEntryCount');
	say ", $waves Waves";


	my @wdFlags=@{$this->{HD}->{'arrWdFlags'} };
	my @wdDur=  @{$this->{HD}->{'arrWdDur'}   };
	my @wdTyp=  @{$this->{HD}->{'arrWdTyp'}   };
	my @wdChan= @{$this->{HD}->{'arrWdChan'}  };
	my @wdRate= @{$this->{HD}->{'arrWdRate'}  };
	my @wdAlign=@{$this->{HD}->{'arrWdAlign'} };
	my @wdPCM16=@{$this->{HD}->{'arrWdPCM16'} };
	my @wdOff=  @{$this->{HD}->{'arrWdOff'}   };
	my @wdLen=  @{$this->{HD}->{'arrWdLen'}   };
	my $pcmNum=0, $xmaNum=0,$adpcmNum=0, $wmaNum=0;
	print "Wave|     |        |    | Chan-|          |     |16bit|in WAVEDATASEGMENT\n";
	print "Nr. |Flags|Duration| Typ|  nels|SampleRate|Align| PCM?|   Offset    Length\n";
	print "--------------------------------------------------------------------------\n";
	for(my $i=0; $i<$waves; $i++) {
		printf "%4d %4d %9d", $i,$wdFlags[$i],$wdDur[$i];
		given($wdTyp[$i]) {
			when (($_ < 0) or ($_ > 3)) { print "UNBEKANNTER AUDIOTYP $_\n"; }
			when($_ == WAVEBANKMINIFORMAT_TAG_PCM) { print "   PCM"; $pcmNum++; continue;}
			when($_ == WAVEBANKMINIFORMAT_TAG_XMA) { print "   XMA"; $xmaNum++; continue;}
			when($_ == WAVEBANKMINIFORMAT_TAG_ADPCM) { print " ADPCM"; $adpcmNum++; continue;}		
			when($_ == WAVEBANKMINIFORMAT_TAG_WMA) { print "   WMA"; $wmaNum++; continue;}	
			default	{ printf "%6d %10d %5d %5d %9d %9d\n", $wdChan[$i], $wdRate[$i], $wdAlign[$i], $wdPCM16[$i], $wdOff[$i], $wdLen[$i];}
		}
	}
	if ($DEBUG) { print map { "$_ => $header{$_}\n" } keys %header; }
	print "Insges.: ";
	print "$pcmNum PCM," if $pcmNum;
	print "$xmaNum XMA," if $xmaNum;
	print "$adpcmNum ADPCM," if $adpcmNum;
	print "$wmaNum WMA" if $wmaNum; 
	print "\n";
	return ($isStreamingWB,$pcmNum, $xmaNum,$adpcmNum, $wmaNum);	
}
sub getHeader {
 my $this = shift;
 return $this->{HD};
}
sub getHD {
	my ($this, $key)=@_;
	return ($this->{HD}->{$key});
}
sub setHD {
	my ($this, $key, $value)=@_;
	if (exists ($this->{HD}{$key}))	{
		if ($DEBUG) { say "addHD: lösche $key"; }
		delete $this->{HD}{$key}
	}	
	$this->{HD}->{$key}=$value;
}

sub getHDnum {
	my $this=shift;
	my $hashref=$this->getHeader();
	return (keys %$hashref);
	}
sub readHeader	{
	my $this=shift;
	$this->SUPER::readIF(XWB_HEADERSIZE);
	my $dwSignature=$this->readStr(0,4);
	if (($dwSignature ne 'DNBW') && ($dwSignature ne 'WBND')) {
		die "Fehler: $this->{XWBFNAME} (Signatur: $dwSignature ) ist keine XACT-Wavebank";
	}
	my $bEndian = $dwSignature ne 'WBND';
	my $dwVersion=$bEndian ? $this->readLBE(4) : $this->readL(4);	
	my $dwHeaderVersion=$bEndian ? $this->readLBE(8) : $this->readL(8);
	if (($dwVersion != 45) or ($dwHeaderVersion != 43)) {
		print "WARNUNG: $this->{XWBFNAME} hat Toolversion $dwVersion und Formatversion $dwHeaderVersion.\n";
		print "$skriptName unterstuetzt nur die Versionen 45 und 43\n";
	}
	if ($DEBUG) { say "Version: $dwVersion,$dwHeaderVersion"};
	$this->{HD} = {
	    dwVersion		       => $dwVersion,
	    dwHeaderVersion	       => $dwHeaderVersion,
	    segBankDataOff             => $bEndian ? $this->readLBE(12) : $this->readL(12),
	    segBankDataLen             => $bEndian ? $this->readLBE(16) : $this->readL(16),
	    segEntryMetaOff             => $bEndian ? $this->readLBE(20) : $this->readL(20),
	    segEntryMetaLen             => $bEndian ? $this->readLBE(24) : $this->readL(24),
	    segSeekTabOff             => $bEndian ? $this->readLBE(28) : $this->readL(28),
	    segSeekTabLen             => $bEndian ? $this->readLBE(32) : $this->readL(32),
	    anzRegions			=> 5,
	    };
	given($this->getHD('segBankDataOff')) {
	when($_ == 52) { 
	 	if ($DEBUG) {print "WAVEBANKHEADER hat korrekte Laenge\n";}
	 	$this->setHD('segWaveDatOff',$bEndian ? $this->readLBE(44) : $this->readL(44));
	 	$this->setHD('segWaveDatLen',$bEndian ? $this->readLBE(48) : $this->readL(48));
	 	}	 	 
	when($_ <  52) { print "WARNUNG: WAVEBANKHEADER zu klein\n"; continue}
	when($_ >  43) {
		$this->setHD('anzRegions',4);
		$this->setHD('segWaveDatOff',$bEndian ? $this->readLBE(36) : $this->readL(36));
	 	$this->setHD('segWaveDatLen',$bEndian ? $this->readLBE(40) : $this->readL(40));
	}
	
	default	     { die "WAVEBANKHEADER von $this->{XWBFNAME} scheint defekt\n"}
	}
	my $segWaveDatOff=$this->getHD('segWaveDatOff');
	my $segWaveDatLen=$this->getHD('segWaveDatLen');
	if ($segWaveDatOff == 0 || $segWaveDatLen==0) { die "FEHLER: WAVEDATA Segment: Offset: $segWaveDatOff  ,Laenge: $segWaveDatLen"; }
	if ($DEBUG) {
	  say "WAVEBANKREGION 1: WAVEBANKDATA.  Offset ".$this->getHD('segBankDataOff').", Laenge ".$this->getHD('segBankDataLen');
	  say "WAVEBANKREGION 2: ENTRYMETADATA. Offset ".$this->getHD('segEntryMetaOff').", Laenge ".$this->getHD('segEntryMetaLen');
	  say "WAVEBANKREGION 3: SEEKTABLES. Offset ".$this->getHD('segSeekTabOff').", Laenge ".$this->getHD('segSeekTabLen');
	  say "WAVEBANKREGION $AnzRegions : WAVEDATA. Offset ".$this->getHD('segWaveDatOff').", Laenge ".$this->getHD('segWaveDatLen');
	}
	my $infoSegSize=$this->getHD('segBankDataLen') + $this->getHD('segEntryMetaLen') + $this->getHD('segSeekTabLen'); 
	if ( (XWB_HEADERSIZE + $infoSegSize + $segWaveDatLen) > $this->getIFSize()) {
		die "$this->{CNAME}:readHeader: Längenangaben im Header von $this->{XWBFNAME} fehlerhaft; Datei zu kurz\n";
	}



	$this->SUPER::readIF($infoSegSize);

	my $pos=$this->getHD('segBankDataOff');
	if ($DEBUG) { print "WAVEBANKDATA:\n"; }

	my $wbd_dwFlags=$bEndian ? $this->readLBE($pos) : $this->readL($pos);
	$this->setHD('wbTyp', $wbd_dwFlags && WAVEBANK_TYPE_MASK);
	my $szBankName=$this->readStr($pos+8,64);
	if ($DEBUG) {  print "Wavebank Name: ",$szBankName,"\n"; }
	$this->setHD('szBankName',$szBankName);
	my $dwEntryCount=$bEndian ? $this->readLBE($pos+4) : $this->readL($pos+4);
	$this->setHD('dwEntryCount',$dwEntryCount);
	if ($DEBUG) { print "Anzahl Entries/Wavs: $dwEntryCount\n"; }
	my $dwEntryMetaDataElementSize=$bEndian ? $this->readLBE($pos+72) : $this->readL($pos+72);
	my $dwEntryNameElementSize=$bEndian ? $this->readLBE($pos+76) : $this->readL($pos+76);
	if ($DEBUG) { 
		print "Laenge eines WAVEBANKENTRY in ENTRYMETADATA: $dwEntryMetaDataElementSize \n";
		print "Laenge eines WAVENAMENS in ENTRYNAMES: $dwEntryNameElementSize \n";
	}
	
	$pos=$this->getHD('segEntryMetaOff');
	my @wdFlags=[];
	my @wdDur=[];
	my @wdTyp=[];
	my @wdChan=[];
	my @wdRate=[];
	my @wdAlign=[];
	my @wdPCM16=[];
	my @wdOff=[];
	my @wdLen=[];
	if ($DEBUG) { 
		print "Wave|     |        |    | Chan-|          |     |16bit|in WAVEDATASEGMENT\n";
		print "Nr. |Flags|Duration| Typ|  nels|SampleRate|Align| PCM?|   Offset    Length\n";
		print "--------------------------------------------------------------------------\n";
	}
	my $wdTotalLength=0;
	for(my $i=0; $i<$dwEntryCount; $i++) {
		($wdFlags[$i], $wdDur[$i])=$bEndian ? $this->readENTRYdwFlagsBE($pos) : $this->readENTRYdwFlags($pos);
		($wdTyp[$i],$wdChan[$i],$wdRate[$i],$wdAlign[$i],$wdPCM16[$i])=$bEndian ? $this->readMINIWAVEFORMATBE($pos+4) : $this->readMINIWAVEFORMAT($pos+4);
		$wdOff[$i]=$bEndian ? $this->readLBE($pos+8) : $this->readL($pos+8);
		$wdLen[$i]=$bEndian ? $this->readLBE($pos+12) : $this->readL($pos+12);
		$pos+=$dwEntryMetaDataElementSize;
		if ($DEBUG) { printf "%4d %4d %9d", $i,$wdFlags[$i],$wdDur[$i]; }
		if ($DEBUG) { 
			given($wdTyp[$i]) {
				when (($_ < 0) or ($_ > 3)) { print "UNBEKANNTER AUDIOTYP $_\n"; }
				when($_ == WAVEBANKMINIFORMAT_TAG_PCM) { print "   PCM"; continue;}
				when($_ == WAVEBANKMINIFORMAT_TAG_XMA) { print "   XMA"; continue;}
				when($_ == WAVEBANKMINIFORMAT_TAG_ADPCM) { print " ADPCM"; continue;}		
				when($_ == WAVEBANKMINIFORMAT_TAG_WMA) { print "   WMA"; continue;}	
				default	{ printf "%6d %10d %5d %5d %9d %9d\n", $wdChan[$i], $wdRate[$i], $wdAlign[$i], $wdPCM16[$i], $wdOff[$i], $wdLen[$i]; }
			}
		}
		$wdTotalLength+=$wdLen[$i];
		if ( $wdTotalLength > $segWaveDatLen) {
			die "Fehler in ".$this->getIFName()." : Entrymetadata-Segment zu kurz (?!?)\n";
		}
		if ($wdLen[$i] < 4) {
			die "Fehler in ".$this->getIFName()." : Wave-Datei Nr. $i zu kurz (",$wdLen[$i]," Byte)\n";
		}
	
	}
	$this->{HD}->{'arrWdFlags'}=\@wdFlags;
	$this->{HD}->{'arrWdDur'}=\@wdDur;
	$this->{HD}->{'arrWdTyp'}=\@wdTyp;
	$this->{HD}->{'arrWdChan'}=\@wdChan;
	$this->{HD}->{'arrWdRate'}=\@wdRate;
	$this->{HD}->{'arrWdAlign'}=\@wdAlign;
	$this->{HD}->{'arrWdPCM16'}=\@wdPCM16;
	$this->{HD}->{'arrWdOff'}=\@wdOff;
	$this->{HD}->{'arrWdLen'}=\@wdLen;
	return $dwEntryCount;
}

sub readWaveInfo {
	my ($this, $i)=@_;
	my $numWaves=   $this->getHD('dwEntryCount');
	my @wdFlags=@{$this->{HD}->{'arrWdFlags'} };
	my @wdDur=  @{$this->{HD}->{'arrWdDur'}   };
	my @wdTyp=  @{$this->{HD}->{'arrWdTyp'}   };
	my @wdChan= @{$this->{HD}->{'arrWdChan'}  };
	my @wdRate= @{$this->{HD}->{'arrWdRate'}  };
	my @wdAlign=@{$this->{HD}->{'arrWdAlign'} };
	my @wdPCM16=@{$this->{HD}->{'arrWdPCM16'} };
	my @wdOff=  @{$this->{HD}->{'arrWdOff'}   };
	my @wdLen=  @{$this->{HD}->{'arrWdLen'}   };	
	if ($i < 0 || $i >= $numWaves) { die "xwb:readWave: WaveIndex $i nicht vorhanden (Anz.Waves=$numWaves)"; }
	return ($wdFlags[$i],$wdDur[$i],$wdTyp[$i],$wdChan[$i],$wdRate[$i],$wdAlign[$i],$wdPCM16[$i],$wdOff[$i],$wdLen[$i]);
	}

sub readWaveData {
	my ($this, $wOff,$wLen)=@_;
	if ($this->getSafeMode()) {	
		return $this->readWaveDataSafe($wOff,$wLen); 
	} else {
		return $this->readWaveData2($wOff,$wLen);
	}
}

sub readWaveData2 {
	my ($this, $wOff,$wLen)=@_;
	my $segWaveDatOff=$this->getHD('segWaveDatOff');
	my $segWaveDatLen=$this->getHD('segWaveDatLen');
	die "xwb:readWaveData2: Wave($wOff,$wLen) liegt ausserhalb WaveDataSegment(Länge: $segWaveDatLen)" if ($wOff+$wLen > $segWaveDatLen);
	return $this->readStr($segWaveDatOff + $wOff, $wLen);
}
sub readWaveDataSafe {
	my ($this, $wOff,$wLen)=@_;
	my $segWaveDatOff=$this->getHD('segWaveDatOff');
	my $segWaveDatLen=$this->getHD('segWaveDatLen');
	die "xwb:readWaveDataSafe: Wave($wOff,$wLen) liegt ausserhalb WaveDataSegment(Länge: $segWaveDatLen)" if ($wOff+$wLen > $segWaveDatLen);
	return $this->SUPER::directReadIF($segWaveDatOff + $wOff, $wLen);
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
sub dhexStr {
	my $value=shift;
	return "$value(\$".hexStr($value).")";
}
sub hexStr {
	my $value=shift;
	return sprintf("%x",$value);
}

sub writeQLong {
	my ($OUTHANDLE, $value)=@_;
	my $hex= new Math::BigInt '0x'.$value;
	my $hexLo=Math::BigInt->new(0);
	my $hexHi=Math::BigInt->new(0);
	$hexLo=$value->copy();
	$hexHi=$value->copy();
	print "hex:",$hex->as_hex();
	$hexLo=$hexLo->band(Math::BigInt->new(0xFFFFFFFF));
	$hexHi=$hexHi->brsft(32);
	my $low=$hexLo->as_int();
	my $high=$hexHi->as_int();
	print ",hex-hi: $high, hex-lo: $low,";
	print "HEX: $value -> $hex\n";
	
}
sub writeLong {
	my ($OUTHANDLE, $value)=@_;
	print $OUTHANDLE pack('L',$value);
	
}
sub writeWord {
	my ($OUTHANDLE, $value)=@_;
	print $OUTHANDLE pack('S',$value);
	
}
sub writeBigEndianLong {
	my ($OUTHANDLE, $value)=@_;
	print $OUTHANDLE pack('N',$value);
}

sub writeBigEndianWord {
	my ($OUTHANDLE, $value)=@_;
	print $OUTHANDLE pack('n',$value);
	
}
sub writeBytes {
	my ($OUTHANDLE, $value)=@_;
	print "WRITING ".printBufferHex($value)."\n";
	print $OUTHANDLE $value;
	
}


sub denull {
    my $string = shift;
    $string =~ s/\0//g if defined $string;
    return $string;
}

sub checkByteValue {
	my $myVal= shift;
	return (($myVal > -1) && ($myVal < 256)) ? 1 : 0;
}


sub readENTRYdwFlags {
	my ($this,$position)=@_;
	my @res= $this->readMaskedLong($position,4,28);
	return @res;
}

sub readENTRYdwFlagsBE {
	my ($this,$position)=@_;
	my @res= $this->readMaskedLongBE($position,4,28);
	return @res;
}

sub readMINIWAVEFORMAT {
	my ($this,$position)=@_;
	my @res= $this->readMaskedLong($position,2,3,18,8,1);

	return @res;	
	}

sub readMINIWAVEFORMATBE {
	my ($this,$position)=@_;
	my @res= $this->readMaskedLongBE($position,2,3,18,8,1);

	return @res;	
	}

sub readMaskedLong {
	my ($this,$position, @bitlen)=@_;
	my $num=$#bitlen + 1;
	my @ch;
	for(my $i=0; $i < 4; $i++) {
		$ch[$i]=$this->readStr($position+$i,1);
		$ch[$i]=unpack('b8',$ch[$i]);
	}
	my $binary=join("",@ch);
	my @result;
	my $bitpos=0;
	for (my $i=0; $i<$num; $i++) {
		$result[$i]=substr($binary,$bitpos, $bitlen[$i]);
		$bitpos+=$bitlen[$i];
		$result[$i]=reverse($result[$i]);
		
		my $bh= new Math::BigInt '0b'.$result[$i];
		$result[$i]=$bh->as_int;
	}
	return @result;	
}
sub readMaskedLongBE {
	my ($this,$position, @bitlen)=@_;
	my $num=$#bitlen + 1;
	my @ch;
	for(my $i=0; $i < 4; $i++) {
		$ch[$i]=$this->readStr($position+3-$i,1);
		$ch[$i]=unpack('b8',$ch[$i]);
	}
	my $binary=join("",@ch);
	my @result;
	my $bitpos=0;
	for (my $i=0; $i<$num; $i++) {
		$result[$i]=substr($binary,$bitpos, $bitlen[$i]);
		$bitpos+=$bitlen[$i];
		$result[$i]=reverse($result[$i]);
		
		my $bh= new Math::BigInt '0b'.$result[$i];
		$result[$i]=$bh->as_int;
	}
	return @result;	
}
sub readB {
	$_[0]->SUPER::readByte($_[1]);   }
sub readW {
	$_[0]->SUPER::readWord($_[1]);   }
sub readWBE {
	$_[0]->SUPER::readWordBE($_[1]);   }
sub readL {	
	$_[0]->SUPER::readLong($_[1]);   }
sub readLBE {	
	$_[0]->SUPER::readLongBE($_[1]);   }
sub readStr {
	$_[0]->SUPER::readString($_[1],$_[2]);   }

sub readRest {
	$_[0]->getSafeMode() ? return 0 : return $_[0]->SUPER::readRest();  }	

	
1;