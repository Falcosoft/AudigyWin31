unit SFiles;

{$F+}
{$I+}
{$B-}
interface
uses WinTypes;

function Slash(const S: string): string;
function ReadIni(const Section,Key,FileName: string; var Value: string): Boolean;
function WriteIni(const Section,Key,Value,FileName: string): Boolean;
procedure InvalidateIni(const FileName: string);
function CopyFileSafe(const Source,Destination: string): Boolean;
function SameFileContents(const First,Second: string): Boolean;
function BackupOnce(const Source,Destination: string): Boolean;
function IsWin16File(const Name: string; LibraryFile: Boolean): Boolean;
function RemoveFile(const Name: string): Boolean;

{ Stage complete copies first; retain originals until all INI writes succeed. }
procedure BeginFiles;
function StageFile(const Source,Target,Folder: string; Index: Word): Boolean;
function PutFiles: Boolean;
function EndFiles(Commit: Boolean): Boolean;

implementation
uses WinProcs, SysUtils;

type
  TBuffer=array[0..2047] of Byte;
  PBuffer=^TBuffer;
  TFileChange=record
    Destination,Stage,OldName: string;
    Staged,OldMoved,NewMoved: Boolean;
  end;
const LastFileSlot=4;
var Changes: array[0..LastFileSlot] of TFileChange;

function Slash(const S: string): string;
begin
  Result := S;
  if Result<>'' then
    if Result[Length(Result)]<>'\' then Result := Result+'\';
end;

function ReadIni(const Section,Key,FileName: string; var Value: string): Boolean;
var S,K,F,B: array[0..255] of Char;
    N: Word;
