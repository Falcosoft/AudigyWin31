unit MxPanel;
{ Capability-driven extended controls inside the existing mixer window. }
interface
uses WinTypes,WinProcs,Messages,Classes,Controls,Forms,StdCtrls,ExtCtrls,
     SysUtils,MMSystem,MxTypes,MxLoad;
type
  TMxControlInfo=class(TObject)
    Control: TMxControl;
  end;
  TMxPanel=class(TPanel)
  private
    Lines,ControlBox,Choices: TComboBox;
    Switch: TCheckBox;
    Status: TLabel;
    CutoffBar: TScrollBar;
    CutoffLabel: TLabel;
    AudigyMixer,CutoffReady,CutoffDirty: Boolean;
    CutoffID: LongInt;
    Sliders: array[0..9] of TScrollBar;
    Labels,Values: array[0..9] of TLabel;
    Clock: TTimer;
    HandleID: Word;
    Current: TMxControl;
    Desired: TMxValues;
    Updating,Dirty,HaveValues: Boolean;
    LastEdit,LastRead: LongInt;
    ValueCount,Channels: Word;
    DirtyMask: Word;
    SelectedLine,SelectedControl: Integer;
    CloseWhenReady: Boolean;
    procedure FreeControls;
    procedure LineChanged(Sender: TObject);
    procedure ControlChanged(Sender: TObject);
    procedure SliderChanged(Sender: TObject);
    procedure SwitchChanged(Sender: TObject);
    procedure CutoffChanged(Sender: TObject);
    procedure ChoiceChanged(Sender: TObject);
    procedure Poll(Sender: TObject);
    procedure ReadValues;
    procedure DisplayValues;
    procedure ReadCutoff;
    procedure DescribeCutoff(var D: TMxDetails);
    function Flush: Boolean;
    function FlushCurrent: Boolean;
    function FlushCutoff: Boolean;
    procedure QueueWrite;
    function Details(var D: TMxDetails): Boolean;
    function HasBoth: Boolean;
    function PreservePercent(Value,Reported: LongInt): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function SelectDevice(ID: Word): Boolean;
    function CloseDevice: Boolean;
    function CanLeave: Boolean;
    function RequestClose: Boolean;
  end;
implementation
function BassSwitch(const C: TMxControl): Boolean;
begin
  Result := (C.ID=MxBassRedirect) and (C.Kind=MX_ONOFF) and
    (C.Flags=MX_UNIFORM) and (C.Items=0) and
    (C.Minimum=0) and (C.Maximum=1) and (StrPas(C.Name)='Bass Redirect');
end;

function BassCutoff(const C: TMxControl): Boolean;
begin
  Result := (C.ID=MxBassCutoff) and (C.Kind=MX_FADER) and
    (C.Flags=MX_UNIFORM) and (C.Items=0) and (C.Steps=MxBassSteps+1) and
    (C.Minimum=0) and (C.Maximum=65535) and (StrPas(C.Name)='Bass Redirect Cutoff');
end;

function FrequencyLabel(const Name: string): string;
var Hz: LongInt;
    Code: Integer;
    Fraction: string;
begin
  Result := Name;
  if Length(Name)<4 then Exit;
  if Copy(Name,Length(Name)-2,3)<>' Hz' then Exit;
  Val(Copy(Name,1,Length(Name)-3),Hz,Code);
  if (Code<>0) or (Hz<1000) then Exit;
  Result := IntToStr(Hz div 1000);
  if Hz mod 1000<>0 then begin
    Fraction := Copy(IntToStr(1000+Hz mod 1000),2,3);
    while Fraction[Length(Fraction)]='0' do Delete(Fraction,Length(Fraction),1);
    Result := Result+'.'+Fraction;
  end;
  Result := Result+' kHz';
end;

