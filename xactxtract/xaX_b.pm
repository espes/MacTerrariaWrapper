#line 1 "xaX_b.pm"
package xaX_b;
my $skriptVersion=	0.97;
use 5.010;
use Math::BigInt;
my $DEBUG = 0;
sub new {
	my ($class, $ifilename)=@_;
	my $this = {};
	$this->{CNAME}=$class;
	
	$this->{DATA}= undef;
	$this->{IFNAME} = $ifilename;
	$this->{IFSIZE} =-s $ifilename;
	$this->{IFGELESEN}=0;
	$this->{HD} = ();
	open (IFH,'<' ,$ifilename) || die "$class: Kann Datei $filename nicht oeffnen: $!";
	binmode (IFH);
	$this->{IFHANDLE} = IFH;
	print "$class:Konstruktor: $ifilename\n";
	bless($this, $class);
	return $this;
}
sub getCName {
	my $this=shift;
	return $this->{CNAME};
}
sub getAll {
	my $this=shift;
	say "INFO ANFANG";
	print "CNAME: ".$this->{CNAME}.", getName(".$this->getCName()."),IFNAME: $this->{IFNAME}";
	say "INFO ENDE";
	}
sub getIFH {
	my $this = shift;
	if ($DEBUG) {

		if (! defined ($this->{IFHANDLE})) { die "$this: Inputfilehandle für ".($this->{IFNAME})." existiert nicht"; }
	}
	return $this->{IFHANDLE};
}