begin
  StrPCopy(S,Section); StrPCopy(K,Key); StrPCopy(F,FileName);
  { #1 distinguishes a missing key from a present, empty key for rollback. }
  N := GetPrivateProfileString(S,K,#1,B,SizeOf(B),F);
  Result := N<SizeOf(B)-1; Value := '';
  if Result then Value := StrPas(B);
end;

function WriteIni(const Section,Key,Value,FileName: string): Boolean;
var S,K,V,F: array[0..255] of Char;
begin
  StrPCopy(S,Section); StrPCopy(K,Key); StrPCopy(F,FileName);
  StrPCopy(V,Value);
  if Value=#1 then Result := WritePrivateProfileString(S,K,nil,F)
  else Result := WritePrivateProfileString(S,K,V,F);
end;

procedure InvalidateIni(const FileName: string);
var F: array[0..255] of Char;
begin
  StrPCopy(F,FileName);
  { Cache invalidation is not a Boolean file-write success test. }
  WritePrivateProfileString(nil,nil,nil,F);
end;

function RemoveFile(const Name: string): Boolean;
var F: File;
    E: Integer;
begin
  Result := True; if not FileExists(Name) then Exit;
  Assign(F,Name);
  {$I-} Erase(F); E := IOResult; {$I+}
  Result := E=0;
end;

function MoveFile(const Source,Destination: string): Boolean;
var F: File;
    E: Integer;
begin
  Result := False; if FileExists(Destination) then Exit;
  Assign(F,Source);
  {$I-} Rename(F,Destination); E := IOResult; {$I+}
  Result := E=0;
end;

function CopyFileSafe(const Source,Destination: string): Boolean;
var A,B: File;
    P: PBuffer;
    Memory: THandle;
    Got,Put: Word;
    E,CE: Integer;
    Mode: Byte;
    Opened: Boolean;
begin
  Result := False;
  if FileExists(Destination) then Exit;
  Memory := GlobalAlloc(GMEM_MOVEABLE,LongInt(2048));
  if Memory=0 then Exit;
  P := GlobalLock(Memory);
  if P=nil then begin GlobalFree(Memory); Exit; end;
  Assign(A,Source); Mode := FileMode; FileMode := $40;
  {$I-} Reset(A,1); E := IOResult; {$I+}
  FileMode := Mode; Opened := False;
  if E=0 then begin
    Assign(B,Destination);
    if not FileExists(Destination) then begin
      {$I-} Rewrite(B,1); E := IOResult; {$I+}
      Opened := E=0;
      if Opened then begin
        repeat
          Got := 0; Put := 0;
          {$I-} BlockRead(A,P^,SizeOf(P^),Got); E := IOResult; {$I+}
          if (E=0) and (Got<>0) then begin
            {$I-} BlockWrite(B,P^,Got,Put); E := IOResult; {$I+}
            if (E=0) and (Got<>Put) then E := 101;
          end;
        until (E<>0) or (Got=0);
        {$I-} Close(B); CE := IOResult; {$I+}
        if E=0 then E := CE;
      end;
    end else E := 5;
    {$I-} Close(A); CE := IOResult; {$I+}
    Result := Opened and (E=0) and (CE=0);
    if Opened and not Result then RemoveFile(Destination);
  end;
  GlobalUnlock(Memory); GlobalFree(Memory);
end;

function SameFileContents(const First,Second: string): Boolean;
var A,B: File;
    P,Q: TBuffer;
    NA,NB,I: Word;
    EA,EB: Integer;
    Mode: Byte;
begin
  Result := False;
  Assign(A,First); Assign(B,Second);
  Mode := FileMode; FileMode := $40;
  {$I-} Reset(A,1); EA := IOResult; {$I+}
  EB := EA;
  if EA=0 then begin {$I-} Reset(B,1); EB := IOResult; {$I+} end;
  FileMode := Mode;
  if EA<>0 then Exit;
  try
    if EB<>0 then Exit;
    try
      repeat
        {$I-} BlockRead(A,P,SizeOf(P),NA); EA := IOResult; {$I+}
        if EA<>0 then Exit;
        {$I-} BlockRead(B,Q,SizeOf(Q),NB); EB := IOResult; {$I+}
        if (EB<>0) or (NA<>NB) then Exit;
        if NA<>0 then
          for I:=0 to NA-1 do
            if P[I]<>Q[I] then Exit;
      until NA=0;
      Result := True;
    finally
      {$I-} Close(B); EB := IOResult; {$I+}
      if EB<>0 then Result := False;
    end;
  finally
    {$I-} Close(A); EA := IOResult; {$I+}
    if EA<>0 then Result := False;
  end;
end;

function BackupOnce(const Source,Destination: string): Boolean;
begin
  Result := True;
  if not FileExists(Source) or FileExists(Destination) then Exit;
  InvalidateIni(Source);
  Result := CopyFileSafe(Source,Destination);
end;

function IsWin16File(const Name: string; LibraryFile: Boolean): Boolean;
var F: File;
    B: array[0..63] of Byte;
    E,CE: Integer;
    Got: Word;
    Offset,LengthBytes: LongInt;
    Mode: Byte;
begin
  Result := False; Got := 0; Assign(F,Name); Mode := FileMode; FileMode := $40;
  {$I-} Reset(F,1); E := IOResult; {$I+}
  FileMode := Mode; if E<>0 then Exit;
  {$I-}
  LengthBytes := FileSize(F); E := IOResult;
  if E=0 then begin BlockRead(F,B,64,Got); E := IOResult; end;
  {$I+}
  if (E=0) and (Got=64) and (B[0]=$4D) and (B[1]=$5A) then begin
    Move(B[60],Offset,4);
    if (Offset>=64) and (Offset<=LengthBytes-64) then begin
      {$I-}
      Seek(F,Offset); E := IOResult;
      if E=0 then begin BlockRead(F,B,64,Got); E := IOResult; end;
      {$I+}
      Result := (E=0) and (Got=64) and (B[0]=$4E) and (B[1]=$45) and
                (((B[13] and $80)<>0)=LibraryFile) and (B[54]=2);
    end;
  end;
  {$I-} Close(F); CE := IOResult; {$I+}
  if CE<>0 then Result := False;
end;

procedure BeginFiles;
begin
  FillChar(Changes,SizeOf(Changes),0);
end;

function StageFile(const Source,Target,Folder: string; Index: Word): Boolean;
begin
  Result := False; if Index>LastFileSlot then Exit;
  with Changes[Index] do begin
    { Source may already be the desired installed file; do not touch it. }
    if UpperCase(Source)=UpperCase(Target) then begin Result := True; Exit; end;
    Destination := Target;
    Stage := Slash(Folder)+'AS'+IntToStr(Index)+'NEW.TMP';
    OldName := Slash(Folder)+'AS'+IntToStr(Index)+'OLD.TMP';
    if FileExists(Stage) or FileExists(OldName) then Exit;
    Result := CopyFileSafe(Source,Stage); Staged := Result;
  end;
end;

function PutFiles: Boolean;
var I: Word;
begin
  Result := False;
  for I:=0 to LastFileSlot do
    with Changes[I] do if Staged then begin
      if FileExists(Destination) then begin
        if not MoveFile(Destination,OldName) then Exit;
        OldMoved := True;
      end;
      if not MoveFile(Stage,Destination) then Exit;
      NewMoved := True; Staged := False;
    end;
  Result := True;
end;

function EndFiles(Commit: Boolean): Boolean;
var I: Integer;
begin
  Result := True;
  for I:=LastFileSlot downto 0 do
    with Changes[I] do begin
      if Commit then begin
        if OldMoved then
          if not RemoveFile(OldName) then Result := False;
      end else begin
        if NewMoved then
          if not RemoveFile(Destination) then Result := False;
        if OldMoved then
          if not MoveFile(OldName,Destination) then Result := False;
      end;
      if Staged then
        if not RemoveFile(Stage) then Result := False;
    end;
end;

end.