constructor TMxPanel.Create(AOwner: TComponent);
var I: Integer;
begin
  inherited Create(AOwner); BevelOuter := bvNone;
  HandleID := 0; Updating := True; Dirty := False; DirtyMask := 0; HaveValues := False;
  SelectedLine := -1; SelectedControl := -1; CloseWhenReady := False;
  Lines := TComboBox.Create(Self); Lines.Parent := Self;
  Lines.Style := csDropDownList; Lines.SetBounds(0,0,238,24);
  Lines.OnChange := LineChanged;
  ControlBox := TComboBox.Create(Self); ControlBox.Parent := Self;
  ControlBox.Style := csDropDownList; ControlBox.SetBounds(246,0,338,24);
  ControlBox.OnChange := ControlChanged;
  Switch := TCheckBox.Create(Self); Switch.Parent := Self;
  Switch.SetBounds(20,50,540,24); Switch.Caption := 'Enabled';
  Switch.OnClick := SwitchChanged; Switch.Visible := False;
  CutoffLabel := TLabel.Create(Self); CutoffLabel.Parent := Self;
  CutoffLabel.SetBounds(20,86,120,18); CutoffLabel.Visible := False;
  CutoffBar := TScrollBar.Create(Self); CutoffBar.Parent := Self;
  CutoffBar.SetBounds(20,108,240,20);
  CutoffBar.Min := 0; CutoffBar.Max := MxBassSteps;
  CutoffBar.SmallChange := 1; CutoffBar.LargeChange := 4;
  CutoffBar.Enabled := False; CutoffBar.Visible := False;
  CutoffBar.OnChange := CutoffChanged;
  Choices := TComboBox.Create(Self); Choices.Parent := Self;
  Choices.Style := csDropDownList; Choices.SetBounds(20,50,400,24);
  Choices.OnChange := ChoiceChanged; Choices.Visible := False;
  for I:=0 to 9 do begin
    Labels[I] := TLabel.Create(Self); Labels[I].Parent := Self;
    Labels[I].AutoSize := False;
    Labels[I].SetBounds(4+I*57,34,62,18); Labels[I].Alignment := taCenter;
    Sliders[I] := TScrollBar.Create(Self); Sliders[I].Parent := Self;
    Sliders[I].Kind := Forms.sbVertical;
    Sliders[I].SetBounds(26+I*57,56,18,160);
    Sliders[I].Min := 0; Sliders[I].Max := 100; Sliders[I].Tag := I;
    Sliders[I].SmallChange := 1; Sliders[I].LargeChange := 5;
    Sliders[I].Visible := False; Labels[I].Visible := False;
    Sliders[I].OnChange := SliderChanged;
    Values[I] := TLabel.Create(Self); Values[I].Parent := Self;
    Values[I].AutoSize := False;
    Values[I].SetBounds(4+I*57,224,62,18); Values[I].Alignment := taCenter;
    Values[I].Visible := False;
  end;
  Status := TLabel.Create(Self); Status.Parent := Self;
  Status.AutoSize := False; Status.WordWrap := True;
  Status.SetBounds(4,250,576,40);
  Clock := TTimer.Create(Self); Clock.Enabled := False;
  Clock.Interval := 100; Clock.OnTimer := Poll;
  Updating := False; Current.ID := 0;
end;

procedure TMxPanel.FreeControls;
var I: Integer;
begin
  for I:=0 to ControlBox.Items.Count-1 do ControlBox.Items.Objects[I].Free;
  ControlBox.Items.Clear;
  Current.ID := 0; Dirty := False; DirtyMask := 0; HaveValues := False;
  Switch.Visible := False; Choices.Visible := False;
  CutoffID := 0; CutoffReady := False; CutoffDirty := False;
  CutoffBar.Visible := False; CutoffLabel.Visible := False;
  for I:=0 to 9 do begin
    Sliders[I].Visible := False; Labels[I].Visible := False; Values[I].Visible := False;
  end;
end;

function TMxPanel.Flush: Boolean;
begin
  Result := FlushCurrent;
  if Result then Result := FlushCutoff;
end;

function TMxPanel.FlushCurrent: Boolean;
var D: TMxDetails;
    Err: Word;
    I: Word;
    Latest: TMxValues;
