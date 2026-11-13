unit SProgman;

{ Optional post-install Program Manager icon. No driver or INI operations. }
{$F+}
{$W+}
{$B-}
interface

function InstallMixerIcon(const SystemDir: string): Boolean;

implementation
uses WinTypes, WinProcs, SysUtils, DDEML, SFiles;

const GroupTitle: string[15]='Audio Utilities';
      ItemTitle: string[11]='Audio Mixer';
      MixerFile: string[12]='AUDMIXER.EXE';
      WaitMS=5000;
      BufferBytes=32760;
type
  TGroupBuffer=array[0..BufferBytes-1] of Char;
  PGroupBuffer=^TGroupBuffer;

function ShortcutCallback(CallType,Fmt: Word; Conv: HConv; Name1,Name2: HSZ;
  Data: HDDEData; Data1,Data2: LongInt): HDDEData; export;
begin
  { Synchronous client only; no server requests or application callbacks. }
  Result := 0;
end;

function Execute(Conversation: HConv; const Command: string): Boolean;
var B: array[0..255] of Char;
begin
  StrPCopy(B,Command);
  { XTYP_EXECUTE returns an acknowledgement, not a data handle to free. }
  Result := DdeClientTransaction(@B,LongInt(Length(Command)+1),Conversation,
                                 0,0,XTYP_EXECUTE,WaitMS,nil)<>0;
end;

function FirstField(Buffer: PGroupBuffer; var Position: Word; Limit: Word;
                     var Value: string): Boolean;
var Closed: Boolean;
    C: Char;
