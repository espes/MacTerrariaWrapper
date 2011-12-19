#line 1 "xaWma.pm"
package xaWma;

my $skriptName=		"xaWma.pm";
my $skriptVersion=	0.97;

use 5.010;
use Math::BigInt;




use constant XWB_HEADERSIZE  =>  52;
use constant WAVEBANK_TYPE_BUFFER    =>      0x00000000;
use constant WAVEBANK_TYPE_STREAMING  =>     0x00000001;
use constant WAVEBANK_TYPE_MASK     =>       0x00000001;

use constant WAVEBANKMINIFORMAT_TAG_PCM   =>   0x0;
use constant WAVEBANKMINIFORMAT_TAG_XMA   =>   0x1;
use constant WAVEBANKMINIFORMAT_TAG_ADPCM =>   0x2;
use constant WAVEBANKMINIFORMAT_TAG_WMA   =>   0x3;



@aWMAAvgBytesPerSec = (12000, 24000, 4000, 6000, 8000, 20000);


@aWMABlockAlign =(929, 1487, 1280, 2230, 8917, 8192, 4459, 5945, 2304,1536, 1485, 1008, 2731, 4096,6827, 5462);

sub new {
	my ($class, $ofilename)=@_;
	my $this = {};
	$this->{CNAME}=$class;
	
	$this->{DATA}= undef;
	$this->{OFNAME} = $ofilename;
	$this->{HD} = ();
	open (OFH,'>' ,$ofilename) || die "$class: Kann Datei $filename nicht zum Schreiben oeffnen: $!";
	binmode (OFH);
	$this->{OFHANDLE} = OFH;
	bless($this, $class);
	return $this;	
}
sub getCName {
	my $this=shift;
	return $this->{CNAME};
}
sub getOFName {
	my $this=shift;
	return $this->{OFNAME};
}

sub getDSize {
	my $this = shift;
	return (length($this->{DATA}));
}


sub close {
	my $this=shift;
	$this->{HD}= undef;
	$this->{DATA}= undef;
	if ($this->{OFHANDLE}) { close $this->{OFHANDLE}; }
}