begin
  Result := True; if not Dirty then Exit;
  Result := False; if not Details(D) then Exit;
  D.Data := @Latest;
  Err := mixerGetControlDetails(HandleID,@D,MX_HANDLE);
  if Err<>0 then Exit;
  for I:=0 to ValueCount-1 do
    if (DirtyMask and (Word(1) shl I))=0 then
      if not PreservePercent(Desired[I],Latest[I]) then Desired[I] := Latest[I];
  D.Data := @Desired;
  Err := mixerSetControlDetails(HandleID,@D,MX_HANDLE);
  if Err=0 then begin
    Dirty := False; DirtyMask := 0; LastRead := timeGetTime;
    Status.Caption := 'Setting accepted; hardware application is asynchronous.';
    Result := True;
  end else if Err=4 then Status.Caption := 'Driver busy; retrying...'
  else begin
    Dirty := False; DirtyMask := 0;
    Status.Caption := 'Mixer write error '+IntToStr(Err); Result := True;
  end;
end;

procedure TMxPanel.DescribeCutoff(var D: TMxDetails);
begin
  FillChar(D,SizeOf(D),0);
  D.Size := SizeOf(D); D.ControlID := CutoffID;
  D.Channels := 1; D.DetailSize := SizeOf(LongInt);
end;

function TMxPanel.FlushCutoff: Boolean;
var D: TMxDetails;
    Raw: LongInt;
    Err: Word;
begin
  Result := True;
  if not CutoffDirty then Exit;
  DescribeCutoff(D);
  Raw := (LongInt(CutoffBar.Position)*65535+MxBassSteps div 2) div MxBassSteps;
  D.Data := @Raw;
  Err := mixerSetControlDetails(HandleID,@D,MX_HANDLE);
  if Err=4 then begin
    Status.Caption := 'Driver busy; retrying...'; Result := False; Exit;
  end;
  CutoffDirty := False;
  if Err=0 then begin
    LastRead := timeGetTime;
    Status.Caption := 'Setting accepted; hardware application is asynchronous.';
  end else begin
    CutoffReady := False; CutoffBar.Enabled := False;
    Status.Caption := 'Mixer write error '+IntToStr(Err);
  end;
end;

function TMxPanel.CanLeave: Boolean;
begin
  Result := Flush;
end;

function TMxPanel.RequestClose: Boolean;
begin
  Result := CloseDevice;
  CloseWhenReady := not Result;
end;

function TMxPanel.CloseDevice: Boolean;
begin
  Result := Flush; if not Result then Exit;
  if HandleID<>0 then begin
    Result := mixerClose(HandleID)=0;
    if not Result then begin Status.Caption := 'Driver busy; please try again.'; Exit; end;
  end;
  Clock.Enabled := False; HandleID := 0;
  FreeControls; Lines.Items.Clear; Current.ID := 0;
end;

destructor TMxPanel.Destroy;
begin
  if Clock<>nil then Clock.Enabled := False;
  if HandleID<>0 then mixerClose(HandleID);
  HandleID := 0; FreeControls;
  inherited Destroy;
end;

function TMxPanel.SelectDevice(ID: Word): Boolean;
var Caps: TMxCaps;
    L: TMxLine;
    I: Word;
    Err: Word;
begin
  Result := CloseDevice; if not Result then Exit;
  Result := False;
  FillChar(Caps,SizeOf(Caps),0);
  Err := mixerGetDevCaps(ID,@Caps,SizeOf(Caps));
  if (Err<>0) or (Caps.Destinations<1) or (Caps.Destinations>32) then Exit;
  Caps.Name[31] := #0;
  AudigyMixer := (StrPas(Caps.Name)='Creative Audigy 1 Mixer') or
                 (StrPas(Caps.Name)='Creative Audigy 2/ZS Mixer');
  Err := mixerOpen(@HandleID,ID,0,0,0);
  if Err<>0 then begin Status.Caption := 'Mixer open error '+IntToStr(Err); Exit; end;
  for I:=0 to Word(Caps.Destinations)-1 do begin
    FillChar(L,SizeOf(L),0); L.Size := SizeOf(L); L.Destination := I;
    if mixerGetLineInfo(HandleID,@L,MX_HANDLE)=0 then begin
      L.Name[63] := #0;
      Lines.Items.AddObject(StrPas(L.Name),TObject(L.ID));
    end;
  end;
  if Lines.Items.Count>0 then begin Lines.ItemIndex := 0; LineChanged(Self); end;
  Clock.Enabled := True; Result := True;
end;

procedure TMxPanel.LineChanged(Sender: TObject);
var L: TMxLine;
    LC: TMxLineControls;
    C: array[0..31] of TMxControl;
    Item: TMxControlInfo;
    I: Word;
    FoundSwitch: Boolean;
    Err: Word;