sub get {
	my ($this, $key)=@_;
	return ($this->{HD}->{$key});
}
sub set {
	if ($#_ % 2) { die "x_b:set: hat eine gerade Anzahl von Parametern @_"; }
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
sub inject {
	my ($this, $pos, $content, $debugstring) = @_;
	my $len=length($content);
	my $flen=$this->getDSize();
	if (! $this->isInFile($pos)) { die $this->{CNAME}.":inject: Einfügeposition $pos liegt ausserhalb Datei"; }
	$pre=substr($this->{DATA},0,$pos);
	$post=substr($this->{DATA},$pos,$flen - $pos);
	$this->{DATA}=$pre.$content.$post;
	say $this->getCName()."inject $debugstring : Pos: $pos, Len: $len in Buffer (vorher $flen , nun ".$this->getDSize().")";
	my @arrPos=@{$this->{HD}->{'arrPos'} };
	my @arrLen=@{$this->{HD}->{'arrLen'} };
	my $insPos=0;
	for (0 .. $#arrPos) {
		if ($pos > $arrPos[$_]) { $insPos++; }
	}
	splice @arrPos, $insPos, 0, $pos;
	splice @arrLen, $insPos, 0, $len;
	$this->{HD}->{'arrPos'}=\@arrPos;
	$this->{HD}->{'arrLen'}=\@arrLen;
}
sub infoInject {
	my $this = shift;
	my $dSize=$this->getDSize();
	my @arrPos=@{$this->{HD}->{'arrPos'} };
	my @arrLen=@{$this->{HD}->{'arrLen'} };
	my $total=0;
	print "Info nach ".($#arrPos +1)." inserts: ";
	for (0 .. $#arrPos) {
		$total+=$arrLen[$_];
	}
}
sub corrOffsetAfter {
	my ($this, $oldPos) = @_;
	my @arrPos=@{$this->{HD}->{'arrPos'} };
	my @arrLen=@{$this->{HD}->{'arrLen'} };
	my $delta=0;
	for (0 .. $#arrPos) {
		if ($oldPos < $arrPos[$_]) { last; }
		else {	$delta+=$arrLen[$_]; }
	}
	if (! $this->isInFile($oldPos+$delta)) { die $this->{CNAME}."corrOffset: Offset $oldPos um $delta verschoben liegt nicht mehr im File?!?"; }
	return $oldPos+$delta;
}

sub corrOffsetBefore {
	my ($this, $oldPos) = @_;
	my @arrPos=@{$this->{HD}->{'arrPos'} };
	my @arrLen=@{$this->{HD}->{'arrLen'} };
	my $delta=0;
	for (0 .. $#arrPos) {
		if ($oldPos <= $arrPos[$_]) { last; }
		else {	$delta+=$arrLen[$_]; }  
	}
	if (! $this->isInFile($oldPos+$delta)) { die $this->{CNAME}."corrOffset: Offset $oldPos um $delta verschoben liegt nicht mehr im File?!?"; }
	return $oldPos+$delta;
}
sub corrPointer {
	my ($this, $pos,$debugstring) = @_;
	my $offset=$this->readLong($this->corrOffsetAfter($pos));
	print "[corrPtr $debugstring:";
	print "readPtr $pos->(".($this->corrOffsetAfter($pos)).")=";
	if (! $this->isInFile($offset)) { die $this->{CNAME}."corrPointer: $pos => $offset liegt nicht in Datei"; }
	say "val $offset->".($this->corrOffsetAfter($offset))."]";
	$offset=$this->corrOffsetAfter($offset);

	$this->writeLong($this->corrOffsetAfter($pos), $offset);
}

sub getIFSize {
	my $this = shift;
	print "$this: getIFSize".$this->{IFSIZE}."\n";
	return $this->{IFSIZE};
}
sub getDSize {
	my $this = shift;
	return (length($this->{DATA}));
}
sub getDataString {
	my $this = shift;
	return ($this->{DATA});
}

sub readIF {
	my ($this, $size) = @_;
	my $buffer;
	my $readBytes= $size ? $size : ($this->{IFSIZE});
	if ($DEBUG) { print $this->getCName().": Lese $readBytes Byte aus ".($this->{IFNAME}) };
	if (read($this->getIFH,$buffer,$readBytes) < $readBytes) { die "Daten aus ".($this->{IFNAME})." konnten nicht gelesen werden"};
	$this->{IFGELESEN} +=$readBytes;
	$this->{DATA}=$this->{DATA}.$buffer;
	if ($DEBUG) { say "=>insges. ".$this->{IFGELESEN}." Byte gelesen. Buffergröße:".$this->getDSize()};
	return $this->getDSize();
}
sub readRest {
	my $this = shift;
	return $this->readIF( $this->getIFSize() - $this->getDSize());
}
sub directReadIF {
	my ($this, $startpos, $size) = @_;
	my $buffer;
	seek($this->getIFH(), $startpos, 0);
	if (read($this->getIFH(),$buffer,$size) < $size) { die "Daten aus ".($this->{IFNAME})." konnten nicht gelesen werden"};
	return $buffer;
}
	
sub openIF {
	my ($this, $ifilename)=@_;
	if ($this->{IFHANDLE}) { $this->closeIF(); }
	$this->{DATA}= undef;
	$this->{HD}= undef;
	$this->{IFNAME} = $ifilename;
	$this->{IFSIZE} =-s $ifilename;
	$this->{IFGELESEN}=0;
	open (IFH,'<' ,$ifilename) || die $this->getCName()." Kann Datei $ifilename nicht oeffnen: $!";
	binmode (IFH);
	$this->{IFHANDLE} = IFH;
		
	}
sub closeIF {
	my $this = shift;
	$this->{IFGELESEN}=0;
	$this->{DATA}= undef;
	$this->{HD}= undef;
	if ($this->{IFHANDLE}) { close $this->{IFHANDLE}; }
	}
sub printBufferHex {
	my ($this,$buffer)=@_;
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
sub printIFileHex {
	my ($this, $pos, $size) = @_;
	my $buffer;
	if ($pos) { $buffer=substr($this->{DATA},$pos,$size); }
	else      { $buffer=$this->{DATA}; }
	if ($DEBUG) { print "$this:printIFileHex: drucke Buffer mit Länge ".length($buffer)."\n"; }
	print $this->printBufferHex($buffer)."\n";
}

sub IFBackup {
	my ($this, $suffix)=@_;
	my $suffix= $suffix ? $suffix : "_backup";
	my $ifname=  ($this->{IFNAME}=~/(\w+).x(w|s)b$/) ? $1 : die $this->{IFNAME}." hat nicht die Endung .xsb/.xwb";
	if ($DEBUG) { print $this->getCName().": Filebackup $ifname.xsb -> $ifname.xsb$suffix\n"; }
	system("copy $ifname.xsb $ifname.xsb$suffix")==0 or die "Fehler beim Anlegen der Backupdatei $myXsb.xsb_backup : $?";
}
sub IFRenameWriteAndClose {
	my ($this, $suffix)=@_;
	my $suffix= $suffix ? $suffix : "_backup";	
	my $ifname=  $this->{IFNAME};
	if ($DEBUG) { print $this->getCName().": Filebackup/rename $ifname -> $ifname$suffix\n"; }
	close $this->{IFHANDLE};
	rename($ifname,$ifname.$suffix) || die "IFRenameAndWrite: Fehler beim Umbenennen von $ifname : $!";
	open (IFH,'>' ,$ifname) || die $this->getCName()." Kann Datei $ifname nicht oeffnen: $!";
	binmode (IFH);
	print IFH $this->{DATA};
	close IFH;
	$this->closeIF();
}
sub isInFile {
	my ($this, $pos)=@_;
	if (($pos > length($this->{DATA})) || ($pos < 0)) {
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

sub readBytes {
	my ($this, $position, $len)=@_;	
	return unpack ("C*",substr($this->{DATA},$position,$len));
}
	
sub writeLong {
	my ($this, $pos, $value)=@_;	
	my $byteString=pack('V',$value);
	substr($this->{DATA},$pos,4,$byteString);
}
sub writeWord {
	my ($this, $pos, $value)=@_;	
	my $byteString=pack('v',$value);
	substr($this->{DATA},$pos,2,$byteString);
}
sub writeByte {
	my ($this, $pos, $value)=@_;
	$this->writeString($pos, pack("C", $value), 1);
}


sub writeString {
	my ($this, $pos, $value, $laenge)=@_;	
	my $byteString=$value;
	my $length= $laenge ? $laenge : length($byteString);
	if ($DEBUG) { $this->isInFile($pos); }
	say "writeString: Pos $pos, val $value, byteString $byteString, len $length";
	substr($this->{DATA},$pos,$length,$byteString);	
}
sub writeBytes {
	my ($this, $pos, $value, $laenge)=@_;	
	my $byteString=pack ("C*",$value);
	my $length= $laenge ? $laenge : length($byteString);
	$this->writeString($pos,$byteString,$length);
}
sub dhexStr {
	my $value=shift;
	return "$value(\$".hexStr($value).")";
}
sub hexStr {
	my $value=shift;
	return sprintf("%x",$value);
}
1;
