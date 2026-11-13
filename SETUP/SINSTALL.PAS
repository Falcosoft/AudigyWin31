unit SInstall;

{ Installation task only: no audio imports, driver loads or driver callbacks. }
{$F+}
{$B-}
interface
uses WinTypes, SMemory;

type
  TSetupPaths=record Source,Windows,System: string; end;
function FindPaths(var P: TSetupPaths): Boolean;
function DriverStem(Card: Word): string;
function CurrentBase(const P: TSetupPaths; Card: Word;
                     var Text: string): Boolean;
function ChooseBase(const P: TSetupPaths; Card: Word; const M: TMemoryInfo;
                    XMS: LongInt; var Base: LongInt): Boolean;
function SuggestBase(const P: TSetupPaths; Card: Word; const M: TMemoryInfo;
                     XMS: LongInt; var Base: LongInt): Boolean;
function CheckBase(const P: TSetupPaths; Card: Word; const M: TMemoryInfo;
                   Base,XMS: LongInt; var Reason: string): Boolean;
function InstallCard(const P: TSetupPaths; Card: Word; Base: LongInt;
                     var Report: string): Boolean;

implementation
uses WinProcs, SysUtils, SFiles;

const ManagerFile: string[12]='MSMIXMGR.DLL';
      MixerFile: string[12]='AUDMIXER.EXE';
      OplCoreFile: string[12]='OPLCORE.DLL';
      SfCoreFile: string[12]='SFCORE.DLL';
      DriverCategories: array[0..3] of string[5]=('wave','aux','mixer','midi');
      EditLimit=16;
type
  TEdit=record FileName,Section,Key,OldValue,NewValue: string; end;
  TPlan=record
    Count,Done: Word;
    CopyOplCore,CopySfCore: Boolean;
    Edits: array[0..EditLimit-1] of TEdit;
  end;
  PPlan=^TPlan;

function FindPaths(var P: TSetupPaths): Boolean;
var B: array[0..255] of Char;
    N: Word;
begin
  Result := False;
  N := GetModuleFileName(HInstance,B,SizeOf(B));
  if (N=0) or (N>=SizeOf(B)-1) then Exit;
  P.Source := Slash(ExtractFilePath(StrPas(B)));
  N := GetWindowsDirectory(B,SizeOf(B));
  if (N=0) or (N>=SizeOf(B)-1) then Exit;
  P.Windows := Slash(StrPas(B));
  N := GetSystemDirectory(B,SizeOf(B));
  if (N=0) or (N>=SizeOf(B)-1) then Exit;
  P.System := Slash(StrPas(B));
  Result := (P.Source<>'') and (Length(P.Source)<220) and
            (Length(P.Windows)<220) and (Length(P.System)<220);
end;

function DriverStem(Card: Word): string;
begin
  Result := 'AUDIGY'+IntToStr(Card);
end;