begin
  if Updating then Exit;
  if not Flush then begin
    Updating := True; Lines.ItemIndex := SelectedLine; Updating := False; Exit;
  end;
  SelectedLine := Lines.ItemIndex;
  Updating := True;
  try
    FreeControls; Current.ID := 0;
    if (HandleID=0) or (Lines.ItemIndex<0) then Exit;
    FillChar(L,SizeOf(L),0); L.Size := SizeOf(L);
    L.ID := LongInt(Lines.Items.Objects[Lines.ItemIndex]);
    Err := mixerGetLineInfo(HandleID,@L,MX_HANDLE or 2);
    if (Err<>0) or (L.Controls<1) or (L.Controls>32) then Exit;
    Channels := Word(L.Channels);
    FillChar(LC,SizeOf(LC),0); LC.Size := SizeOf(LC);
    LC.LineID := L.ID; LC.Count := L.Controls;
    LC.ControlSize := SizeOf(TMxControl); LC.Data := @C;
    Err := mixerGetLineControls(HandleID,@LC,MX_HANDLE);
    if Err<>0 then begin Status.Caption := 'Control query error '+IntToStr(Err); Exit; end;
    if AudigyMixer then begin
      FoundSwitch := False;
      for I:=0 to Word(L.Controls)-1 do begin
        C[I].Name[63] := #0;
        if BassSwitch(C[I]) then FoundSwitch := True;
        if BassCutoff(C[I]) then CutoffID := C[I].ID;
      end;
      if not FoundSwitch then CutoffID := 0;
    end;
    for I:=0 to Word(L.Controls)-1 do begin
      if (CutoffID=0) or (C[I].ID<>CutoffID) then begin
        Item := TMxControlInfo.Create; Item.Control := C[I]; Item.Control.Name[63] := #0;
        ControlBox.Items.AddObject(StrPas(Item.Control.Name),Item);
      end;
    end;
    if ControlBox.Items.Count>0 then ControlBox.ItemIndex := 0;
  finally Updating := False; end;
  ControlChanged(Self);
end;

function TMxPanel.HasBoth: Boolean;
begin
  Result := (Current.ID<>0) and (ValueCount=2) and (Current.Items=0) and
    ((Current.Kind and $FFFF0000)=$50030000);
end;

function TMxPanel.PreservePercent(Value,Reported: LongInt): Boolean;
var Steps,Q: LongInt;
begin
  Result := False;
  if not HaveValues or ((Current.Kind and $FFFF0000)<>$50030000) then Exit;
  if (Current.Steps<2) or (Current.Steps>100) then Exit;
  { Keep fine GUI intent if readback only reflects the same native gain step.
    A genuinely different reported step still replaces it on the next poll. }
  Steps := Current.Steps-1;
  Q := (Value*Steps+32767) div 65535;
  Q := (Q*65535+Steps div 2) div Steps;
  Result := Q=Reported;
end;

function TMxPanel.Details(var D: TMxDetails): Boolean;
begin
  FillChar(D,SizeOf(D),0); D.Size := SizeOf(D); D.ControlID := Current.ID;
  D.Channels := 1;
  if (Current.Flags and MX_UNIFORM)=0 then D.Channels := Channels;
  D.Items := Current.Items; D.DetailSize := 4;
  Result := (HandleID<>0) and (Current.ID<>0) and (ValueCount>=1) and (ValueCount<=10);
end;

procedure TMxPanel.ControlChanged(Sender: TObject);
var I: Integer;
    D: TMxDetails;
    Names: array[0..9] of TMxListText;
    Err: Word;
