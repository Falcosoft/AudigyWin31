unit SMemory;

{ Read-only BIOS queries. No physical mapping, RAM writes or XMS allocation. }
{$F+}
{$G+}
{$R-}
{$Q-}
{$B-}
interface

const RegionBytes=$40000;
      MapLimit=128;
type
  TRange=record First,Limit,Kind: LongInt; end;
  TMemoryInfo=record
    Method: Word; { 0 unavailable, 1 complete E820, 2 coarse E801 }
    Count: Word;
    Top: LongInt;
    Ranges: array[0..MapLimit-1] of TRange;
  end;
procedure DetectMemory(var M: TMemoryInfo);
function FitsRAM(const M: TMemoryInfo; Base: LongInt): Boolean;
function ValidBase(Base: LongInt): Boolean;

implementation

type
  TRM=packed record
    DI,SI,BP,Reserved,BX,DX,CX,AX: LongInt;
    Flags,ES,DS,FS,GS,IP,CS,SP,SS: Word;
  end;
  TE820=packed record
    StartLo,StartHi,SizeLo,SizeHi,Kind: LongInt;
  end;
  PE820=^TE820;

function Simulate(var R: TRM): Boolean;
var OK: Boolean;
begin
  OK := False;
  asm
    pusha
    push es
    les di,R
    mov ax,0300h
    mov bx,0015h
    xor cx,cx
    int 31h
    jc @@Done
    mov OK,1
  @@Done:
    pop es
    popa
  end;
  Result := OK and ((R.Flags and 1)=0);
end;

function DOSBuffer(var SegmentValue,Selector: Word): Boolean;
var OK: Boolean;
begin
  OK := False; SegmentValue := 0; Selector := 0;
  asm
    pusha
    push es
    mov ax,0100h
    mov bx,2
    int 31h
    jc @@Done
    les di,SegmentValue
    mov es:[di],ax
    les di,Selector
    mov es:[di],dx
    mov OK,1
  @@Done:
    pop es
    popa
  end;
  Result := OK;
end;

procedure FreeDOS(Selector: Word);
begin
  asm
    pusha
    mov ax,0101h
    mov dx,Selector
    int 31h
    popa
  end;
end;

function ValidBase(Base: LongInt): Boolean;
begin
  Result := (Base>=$100000) and (Base<=$7FFFFFFF-RegionBytes) and
            ((Base and $FFF)=0);
end;

function ReadMap(var M: TMemoryInfo): Boolean;
var R: TRM;
    E: PE820;
    SegmentValue,Selector,I: Word;
    Next,OldNext,EndAddress: LongInt;
    Complete: Boolean;
begin
  Result := False; M.Count := 0; M.Top := 0;
  if not DOSBuffer(SegmentValue,Selector) then Exit;
  try
    E := Ptr(Selector,0); Next := 0; Complete := False;
    for I:=1 to MapLimit do begin
      FillChar(E^,SizeOf(E^),0); FillChar(R,SizeOf(R),0);
      R.AX := $E820; R.DX := $534D4150; R.CX := 20;
      R.BX := Next; R.ES := SegmentValue; R.DI := 0;
      OldNext := Next;
      if not Simulate(R) then Exit;
      if (R.AX<>$534D4150) or (R.CX<20) then Exit;
      Next := R.BX;
      { The audio drivers use signed 32-bit addresses: clip at 2 GiB. }
      if (E^.StartHi=0) and (E^.StartLo>=0) and
         ((E^.SizeLo<>0) or (E^.SizeHi<>0)) then begin
        EndAddress := $7FFFFFFF;
        if (E^.SizeHi=0) and (E^.SizeLo>0) then
          if E^.SizeLo<=$7FFFFFFF-E^.StartLo then
            EndAddress := E^.StartLo+E^.SizeLo;
        with M.Ranges[M.Count] do begin
          First := E^.StartLo; Limit := EndAddress; Kind := E^.Kind;
        end;
        Inc(M.Count);
        if (E^.Kind=1) and (EndAddress>M.Top) then M.Top := EndAddress;
      end;
      if Next=0 then begin Complete := True; Break; end;
      if Next=OldNext then Exit;
    end;
    Result := Complete and (M.Count<>0) and (M.Top>$100000);
  finally
    FreeDOS(Selector);
  end;
end;

procedure DetectMemory(var M: TMemoryInfo);
var R: TRM;
    Below,Above: LongInt;
begin
  FillChar(M,SizeOf(M),0);
  if ReadMap(M) then begin M.Method := 1; Exit; end;
  FillChar(M,SizeOf(M),0); FillChar(R,SizeOf(R),0);
  R.AX := $E801;
  if not Simulate(R) then Exit;
  Below := R.AX and $FFFF; Above := R.BX and $FFFF;
  if ((R.CX or R.DX) and $FFFF)<>0 then begin
    Below := R.CX and $FFFF; Above := R.DX and $FFFF;
  end;
  if (Below<=0) or (Below>15360) then Exit;
  M.Top := $100000+Below*1024;
  if Below=15360 then begin
    if Above>$7EFF then M.Top := $7FFFFFFF
    else M.Top := $1000000+Above*65536;
  end;
  M.Method := 2; { No reserved-hole information: needs manual confirmation. }
end;

function FitsRAM(const M: TMemoryInfo; Base: LongInt): Boolean;
var I: Word;
    Last,Covered,Advance: LongInt;
begin
  Result := False;
  if not ValidBase(Base) then Exit;
  Last := Base+RegionBytes;
  if M.Method=0 then begin Result := True; Exit; end;
  if M.Method=2 then begin Result := Last<=M.Top; Exit; end;
  if M.Count=0 then Exit;
  { Reserved entries override usable entries, including overlapping maps. }
  for I:=0 to M.Count-1 do
    with M.Ranges[I] do
      if (Kind<>1) and (First<Last) and (Limit>Base) then Exit;
  Covered := Base;
  repeat
    Advance := Covered;
    for I:=0 to M.Count-1 do
      with M.Ranges[I] do
        if (Kind=1) and (First<=Covered) and (Limit>Advance) then Advance := Limit;
    if Advance=Covered then Exit;
    Covered := Advance;
  until Covered>=Last;
  Result := True;
end;

end.