function CurrentBase(const P: TSetupPaths; Card: Word; var Text: string): Boolean;
begin
  Result := ReadIni(DriverStem(Card),'PhysicalBase',
                    P.Windows+DriverStem(Card)+'.INI',Text);
  if Result and (Text=#1) then Text := '';
end;

function NextToken(const S: string; var Position: Word): string;
var Start: Word;
    Quoted: Boolean;
begin
  while Position<=Length(S) do begin
    if not (S[Position] in [' ',#9]) then Break;
    Inc(Position);
  end;
  Start := Position; Quoted := False;
  while Position<=Length(S) do begin
    if S[Position]='"' then Quoted := not Quoted;
    if not Quoted and (S[Position] in [' ',#9]) then Break;
    Inc(Position);
  end;
  Result := Copy(S,Start,Position-Start);
end;

function ModuleName(const S: string): string;
var Position: Word;
begin
  Position := 1; Result := NextToken(S,Position);
  if Length(Result)>=2 then
    if (Result[1]='"') and (Result[Length(Result)]='"') then
      Result := Copy(Result,2,Length(Result)-2);
  Result := UpperCase(ExtractFileName(Result));
end;

function TokenIs(const Token,Name,IniName: string): Boolean;
var Module,AliasValue: string;
begin
  Module := ModuleName(Token);
  Result := (Module=Name) or (Module=Copy(Name,1,Length(Name)-4));
  if Result then Exit;
  if ReadIni('drivers',Token,IniName,AliasValue) then begin
    Module := ModuleName(AliasValue);
    Result := (Module=Name) or (Module=Copy(Name,1,Length(Name)-4));
  end;
end;

function AppendToken(var S: string; const Token: string): Boolean;
var Needed: Word;
begin
  Needed := Length(S)+Length(Token);
  if S<>'' then Inc(Needed);
  Result := Needed<=254;
  if not Result then Exit;
  if S<>'' then S := S+' ';
  S := S+Token;
end;

function MakeBootLine(const Old,IniName: string; var NewLine: string): Boolean;
var Position,Managers: Word;
    Token,ManagerToken: string;
    HaveMMS,GoodOrder,Inserted: Boolean;
begin
  Result := False; NewLine := ''; Position := 1;
  ManagerToken := ManagerFile; Managers := 0;
  HaveMMS := False; GoodOrder := False;
  repeat
    Token := NextToken(Old,Position);
    if Token='' then Break;
    if TokenIs(Token,'MMSYSTEM.DLL',IniName) then HaveMMS := True;
    if TokenIs(Token,ManagerFile,IniName) then begin
      Inc(Managers);
      if Managers=1 then begin ManagerToken := Token; GoodOrder := HaveMMS; end;
    end;
  until False;
  if (Managers=1) and GoodOrder then begin
    NewLine := Old; Result := True; Exit;
  end;
  Inserted := False;
  if not HaveMMS then begin
    if not AppendToken(NewLine,'mmsystem.dll') then Exit;
    if not AppendToken(NewLine,ManagerToken) then Exit;
    Inserted := True;
  end;
  Position := 1;
  repeat
    Token := NextToken(Old,Position);
    if Token='' then Break;
    if not TokenIs(Token,ManagerFile,IniName) then begin
      if not AppendToken(NewLine,Token) then Exit;
      if not Inserted and TokenIs(Token,'MMSYSTEM.DLL',IniName) then begin
        if not AppendToken(NewLine,ManagerToken) then Exit;
        Inserted := True;
      end;
    end;
  until False;
  Result := Inserted;
end;

function Registered(const P: TSetupPaths; const Name: string): Boolean;
var I,J: Word;
    S,Key,Category: string;
begin
  Result := False;
  for J:=Low(DriverCategories) to High(DriverCategories) do begin
    Category := DriverCategories[J];
    for I:=0 to 9 do begin
      Key := Category; if I<>0 then Key := Key+IntToStr(I);
      if not ReadIni('drivers',Key,P.Windows+'SYSTEM.INI',S) then begin
        Result := True; Exit; { Treat unknown/truncated registration conservatively. }
      end;
      if ModuleName(S)=Name then begin Result := True; Exit; end;
    end;
  end;
end;

function Number(const S: string; var V: LongInt): Boolean;
var E: Integer;
begin
  Val(S,V,E); Result := E=0;
end;

function Overlap(A,ASize,B,BSize: LongInt): Boolean;
begin
  Result := (A<B+BSize) and (B<A+ASize);
end;

function HDAAddress(const P: TSetupPaths; const Key: string;
                    DefaultValue: LongInt; var V: LongInt): Boolean;
var S,H,L: string;
    Hi,Lo,Raw: LongInt;
begin
  Result := False;
  if not ReadIni('BUSMASTER',Key+'HI',P.Windows+'HDACFG.INI',H) then Exit;
  if not ReadIni('BUSMASTER',Key+'LO',P.Windows+'HDACFG.INI',L) then Exit;
  { HDA2 actually maps HI:LO; match those, not a potentially inconsistent PCI key. }
  if H=#1 then Hi := DefaultValue shr 16
  else if not Number(H,Hi) then Exit;
  if L=#1 then Lo := DefaultValue and $FFFF
  else if not Number(L,Lo) then Exit;
  if (Hi<0) or (Hi>$7FFF) or (Lo<0) or (Lo>$FFFF) then Exit;
  V := Hi*65536+Lo;
  if not ReadIni('BUSMASTER',Key,P.Windows+'HDACFG.INI',S) then Exit;
  { Reject inconsistent DMA/mapping keys rather than trusting just one of them. }
  if S<>#1 then begin
    if not Number(S,Raw) then Exit;
    if Raw<>V then Exit;
  end;
  Result := True;
end;

function CheckBase(const P: TSetupPaths; Card: Word; const M: TMemoryInfo;
                   Base,XMS: LongInt; var Reason: string): Boolean;
var Other,A,B: LongInt;
    S: string;
begin
  Result := False;
  Reason := 'PhysicalBase must be a 4 KiB-aligned address below 2 GiB.';
  if not ValidBase(Base) then Exit;
  Reason := 'The memory amount must be valid (1..2046 MB), not free memory.';
  if (XMS<1) or (XMS>2046) then Exit;
  Reason := 'PhysicalBase must be above the reported memory amount plus the first MB.';
  if Base<(XMS+1)*$100000 then Exit;
  Reason := 'The BIOS memory report does not contain enough usable RAM at this address.';
  if not FitsRAM(M,Base) then Exit;
  Other := 3-Card;
  if Registered(P,DriverStem(Word(Other))+'.DLL') then begin
    Reason := 'Cannot safely read the other Audigy driver memory setting.';
    if not CurrentBase(P,Word(Other),S) then Exit;
    if S='' then S := '$08000000';
    if not Number(S,A) then Exit;
    if not ValidBase(A) then Exit;
    Reason := 'The two Audigy drivers must not use overlapping PhysicalBase regions.';
    if Overlap(Base,RegionBytes,A,RegionBytes) then Exit;
  end;
  if Registered(P,'HDA2.DLL') then begin
    Reason := 'Cannot read the registered HDA2 memory configuration safely.';
    if not ReadIni('HDA','TSR',P.Windows+'HDACFG.INI',S) then Exit;
    if (UpperCase(S)='TSR FOUND') then begin
      Reason := 'HDA2 uses a TSR: verify its reservation manually before installing.';
      Exit;
    end;
    { Test20: BDL maps 128 KiB at $08000000, PCM 320 KiB at $08100000. }
    if not HDAAddress(P,'aPCI',$08000000,A) then Exit;
    if not HDAAddress(P,'myPCI',$08100000,B) then Exit;
    Reason := 'PhysicalBase overlaps the registered HDA2 driver memory region.';
    if (A>$7FFFFFFF-$20000) or (B>$7FFFFFFF-$50000) then Exit;
    if Overlap(Base,RegionBytes,A,$20000) or Overlap(Base,RegionBytes,B,$50000) then Exit;
  end;
  Reason := ''; Result := True;
end;

function SuggestBase(const P: TSetupPaths; Card: Word; const M: TMemoryInfo;
                     XMS: LongInt; var Base: LongInt): Boolean;
var Reason: string;
    Candidate: LongInt;
begin
  Result := False; Base := 0;
  Candidate := $08000000;
  if CheckBase(P,Card,M,Candidate,XMS,Reason) then begin
    Base := Candidate; Result := True; Exit;
  end;
  { Without a BIOS map this is an UNVERIFIED address, not detected RAM.
    CheckBase still enforces the Windows/XMS floor and known card conflicts. }
  Candidate := $09000000;
  while (Candidate<=$7F000000) and ((M.Method=0) or (Candidate<M.Top)) do begin
    if CheckBase(P,Card,M,Candidate,XMS,Reason) then begin
      Base := Candidate; Result := True; Exit;
    end;
    if Candidate>=$7F000000 then Break; { next 16 MiB would overflow signed LongInt }
    Candidate := Candidate+$1000000;
  end;
  Candidate := $05000000;
  while Candidate<$08000000 do begin
    if CheckBase(P,Card,M,Candidate,XMS,Reason) then begin
      Base := Candidate; Result := True; Exit;
    end;
    Candidate := Candidate+$1000000;
  end;
end;

function ChooseBase(const P: TSetupPaths; Card: Word; const M: TMemoryInfo;
                    XMS: LongInt; var Base: LongInt): Boolean;
var S: string;
begin
  Result := False;
  if not CurrentBase(P,Card,S) then Exit;
  { Never automatically repair or relocate an explicit existing setting. }
  if S<>'' then begin Result := Number(S,Base); Exit; end;
  Result := SuggestBase(P,Card,M,XMS,Base);
end;

function AddEdit(Plan: PPlan; const Path,Group,Name,Value: string): Boolean;
begin
  Result := False; if Plan^.Count=EditLimit then Exit;
  with Plan^.Edits[Plan^.Count] do begin
    if not ReadIni(Group,Name,Path,OldValue) then Exit;
    FileName := Path; Section := Group; Key := Name;
    NewValue := Value;
  end;
  Inc(Plan^.Count); Result := True;
end;

function AliasFor(const P: TSetupPaths; const Category,Driver: string;
                  var Alias: string): Boolean;
var I: Word;
    Key,Value,FreeKey: string;
begin
  Result := False; Alias := ''; FreeKey := '';
  { Preserve another driver's entries and reuse our own alias on upgrades. }
  for I:=0 to 9 do begin
    Key := Category; if I<>0 then Key := Key+IntToStr(I);
    if not ReadIni('drivers',Key,P.Windows+'SYSTEM.INI',Value) then Exit;
    if ModuleName(Value)=UpperCase(Driver) then begin
      Alias := Key; Result := True; Exit;
    end;
    if ((Value=#1) or (Value='')) and (FreeKey='') then FreeKey := Key;
  end;
  Alias := FreeKey; Result := Alias<>'';
end;

function DriverLoaded(const Driver: string): Boolean;
var B: array[0..255] of Char;
begin
  StrPCopy(B,Driver); Result := GetModuleHandle(B)<>0;
  if not Result then begin
    StrPCopy(B,Copy(Driver,1,Length(Driver)-4)); Result := GetModuleHandle(B)<>0;
  end;
end;

function CheckSynthCore(const P: TSetupPaths; const Name: string;
                        var CopyCore: Boolean; var Report: string): Boolean;
begin
  Result := False;
  Report := Name+' is missing or is not a Windows 3.x DLL.';
  if not IsWin16File(P.Source+Name,True) then Exit;
  CopyCore := not SameFileContents(P.Source+Name,P.System+Name);
  if CopyCore and DriverLoaded(Name) then begin
    Report := Name+' is loaded. Exit Windows and update it from DOS.';
    Exit;
  end;
  Result := True;
end;

function PreparePlan(const P: TSetupPaths; Card: Word; Base: LongInt;
                      Plan: PPlan; var Report: string): Boolean;
var Stem,Driver,Alias,Category,OldBoot,NewBoot,Ini,Mode: string;
    I: Word;
begin
  Result := False; Stem := DriverStem(Card); Driver := Stem+'.DLL';
  Report := 'The selected driver is loaded. Remove it in Control Panel, restart Windows,'+
            ' then run Setup; or update the DLL manually from DOS.';
  if DriverLoaded(Driver) then Exit;
  Report := 'Close AUDMIXER before installing.';
  if DriverLoaded(MixerFile) then Exit;
  Report := 'A required file is missing or is not a Windows 3.x binary.';
  if not IsWin16File(P.Source+Driver,True) then Exit;
  if not IsWin16File(P.Source+MixerFile,False) then Exit;
  if not FileExists(P.System+ManagerFile) then
    if not IsWin16File(P.Source+ManagerFile,True) then Exit;
  if not CheckSynthCore(P,OplCoreFile,Plan^.CopyOplCore,Report) then Exit;
  if not CheckSynthCore(P,SfCoreFile,Plan^.CopySfCore,Report) then Exit;
  Report := 'SYSTEM.INI is missing or its boot drivers line is too long.';
  if not FileExists(P.Windows+'SYSTEM.INI') then Exit;
  if not ReadIni('boot','drivers',P.Windows+'SYSTEM.INI',OldBoot) then Exit;
  if OldBoot=#1 then OldBoot := '';
  Report := 'Cannot safely extend the boot drivers line (254 characters maximum).';
  if not MakeBootLine(OldBoot,P.Windows+'SYSTEM.INI',NewBoot) then Exit;
  if not AddEdit(Plan,P.Windows+'SYSTEM.INI','boot','drivers',NewBoot) then Exit;
  for I:=Low(DriverCategories) to High(DriverCategories) do begin
    Category := DriverCategories[I];
    Report := 'No free '+Category+' registration, or an INI entry is too long.';
    if not AliasFor(P,Category,Driver,Alias) then Exit;
    if not AddEdit(Plan,P.Windows+'SYSTEM.INI','drivers',Alias,Driver) then Exit;
    if not AddEdit(Plan,P.Windows+'CONTROL.INI','Userinstallable.drivers',Alias,
                   Driver) then Exit;
  end;
  Report := 'Cannot read existing driver settings safely.';
  Ini := P.Windows+Stem+'.INI';
  if not AddEdit(Plan,Ini,Stem,'PhysicalBase','$'+IntToHex(Base,8)) then Exit;
  { The synth DLLs have one state each. Avoid enabling a second synth
    by default, and preserve explicit settings on an upgrade. }
  if Registered(P,DriverStem(3-Card)+'.DLL') then begin
    if not ReadIni(Stem,'MidiSynth',Ini,Mode) then Exit;
    if Mode=#1 then begin
      if not ReadIni(Stem,'OplMidi',Ini,Mode) then Exit;
      if Mode=#1 then
        if not AddEdit(Plan,Ini,Stem,'MidiSynth','0') then Exit;
    end;
  end;
  if Card=1 then Category := 'Creative Audigy 1'
  else Category := 'Creative Audigy 2/ZS';
  Report := 'Cannot prepare the Control Panel driver description.';
  if not AddEdit(Plan,P.Windows+'CONTROL.INI','drivers.desc',Driver,Category) then Exit;
  Result := True;
end;

function InstallCard(const P: TSetupPaths; Card: Word; Base: LongInt;
                     var Report: string): Boolean;
var Plan: PPlan;
    Stem,Driver,Backup: string;
    I: Integer;
    ConfigExisted,FilesOK,RolledBack,Committed: Boolean;
begin
  Result := False; New(Plan); FillChar(Plan^,SizeOf(Plan^),0);
  BeginFiles; Committed := False; ConfigExisted := True;
  Stem := DriverStem(Card); Driver := Stem+'.DLL';
  try
    if not PreparePlan(P,Card,Base,Plan,Report) then Exit;
    ConfigExisted := FileExists(P.Windows+Stem+'.INI');
    Backup := 'AUD'+IntToStr(Card);
    Report := 'Cannot back up SYSTEM.INI. No configuration changes were made.';
    if not BackupOnce(P.Windows+'SYSTEM.INI',P.Windows+Backup+'INST.BAK') then Exit;
    Report := 'Cannot back up CONTROL.INI. No configuration changes were made.';
    if not BackupOnce(P.Windows+'CONTROL.INI',P.Windows+Backup+'CTRL.BAK') then Exit;
    Report := 'Cannot back up the driver INI. No configuration changes were made.';
    if not BackupOnce(P.Windows+Stem+'.INI',P.Windows+Backup+'CFG.BAK') then Exit;
    Report := 'Cannot stage files. Check free disk space and write protection.'+
              ' AS?NEW.TMP / AS?OLD.TMP from an interrupted setup must be recovered first.';
    if not StageFile(P.Source+Driver,P.System+Driver,P.System,0) then Exit;
    if not StageFile(P.Source+MixerFile,P.System+MixerFile,P.System,1) then Exit;
    if not FileExists(P.System+ManagerFile) then
      if not StageFile(P.Source+ManagerFile,P.System+ManagerFile,P.System,2) then Exit;
    if Plan^.CopyOplCore then
      if not StageFile(P.Source+OplCoreFile,P.System+OplCoreFile,P.System,3) then Exit;
    if Plan^.CopySfCore then
      if not StageFile(P.Source+SfCoreFile,P.System+SfCoreFile,P.System,4) then Exit;
    Report := 'Cannot replace installed files. Close programs using them and retry.';
    if DriverLoaded(Driver) or DriverLoaded(MixerFile) or
       (Plan^.CopyOplCore and DriverLoaded(OplCoreFile)) or
       (Plan^.CopySfCore and DriverLoaded(SfCoreFile)) then Exit;
    if not PutFiles then Exit;
    Report := 'An INI update failed. Setup is restoring the previous configuration.';
    if Plan^.Count=0 then Exit;
    for I:=0 to Plan^.Count-1 do begin
      { Include a failed API call in rollback: it may have partially changed disk. }
      Plan^.Done := I+1;
      with Plan^.Edits[I] do
        if not WriteIni(Section,Key,NewValue,FileName) then Exit;
    end;
    for I:=0 to Plan^.Count-1 do
      InvalidateIni(Plan^.Edits[I].FileName);
    Committed := True; Result := True;
    Report := 'Installed. Restart Windows before using the driver or AUDMIXER.';
  finally
    RolledBack := True;
    if not Committed then begin
      if Plan^.Done<>0 then
        for I:=Plan^.Done-1 downto 0 do
          with Plan^.Edits[I] do begin
            if not WriteIni(Section,Key,OldValue,FileName) then RolledBack := False;
            InvalidateIni(FileName);
          end;
      if not ConfigExisted then
        if not RemoveFile(P.Windows+Stem+'.INI') then RolledBack := False;
    end;
    FilesOK := EndFiles(Committed);
    if not Committed and (not RolledBack or not FilesOK) then
      Report := 'Rollback incomplete. Do not restart Windows yet. Restore SYSTEM.INI /'+
                ' CONTROL.INI from AUD'+IntToStr(Card)+'*.BAK; recover AS?OLD.TMP in SYSTEM.';
    if Committed and not FilesOK then
      Report := 'Installed. Restart Windows. An old AS?OLD.TMP backup could not be removed.';
    Dispose(Plan);
  end;
end;

end.