begin
  if Updating then Exit;
  if not Flush then begin
    Updating := True; ControlBox.ItemIndex := SelectedControl; Updating := False; Exit;
  end;
  SelectedControl := ControlBox.ItemIndex;
  Updating := True;
  try
    Current.ID := 0; ValueCount := 0; HaveValues := False;
    CutoffReady := False; CutoffBar.Enabled := False;
    CutoffBar.Visible := False; CutoffLabel.Visible := False;
    for I:=0 to 9 do begin
      Sliders[I].Visible := False; Labels[I].Visible := False; Values[I].Visible := False;
    end;
    Choices.Visible := False; Switch.Visible := False; Choices.Items.Clear;
    if ControlBox.ItemIndex<0 then Exit;
    Current := TMxControlInfo(ControlBox.Items.Objects[ControlBox.ItemIndex]).Control;
    ValueCount := 1;
    if (Current.Flags and MX_UNIFORM)=0 then ValueCount := Channels;
    if Current.Items<>0 then ValueCount := Word(Current.Items);
    if (Current.Items<>0) and ((Current.Flags and MX_UNIFORM)=0) and
       (Channels<>1) then begin
      Current.ID := 0; Status.Caption := 'Non-uniform multichannel lists are not supported.';
      Exit;
    end;
    if (ValueCount<1) or (ValueCount>10) or (Current.Items>10) then begin
      Current.ID := 0; Status.Caption := 'This control has too many values.'; Exit;
    end;
    FillChar(Names,SizeOf(Names),0);
    if Current.Items<>0 then begin
      Details(D); D.Channels := 1; D.DetailSize := SizeOf(TMxListText); D.Data := @Names;
      Err := mixerGetControlDetails(HandleID,@D,MX_HANDLE or 1);
      if Err<>0 then begin Current.ID := 0; Status.Caption := 'Item label query failed.'; Exit; end;
    end;
    if (Current.Kind=MX_SINGLE) or (Current.Kind=MX_MUX) then begin
      for I:=0 to Integer(ValueCount)-1 do begin
        Names[I].Name[63] := #0; Choices.Items.Add(StrPas(Names[I].Name));
      end;
      Choices.Visible := True;
    end else if Current.Kind=MX_ONOFF then begin
      Switch.Visible := True;
      if (CutoffID<>0) and BassSwitch(Current) then begin
        CutoffLabel.Caption := 'Cutoff';
        CutoffLabel.Visible := True; CutoffBar.Visible := True;
      end;
    end
    else if (Current.Kind and $FFFF0000)=$50030000 then begin
      { Every displayed percentage slider uses the same 1% / 5% GUI scale. }
      for I:=0 to 9 do begin
        Sliders[I].Position := 0; Sliders[I].Max := 100;
        Sliders[I].SmallChange := 1; Sliders[I].LargeChange := 5;
      end;
      for I:=0 to Integer(ValueCount)-1 do begin
        Sliders[I].Visible := True; Labels[I].Visible := True; Values[I].Visible := True;
        Labels[I].Caption := 'Level';
        if Current.Items<>0 then begin
          Names[I].Name[63] := #0; Labels[I].Caption := StrPas(Names[I].Name);
          if Current.Kind=MX_EQUALIZER then
            Labels[I].Caption := FrequencyLabel(Labels[I].Caption);
        end else if ValueCount=2 then
          if I=0 then Labels[I].Caption := 'Left' else Labels[I].Caption := 'Right';
      end;
      if HasBoth then begin
        Sliders[2].Visible := True; Labels[2].Visible := True; Values[2].Visible := True;
        Labels[2].Caption := 'Both';
      end;
    end else begin Current.ID := 0; Status.Caption := 'Unsupported control type.'; Exit; end;
    Status.Caption := 'Changes are live. Settings are shared with driver Setup.';
  finally Updating := False; end;
  ReadValues;
end;

procedure TMxPanel.DisplayValues;
var I,N: Integer;
    V: LongInt;
begin
  Updating := True;
  try
    Choices.ItemIndex := -1;
    for I:=0 to Integer(ValueCount)-1 do begin
      if Choices.Visible and (Desired[I]<>0) then Choices.ItemIndex := I;
      if Sliders[I].Visible then begin
        V := Desired[I]; if V<0 then V := 0; if V>65535 then V := 65535;
        N := Sliders[I].Max;
        Sliders[I].Position := N-Integer((V*N+32767) div 65535);
        Values[I].Caption := IntToStr((V*100+32767) div 65535)+'%';
      end;
    end;
    if HasBoth then begin
      V := (Desired[0]+Desired[1]) div 2;
      N := Sliders[2].Max;
      Sliders[2].Position := N-Integer((V*N+32767) div 65535);
      if Desired[0]=Desired[1] then
        Values[2].Caption := IntToStr((V*100+32767) div 65535)+'%'
      else Values[2].Caption := 'L/R';
    end;
    Switch.Checked := Desired[0]<>0;
    CutoffBar.Enabled := CutoffBar.Visible and CutoffReady and Switch.Checked;
  finally Updating := False; end;
