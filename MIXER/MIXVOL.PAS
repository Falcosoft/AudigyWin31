unit MixVol;

{ Win16 common volume packing. Low word is LEFT; high word is RIGHT.
  A vertical scrollbar is zero at the top (full volume), 100 at silence. }
{$R-}
{$Q-}

interface

function MixPack(LeftLevel,RightLevel: Word): LongInt;
function MixLeft(Volume: LongInt): Word;
function MixRight(Volume: LongInt): Word;
function MixPosition(Level: Word): Integer;
function MixLevel(Position: Integer): Word;
function MixPercent(Level: Word): Word;

implementation

function MixPack(LeftLevel,RightLevel: Word): LongInt;
begin
  Result := LongInt(LeftLevel) or (LongInt(RightLevel) shl 16);
end;

function MixLeft(Volume: LongInt): Word;
begin
  Result := Word(Volume);
end;

function MixRight(Volume: LongInt): Word;
begin
  Result := Word(Volume shr 16);
end;

function MixPosition(Level: Word): Integer;
begin
  Result := 100-Integer((LongInt(Level)*100+32767) div 65535);
end;

function MixLevel(Position: Integer): Word;
begin
  if Position<0 then Position := 0;
  if Position>100 then Position := 100;
  Result := Word((LongInt(100-Position)*65535+50) div 100);
end;

function MixPercent(Level: Word): Word;
begin
  Result := Word((LongInt(Level)*100+32767) div 65535);
end;

end.
