unit SPci;

{ Setup-only probe: use the same PCI BIOS and card checks as AudOpen. }
{$F+}
{$B-}
interface
uses SInstall;

const
  ProbeUnknown=0;
  ProbeNone=1;
  ProbeFound=2;

function ProbeAudigy(const Paths: TSetupPaths; var Preferred: Word): Word;

implementation
uses WinTypes, WinProcs, SFiles, PCI;

function ConfiguredIndex(const Paths: TSetupPaths; Card: Word; var Index: Word): Boolean;
var Stem,S: string;
    Value: LongInt;
    Err: Integer;
begin
  Result := False; Index := 0; Stem := DriverStem(Card);
  if not ReadIni(Stem,'CardIndex',Paths.Windows+Stem+'.INI',S) then Exit;
  if S=#1 then S := '0';
  Val(S,Value,Err);
  if (Err<>0) or (Value<0) or (Value>255) then Exit;
  Index := Word(Value); Result := True;
end;

function BoardKind(Bus,DevFn: Byte; var Kind: Word): Boolean;
var Rev: Byte;
    BAR,Subsystem: LongInt;
begin
  Result := False; Kind := 0;
  if not readPCIRegisterByte($08,Bus,DevFn,Rev) then Exit;
  if (Rev=0) or (Rev>4) then begin Result := True; Exit; end;
  if not readPCIRegisterDWord($10,Bus,DevFn,BAR) then Exit;
  if ((BAR and 1)=0) or ((BAR and $FFFF0000)<>0) or
     ((BAR and $FFF0)=0) then begin Result := True; Exit; end;
  if not readPCIRegisterDWord($2C,Bus,DevFn,Subsystem) then Exit;
  if Rev<4 then Kind := 1
  else if (Subsystem and LongInt($F0000000))<>$40000000 then Kind := 2;
  Result := True;
end;

function ProbeAudigy(const Paths: TSetupPaths; var Preferred: Word): Word;
var Bus,DevFn: Byte;
    I,Kind,Status,Index1,Index2: Word;
    Index1OK,Index2OK,Seen1,Seen2,Match1,Match2,Complete,ReadFailed: Boolean;
begin
  Result := ProbeUnknown; Preferred := 0;
  if (GetWinFlags and WF_ENHANCED)=0 then Exit;
  Index1OK := ConfiguredIndex(Paths,1,Index1);
  Index2OK := ConfiguredIndex(Paths,2,Index2);
  Seen1 := False; Seen2 := False; Match1 := False; Match2 := False;
  Complete := False; ReadFailed := False;
  { CardIndex is the raw PCI match index, not an index per Audigy type.
    One extra probe checks for end of list after the last usable index. }
  for I:=0 to 256 do begin
    Status := FindPCIStatus($0004,$1102,Bus,DevFn,I);
    if Status=PCINotFound then begin Complete := True; Break; end;
    if (Status<>0) or (I=256) then Break;
    if not BoardKind(Bus,DevFn,Kind) then ReadFailed := True
    else if Kind=1 then begin
      Seen1 := True;
      if Index1OK and (I=Index1) then Match1 := True;
    end else if Kind=2 then begin
      Seen2 := True;
      if Index2OK and (I=Index2) then Match2 := True;
    end;
  end;
  if Seen1 or Seen2 then Result := ProbeFound;
  if not Complete or ReadFailed then Exit;
  if not (Seen1 or Seen2) then Result := ProbeNone;
  if Match1 and not Seen2 then Preferred := 1;
  if Match2 and not Seen1 then Preferred := 2;
end;

end.