end;

procedure TMxPanel.ReadValues;
var D: TMxDetails;
    V: TMxValues;
    Err,I: Word;
begin
  if Dirty or CutoffDirty or Updating or not Details(D) then Exit;
  FillChar(V,SizeOf(V),0); D.Data := @V;
  Err := mixerGetControlDetails(HandleID,@D,MX_HANDLE);
  if Err=0 then begin
    for I:=0 to ValueCount-1 do
      if not PreservePercent(Desired[I],V[I]) then Desired[I] := V[I];
    HaveValues := True; DisplayValues; ReadCutoff;
  end
  else Status.Caption := 'Mixer read error '+IntToStr(Err);
  LastRead := timeGetTime;
end;

procedure TMxPanel.ReadCutoff;
var D: TMxDetails;
    Raw: LongInt;
    Err: Word;
begin
  if not CutoffBar.Visible then Exit;
  DescribeCutoff(D); Raw := 0; D.Data := @Raw;
  Err := mixerGetControlDetails(HandleID,@D,MX_HANDLE);
  if Err<>0 then Exit;
  if Raw<0 then Raw := 0 else if Raw>65535 then Raw := 65535;
  Updating := True;
  try
    CutoffBar.Position := Integer((Raw*MxBassSteps+32767) div 65535);
    CutoffLabel.Caption := 'Cutoff: '+
      IntToStr(MxBassMinHz+CutoffBar.Position*MxBassStepHz)+' Hz';
    CutoffReady := True; CutoffBar.Enabled := Switch.Checked;
  finally Updating := False; end;
end;

procedure TMxPanel.QueueWrite;
begin
  if (HandleID=0) or (Current.ID=0) then Exit;
  Dirty := True; LastEdit := timeGetTime;
end;
procedure TMxPanel.SliderChanged(Sender: TObject);
var I,N: Integer;
    V: LongInt;
begin
  if Updating then Exit;
  I := TScrollBar(Sender).Tag;
  N := Sliders[I].Max;
  V := (LongInt(N-Sliders[I].Position)*65535+N div 2) div N;
  if HasBoth and (I=2) then begin
    Desired[0] := V; Desired[1] := V; DirtyMask := DirtyMask or 3;
  end else begin
    Desired[I] := V; DirtyMask := DirtyMask or (Word(1) shl I);
  end;
  DisplayValues;
  QueueWrite;
end;
procedure TMxPanel.SwitchChanged(Sender: TObject);
begin
  if Updating then Exit;
  Desired[0] := Ord(Switch.Checked); DirtyMask := 1; QueueWrite;
  CutoffBar.Enabled := CutoffBar.Visible and CutoffReady and Switch.Checked;
end;
procedure TMxPanel.CutoffChanged(Sender: TObject);
begin
  if Updating or not CutoffBar.Visible or not CutoffBar.Enabled then Exit;
  CutoffLabel.Caption := 'Cutoff: '+
    IntToStr(MxBassMinHz+CutoffBar.Position*MxBassStepHz)+' Hz';
  CutoffDirty := True; LastEdit := timeGetTime;
end;
procedure TMxPanel.ChoiceChanged(Sender: TObject);
begin
  if Updating or (Choices.ItemIndex<0) then Exit;
  FillChar(Desired,SizeOf(Desired),0); Desired[Choices.ItemIndex] := 1;
  DirtyMask := $3FF; QueueWrite;
end;
procedure TMxPanel.Poll(Sender: TObject);
begin
  if CloseWhenReady then begin
    if CloseDevice then begin
      CloseWhenReady := False; PostMessage(Parent.Handle,WM_CLOSE,0,0);
    end;
    Exit;
  end;
  if (Dirty or CutoffDirty) and (timeGetTime-LastEdit>=100) then Flush;
  if not (Dirty or CutoffDirty) and (timeGetTime-LastRead>=500) then ReadValues;
end;
end.