sub flush {
	my $this=shift;
	my $fh = $this->{OFHANDLE};
	print $fh $this->{DATA};
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


sub writeXWma {

	my ($this, $wNum, $shortFileName, $dFlags, $dDur, $dTyp, $dChan, $dRate, $dAlign, $dPCM16, $dOff, $dLength, $wdref, $printInfo)=@_; 
	if ($dTyp != WAVEBANKMINIFORMAT_TAG_WMA) {
		if (DEBUG) { print "Wave $wNum ist kein WMA(?)\n"; }
		return 0;
	}
	print "$shortFileName:" if ($printInfo);
	print "Dur:$dDur,".$dChan."ch,$dRate\Hz,Align:$dAlign,"  if ($printInfo);
	$this->writeString(0,"RIFF");
	my $odRIchunkSize=$this->getDSize();
	$this->writeLong(0);
	$this->writeString(8,"XWMAfmt "); 
	$this->writeLong(18);
	$this->writeWord(0x161);
	$this->writeWord($dChan);
	$this->writeLong($dRate);
	my $dFMavgBytesPerSec=($dAlign > $#aWMAAvgBytesPerSec ? $aWMAAvgBytesPerSec[$dAlign >> 5] : $aWMAAvgBytesPerSec[$dAlign]);
	my $dFMblockAlign=($dAlign > $#aWMABlockAlign ? $aWMABlockAlign[$dAlign & 0xf] :$aWMABlockAlign[$dAlign]);
	$this->writeLong($dFMavgBytesPerSec);
	$this->writeWord($dFMblockAlign);
	$this->writeWord(16);
	$this->writeWord(0);
	$this->writeString($this->getDSize(),"dpds");
	my $packetLength=$dFMblockAlign;
	if ($dLength % $packetLength) { die $this->getCName."xWMAWrite:Paketgröße($packetLength) teilt Datenblockgröße($dLength) nicht restfrei";}
	my $packetNum=$dLength / $packetLength;
	$this->writeLong($packetNum * 4);
	my $fullsize=round4096($dDur * 2);
	my $allBlocks=int($fullsize/4096);
	my $avgBlocksPerPacket=int($allBlocks/$packetNum);
	my $spareBlocks=$allBlocks - ($avgBlocksPerPacket * $packetNum);
	
	print "Pakete: $packetNum\n"  if ($printInfo);	
	my $accu=0;
	for(my $i=0; $i < $packetNum; $i++) {
		$accu+=$avgBlocksPerPacket * 4096;
		if ($spareBlocks) {
			$accu+=4096;
			$spareBlocks--;
		}
		$this->writeLong($accu);
	}


	$this->writeString($this->getDSize(),"data");
	$this->writeLong($dLength);
	$this->writeString($this->getDSize(),$$wdref);
	
	$this->writeLong($odRIchunkSize,$this->getDSize() - 8);
	return 0;
	
	
		
}
sub round4096 {
	my $value=shift;
	return ($value % 4096 ? (1+ int($value /4096))*4096 : $value);
	}

sub writePCM {

	my ($this, $wNum, $shortFileName, $dFlags, $dDur, $dTyp, $dChan, $dRate, $dAlign, $dPCM16, $dOff, $dLength, $wdref, $printInfo)=@_; 
	if ($dTyp != WAVEBANKMINIFORMAT_TAG_PCM) {
		if (DEBUG) { print "Wave $wNum ist kein PCM(?)\n"; }
		return 0;
	}
	print "$shortFileName:" if ($printInfo);
	print "Dur:$dDur,".$dChan."ch,$dRate\Hz,Align:$dAlign,"  if ($printInfo);
	$this->writeString(0,"RIFF");
	my $odRIchunkSize=$this->getDSize();
	$this->writeLong(0);
	$this->writeString(8,"WAVEfmt "); 
	$this->writeLong(16);
	$this->writeWord(0x0001);
	$this->writeWord($dChan);
	$this->writeLong($dRate);
	my $wFMbitsPerSample = ($dPCM16 ? 16 : 8);
	my $dFMblockAlign = $dChan * roundInt(($wFMbitsPerSample + 7) / 8);
	my $dFMavgBytesPerSec=$dRate * $dFMblockAlign;
	$this->writeLong($dFMavgBytesPerSec);
	$this->writeWord($dFMblockAlign);
	$this->writeWord($wFMbitsPerSample);


	$this->writeString($this->getDSize(),"data");
	$this->writeLong($dLength);
	$this->writeString($this->getDSize(),$$wdref);
	
	$this->writeLong($odRIchunkSize,$this->getDSize() - 8);
	return 0;
	
	
		
}
sub roundInt {
	my $value=shift;
	my $intvalue=int($value);
	return ( ($value - $intvalue < 0.5) ? $intvalue : $intvalue + 1);
}
sub ADPCM2PCM {
	my ($this, $wdref, $dLength)=@_;
	my $adpcm=$$wdref;
	my $pcm="";
}

sub dhexStr {
	my $value=shift;
	return "$value(\$".hexStr($value).")";
}
sub hexStr {
	my $value=shift;
	return sprintf("%x",$value);
}
sub isInFile {
	my ($this, $pos)=@_;
	if (($pos > length($this->{DATA})) || ($pos < 0)) {
		say $this->{CNAME}.":isInFile: Position $pos liegt ausserhalb des Buffers der Datei $this->{IFNAME} (Groesse: ",length($this->{DATA}),")\n";
		return 0;
	} else {
		return ($pos ? $pos : 1);
	}
}
sub readByte {
	my ($this, $position)=@_;
	if ($DEBUG) { $this->isInFile($position); }
	return unpack('C',substr($this->{DATA},$position,1));
	}
sub readWord {
	my ($this, $position)=@_;
	if ($DEBUG) { $this->isInFile($position); }
	return unpack('S',substr($this->{DATA},$position,2));
}
sub readLong {
	my ($this, $position)=@_;
	if ($DEBUG) { $this->isInFile($position); }
	return unpack('L',substr($this->{DATA},$position,4));
}
sub readString {
	my ($this, $position, $len)=@_;
	if ($DEBUG) { $this->isInFile($position); }
	return substr($this->{DATA},$position,$len);
}

sub writeQLong {
	my $this=shift;
	my $pos, $value;
	my $anzahl=@_;
	if ($anzahl == 1) {
		$value=shift;
		$pos=length($this->{DATA});
	} elsif ($anzahl == 2) {
		($pos, $value)=@_;
	} else { die "xaWMA:writeLong: zu viele ($anzahl) Parameter: @_"; }	
	my $hex= new Math::BigInt $value;
	my $hexLo=Math::BigInt->new(0);
	my $hexHi=Math::BigInt->new(0);
	$hexLo=$hex->copy();
	$hexHi=$hex->copy();	
	print "hex:",$hex->as_hex();
	$hexLo=$hexLo->band(Math::BigInt->new(0xFFFFFFFF));
	$hexHi=$hexHi->brsft(32);
	my $low=$hexLo->as_int();
	my $high=$hexHi->as_int();
	print ",hex-hi: $high, hex-lo: $low,";
	print "HEX: $value -> $hex\n";
	$this->writeLong($pos,$low);
	$this->writeLong($pos+4,$high);
	
}
sub writeLong {
	
	my $this=shift;
	my $pos, $value;
	my $anzahl=@_;
	if ($anzahl == 1) {
		$value=shift;
		$pos=length($this->{DATA});
	} elsif ($anzahl == 2) {
		($pos, $value)=@_;
	} else { die "xaWMA:writeLong: zu viele ($anzahl) Parameter: @_"; }
	
	my $byteString=pack('V',$value);
	substr($this->{DATA},$pos,4,$byteString);		
}


sub writeWord {
	my $this=shift;
	my $pos, $value;
	my $anzahl=@_;
	if ($anzahl == 1) {
		$value=shift;
		$pos=length($this->{DATA});
	} elsif ($anzahl == 2) {
		($pos, $value)=@_;
	} else { die "xaWMA:writeWord: zu viele ($anzahl) Parameter: @_"; }
	
	my $byteString=pack('v',$value);
	substr($this->{DATA},$pos,2,$byteString);	
}
sub writeBigEndianLong {
	my $this=shift;
	my $pos, $value;
	my $anzahl=@_;
	if ($anzahl == 1) {
		$value=shift;
		$pos=length($this->{DATA});
	} elsif ($anzahl == 2) {
		($pos, $value)=@_;
	} else { die "xaWMA:writeLong: zu viele ($anzahl) Parameter: @_"; }
	my $byteString=pack('N',$value);
	substr($this->{DATA},$pos,4,$byteString);
}
sub writeBigEndianWord {
	my $this=shift;
	my $pos, $value;
	my $anzahl=@_;
	if ($anzahl == 1) {
		$value=shift;
		$pos=length($this->{DATA});
	} elsif ($anzahl == 2) {
		($pos, $value)=@_;
	} else { die "xaWMA:writeLong: zu viele ($anzahl) Parameter: @_"; }
	my $byteString=pack('n',$value);
	substr($this->{DATA},$pos,2,$byteString);
}
sub writeByte {
	my $this=shift;
	my $pos, $value;
	my $anzahl=@_;
	if ($anzahl == 1) {
		$value=shift;
		$pos=length($this->{DATA});
	} elsif ($anzahl == 2) {
		($pos, $value)=@_;
	} else { die "xaWMA:writeWord: zu viele ($anzahl) Parameter: @_"; }
	$this->writeString($pos, pack("C", $value), 1);
}


sub writeString {
	my ($this, $pos, $value, $laenge)=@_;	
	my $byteString=$value;
	my $length= $laenge ? $laenge : length($byteString);
	if ($DEBUG) { $this->isInFile($pos); }
	substr($this->{DATA},$pos,$length,$byteString);	
}
sub writeBytes {
	my ($this, $pos, $value, $laenge)=@_;	
	my $byteString=pack ("C*",$value);
	my $length= $laenge ? $laenge : length($byteString);
	$this->writeString($pos,$byteString,$length);
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

	
1;