begin
  Result := False; Value := ''; Closed := False;
  while Position<Limit do begin
    if not (Buffer^[Position] in [' ',#9]) then Break;
    Inc(Position);
  end;
  if Position>=Limit then Exit;
  if Buffer^[Position]<>'"' then Exit;
  Inc(Position);
  while Position<Limit do begin
    C := Buffer^[Position]; Inc(Position);
    if C in [#0,#13,#10] then Exit;
    if C='"' then begin
      if (Position<Limit) and (Buffer^[Position]='"') then Inc(Position)
      else begin Closed := True; Break; end;
    end;
    if Length(Value)=255 then Exit;
    Value := Value+C;
  end;
  if not Closed then Exit;
  while Position<Limit do begin
    if not (Buffer^[Position] in [' ',#9]) then Break;
    Inc(Position);
  end;
  if Position>=Limit then Exit;
  if Buffer^[Position]<>',' then Exit;
  Inc(Position); Result := True;
end;

procedure NextLine(Buffer: PGroupBuffer; var Position: Word; Limit: Word);
begin
  while Position<Limit do begin
    if Buffer^[Position] in [#13,#10] then Break;
    Inc(Position);
  end;
  while Position<Limit do begin
    if not (Buffer^[Position] in [#13,#10]) then Break;
    Inc(Position);
  end;
end;

function OurCommand(const Command: string): Boolean;
var Name: string;
    I: Word;
begin
  Name := ''; I := 1;
  while I<=Length(Command) do begin
    if not (Command[I] in [' ',#9]) then Break;
    Inc(I);
  end;
  if I<=Length(Command) then begin
    if Command[I]='"' then begin
      Inc(I);
      while I<=Length(Command) do begin
        if Command[I]='"' then Break;
        Name := Name+Command[I]; Inc(I);
      end;
    end else
      while I<=Length(Command) do begin
        if Command[I] in [' ',#9] then Break;
        Name := Name+Command[I]; Inc(I);
      end;
  end;
  Result := UpperCase(ExtractFileName(Name))=MixerFile;
end;

function ExistingItem(Conversation: HConv; Group: HSZ; var Found: Boolean): Boolean;
var Data: HDDEData;
    Memory: THandle;
    Buffer: PGroupBuffer;
    Copied: LongInt;
    Position,Limit: Word;
    Name,Command: string;
begin
  Result := False; Found := False;
  Data := DdeClientTransaction(nil,0,Conversation,Group,CF_TEXT,XTYP_REQUEST,WaitMS,nil);
  if Data=0 then Exit;
  try
    Memory := GlobalAlloc(GMEM_MOVEABLE,LongInt(BufferBytes));
    if Memory=0 then Exit;
    try
      Buffer := GlobalLock(Memory);
      if Buffer=nil then Exit;
      try
        Copied := DdeGetData(Data,Buffer,BufferBytes,0);
        { Reject incomplete text instead of risking a duplicate item. }
        if (Copied<1) or (Copied>=BufferBytes) then Exit;
        Limit := 0;
        while Limit<Word(Copied) do begin
          if Buffer^[Limit]=#0 then Break;
          Inc(Limit);
        end;
        if Limit=Word(Copied) then Exit;
        if Limit=0 then Exit;
        Position := 0;
        if not FirstField(Buffer,Position,Limit,Name) then Exit;
        if UpperCase(Name)<>UpperCase(GroupTitle) then Exit;
        NextLine(Buffer,Position,Limit);
        while Position<Limit do begin
          if not FirstField(Buffer,Position,Limit,Name) then Exit;
          if UpperCase(Name)=UpperCase(ItemTitle) then begin
            if not FirstField(Buffer,Position,Limit,Command) then Exit;
            { Never replace an unrelated program sharing our friendly title. }
            if not OurCommand(Command) then Exit;
            Found := True;
          end;
          NextLine(Buffer,Position,Limit);
        end;
        Result := True;
      finally
        GlobalUnlock(Memory);
      end;
    finally
      GlobalFree(Memory);
    end;
  finally
    DdeFreeDataHandle(Data);
  end;
end;

function InstallMixerIcon(const SystemDir: string): Boolean;
var Instance: LongInt;
    Service,Group: HSZ;
    Conversation: HConv;
    Thunk: TFarProc;
    Callback: TCallback;
    Initialized,Found: Boolean;
    Target,AddCommand: string;
    B: array[0..255] of Char;
begin
  Result := False;
  Target := Slash(SystemDir)+MixerFile;
  if not FileExists(Target) then Exit;
  if (Pos('"',Target)<>0) or (Pos(#13,Target)<>0) or (Pos(#10,Target)<>0) then Exit;
  { Check before concatenation: Delphi1 short strings must never truncate. }
  if Length(Target)+Length('[AddItem("')+Length('","Audio Mixer")]')>254 then Exit;
  AddCommand := '[AddItem("'+Target+'","Audio Mixer")]';
  Instance := 0; Service := 0; Group := 0; Conversation := 0; Initialized := False;
  Thunk := MakeProcInstance(@ShortcutCallback,HInstance);
  if not Assigned(Thunk) then Exit;
  @Callback := Thunk;
  try
    if DdeInitialize(Instance,Callback,APPCMD_CLIENTONLY,0)<>DMLERR_NO_ERROR then Exit;
    Initialized := True;
    Service := DdeCreateStringHandle(Instance,'PROGMAN',CP_WINANSI);
    StrPCopy(B,GroupTitle); Group := DdeCreateStringHandle(Instance,B,CP_WINANSI);
    if (Service=0) or (Group=0) then Exit;
    Conversation := DdeConnect(Instance,Service,Service,nil);
    if Conversation=0 then Exit;
    if not Execute(Conversation,'[CreateGroup("Audio Utilities")]') then Exit;
    if not ExistingItem(Conversation,Group,Found) then Exit;
    if Found then
      if not Execute(Conversation,'[ReplaceItem("Audio Mixer")]') then Exit;
    Result := Execute(Conversation,AddCommand);
  finally
    if Conversation<>0 then DdeDisconnect(Conversation);
    if Group<>0 then DdeFreeStringHandle(Instance,Group);
    if Service<>0 then DdeFreeStringHandle(Instance,Service);
    if Initialized then DdeUninitialize(Instance);
    FreeProcInstance(Thunk);
  end;
end;

end.
