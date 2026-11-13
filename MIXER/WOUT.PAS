unit Wout;

interface

uses
  WinTypes, WinProcs, Messages, SysUtils, Classes, Graphics, Controls,
  Forms, Dialogs, MMSystem, StdCtrls, Spin, ExtCtrls, MixVol, MxTypes,MxLoad,MxPanel;

type
  TDeviceInfo=class(TObject)
    DeviceID: Word;
  end;

  TForm1 = class(TForm)
    Button1: TButton;
    Edit1: TEdit;
    Edit2: TEdit;
    Memo1: TMemo;
    ScrollBar1: TScrollBar;
    SpinEdit1: TSpinEdit;
    ScrollBar2: TScrollBar;
    ScrollBar3: TScrollBar;
    procedure Button1Click(Sender: TObject);
    procedure ScrollBar1Change(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure ScrollBar2Change(Sender: TObject);
    procedure ScrollBar3Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    ModeBox, DeviceBox: TComboBox;
    PollTimer: TTimer;
    VolumeLabels: array[0..2] of TLabel;
    Updating, Writing, Closing, CanVolume, Independent, VolumeReady: Boolean;
    CurrentVolume, LastChange: LongInt;
    PreferredID: array[0..2] of LongInt;
    Advanced: TMxPanel;
    CurrentMode: Integer;
    function SelectedDevice(var ID: Word): Boolean;
    function GetVolume(var Volume: LongInt): Word;
    function SetVolume(Volume: LongInt): Word;
    function ErrorText(Code: Word): string;
    procedure FreeDeviceList;
    procedure EnumerateDevices;
    procedure ShowSelectedDevice;
    procedure ReadVolume;
    procedure DisplayVolume;
    procedure EnableVolumes(Enable: Boolean);
    procedure WriteVolume(LeftLevel,RightLevel: Word);
    procedure AddFormats(const RateText: string; Mask,Formats: LongInt);
    procedure ModeChange(Sender: TObject);
    procedure DeviceChange(Sender: TObject);
    procedure PollVolume(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  end;

var
  Form1: TForm1;

implementation

{$R *.DFM}
{$R-}
{$Q-}

function TForm1.SelectedDevice(var ID: Word): Boolean;
var I: Integer;
    D: TDeviceInfo;
begin
  Result := False;
  if DeviceBox=nil then Exit;
  I := DeviceBox.ItemIndex;
  if (I<0) or (I>=DeviceBox.Items.Count) then Exit;
  D := TDeviceInfo(DeviceBox.Items.Objects[I]);
  if D=nil then Exit;
  ID := D.DeviceID; Result := True;
end;

function TForm1.GetVolume(var Volume: LongInt): Word;
var ID: Word;
begin
  Result := MMSYSERR_BADDEVICEID;
  if not SelectedDevice(ID) then Exit;
  if ModeBox.ItemIndex=1 then Result := auxGetVolume(ID,@Volume)
  else Result := waveOutGetVolume(ID,@Volume);
end;

function TForm1.SetVolume(Volume: LongInt): Word;
var ID: Word;
begin
  Result := MMSYSERR_BADDEVICEID;
  if not SelectedDevice(ID) then Exit;
  if ModeBox.ItemIndex=1 then Result := auxSetVolume(ID,Volume)
  else Result := waveOutSetVolume(ID,Volume);
end;

function TForm1.ErrorText(Code: Word): string;
var B: array[0..255] of Char;
begin
  if waveOutGetErrorText(Code,B,SizeOf(B))=0 then Result := StrPas(B)
  else Result := 'Multimedia error '+IntToStr(Code);
end;

procedure TForm1.EnableVolumes(Enable: Boolean);
begin
  ScrollBar1.Enabled := Enable and Independent;
  ScrollBar2.Enabled := Enable and Independent;
  ScrollBar3.Enabled := Enable;
end;

procedure TForm1.FreeDeviceList;
var I: Integer;
begin
  for I:=0 to DeviceBox.Items.Count-1 do DeviceBox.Items.Objects[I].Free;
  DeviceBox.Items.Clear;
end;

procedure TForm1.EnumerateDevices;
var ID,N: Word;
    I,Choice,Mode: Integer;
    Err: Word;
    Name,Kind: string;
    D: TDeviceInfo;
    W: TWaveOutCaps;
    A: TAuxCaps;
    M: TMxCaps;
begin
  if Updating or Writing or Closing then Exit;
  Updating := True;
  try
    Mode := ModeBox.ItemIndex;
    FreeDeviceList;
    Choice := -1;
    if Mode=2 then begin N := mixerGetNumDevs; Kind := 'Mixer'; end
    else if Mode=1 then begin N := auxGetNumDevs; Kind := 'AUX'; end
    else begin N := waveOutGetNumDevs; Kind := 'Wave'; end;
    ID := 0;
    while ID<N do begin
      if Mode=2 then begin
        FillChar(M,SizeOf(M),0); Err := mixerGetDevCaps(ID,@M,SizeOf(M));
        M.Name[31] := #0; Name := StrPas(M.Name);
      end else if Mode=1 then begin
        FillChar(A,SizeOf(A),0);
        Err := auxGetDevCaps(ID,@A,SizeOf(A));
        A.szPname[31] := #0; Name := StrPas(A.szPname);
      end else begin
        FillChar(W,SizeOf(W),0);
        Err := waveOutGetDevCaps(ID,@W,SizeOf(W));
        W.szPname[31] := #0; Name := StrPas(W.szPname);
      end;
      if Err=0 then begin
        if Name='' then Name := Kind+' device';
        D := TDeviceInfo.Create; D.DeviceID := ID;
        try
          I := DeviceBox.Items.AddObject(Name+' ['+IntToStr(ID)+']',D);
        except
          D.Free; raise;
        end;
        if LongInt(ID)=PreferredID[Mode] then Choice := I;
      end;
      Inc(ID);
    end;
    if (Choice<0) and (DeviceBox.Items.Count<>0) then Choice := 0;
    DeviceBox.ItemIndex := Choice;
    DeviceBox.Enabled := DeviceBox.Items.Count<>0;
    Edit1.Text := Kind+' devices: '+IntToStr(N)+
                  '   Listed: '+IntToStr(DeviceBox.Items.Count);
  finally
    Updating := False;
  end;
  ShowSelectedDevice;
end;

procedure TForm1.AddFormats(const RateText: string; Mask,Formats: LongInt);
begin
  if (Formats and Mask)<>0 then Memo1.Lines.Add(RateText+', mono, 8-bit');
  if (Formats and (Mask shl 1))<>0 then Memo1.Lines.Add(RateText+', stereo, 8-bit');
  if (Formats and (Mask shl 2))<>0 then Memo1.Lines.Add(RateText+', mono, 16-bit');
  if (Formats and (Mask shl 3))<>0 then Memo1.Lines.Add(RateText+', stereo, 16-bit');
end;

procedure TForm1.ShowSelectedDevice;
var ID,Err,Version: Word;
    W: TWaveOutCaps;
    A: TAuxCaps;
    Name: string;
begin
  CanVolume := False; Independent := False; VolumeReady := False;
  EnableVolumes(False);
  Advanced.Visible := ModeBox.ItemIndex=2;
  Memo1.Visible := ModeBox.ItemIndex<>2;
  ScrollBar1.Visible := ModeBox.ItemIndex<>2;
  ScrollBar2.Visible := ModeBox.ItemIndex<>2;
  ScrollBar3.Visible := ModeBox.ItemIndex<>2;
  Edit2.Visible := ModeBox.ItemIndex<>2;
  if Advanced.Visible then Advanced.BringToFront;
  Memo1.Lines.Clear;
  if not SelectedDevice(ID) then begin
    if ModeBox.ItemIndex=2 then Advanced.CloseDevice;
    Edit2.Text := 'No usable device in this category.';
    if ModeBox.ItemIndex=2 then Edit1.Text := Edit1.Text+'; no usable device.';
    Exit;
  end;
  PreferredID[ModeBox.ItemIndex] := ID;
  if ModeBox.ItemIndex=2 then begin
    if not Advanced.SelectDevice(ID) then
      Edit1.Text := 'Extended mixer could not open this device.';
    Exit;
  end;
  Err := MMSYSERR_ERROR;
  if ModeBox.ItemIndex=1 then begin
    FillChar(A,SizeOf(A),0);
    Err := auxGetDevCaps(ID,@A,SizeOf(A));
    if Err=0 then begin
      A.szPname[31] := #0; Name := StrPas(A.szPname); Version := A.vDriverVersion;
      CanVolume := (A.dwSupport and AUXCAPS_VOLUME)<>0;
      Independent := (A.dwSupport and AUXCAPS_LRVOLUME)<>0;
      Memo1.Lines.Add('AUX: '+Name);
      if A.wTechnology=AUXCAPS_CDAUDIO then Memo1.Lines.Add('CD audio')
      else if A.wTechnology=AUXCAPS_AUXIN then Memo1.Lines.Add('Auxiliary audio');
      Memo1.Lines.Add('No Wave playback formats apply to AUX devices.');
    end;
  end else begin
    FillChar(W,SizeOf(W),0);
    Err := waveOutGetDevCaps(ID,@W,SizeOf(W));
    if Err=0 then begin
      W.szPname[31] := #0; Name := StrPas(W.szPname); Version := W.vDriverVersion;
      CanVolume := (W.dwSupport and WAVECAPS_VOLUME)<>0;
      Independent := (W.dwSupport and WAVECAPS_LRVOLUME)<>0;
      Memo1.Lines.Add('Wave: '+Name);
      if W.wChannels=1 then Memo1.Lines.Add('Mono')
      else if W.wChannels=2 then Memo1.Lines.Add('Stereo');
      if (W.dwSupport and WAVECAPS_PITCH)<>0 then Memo1.Lines.Add('Pitch adjustment');
      if (W.dwSupport and WAVECAPS_PLAYBACKRATE)<>0 then
        Memo1.Lines.Add('Playback rate control');
      if (W.dwSupport and WAVECAPS_SYNC)<>0 then Memo1.Lines.Add('Synchronous driver');
      if (W.dwSupport and $20)<>0 then Memo1.Lines.Add('Sample-accurate driver');
      Memo1.Lines.Add('Advertised format flags: $'+IntToHex(W.dwFormats,8));
      AddFormats('11.025 kHz',1,W.dwFormats);
      AddFormats('22.05 kHz',$10,W.dwFormats);
      AddFormats('44.1 kHz',$100,W.dwFormats);
      AddFormats('48 kHz',$1000,W.dwFormats);
      AddFormats('96 kHz',$10000,W.dwFormats);
      AddFormats('Extended rate',$100000,W.dwFormats);
      AddFormats('Extended rate',$1000000,W.dwFormats);
    end;
  end;
  if Err<>0 then begin Edit2.Text := ErrorText(Err); Exit; end;
  Memo1.Lines.Add('Driver version: '+IntToStr(Hi(Version))+'.'+IntToStr(Lo(Version)));
  if CanVolume then begin
    Memo1.Lines.Add('Volume control supported');
    if Independent then Memo1.Lines.Add('Independent left/right levels')
    else Memo1.Lines.Add('Linked channels: use the Both slider.');
    LastChange := timeGetTime-1000;
    ReadVolume;
  end else Edit2.Text := 'This device does not advertise volume control.';
end;

procedure TForm1.DisplayVolume;
var L,R: Word;
begin
  L := MixLeft(CurrentVolume); R := MixRight(CurrentVolume);
  Updating := True;
  try
    ScrollBar1.Position := MixPosition(L);
    ScrollBar2.Position := MixPosition(R);
    ScrollBar3.Position := MixPosition(Word((LongInt(L)+LongInt(R)) div 2));
    VolumeLabels[0].Caption := IntToStr(MixPercent(L))+'%';
    VolumeLabels[1].Caption := IntToStr(MixPercent(R))+'%';
    if L=R then VolumeLabels[2].Caption := IntToStr(MixPercent(L))+'%'
    else VolumeLabels[2].Caption := 'L/R';
    Edit2.Text := 'Left: '+IntToStr(L)+'   Right: '+IntToStr(R)+
                  '   Packed volume: $'+IntToHex(CurrentVolume,8);
  finally
    Updating := False;
  end;
end;

procedure TForm1.ReadVolume;
var V: LongInt;
    Err: Word;
begin
  if Updating or Writing or Closing or not CanVolume then Exit;
  V := 0; Err := GetVolume(V);
  if Err<>0 then begin
    VolumeReady := False; EnableVolumes(False);
    Edit2.Text := ErrorText(Err); Exit;
  end;
  if not Independent then V := MixPack(MixLeft(V),MixLeft(V));
  CurrentVolume := V; VolumeReady := True;
  DisplayVolume; EnableVolumes(True);
end;

procedure TForm1.WriteVolume(LeftLevel,RightLevel: Word);
var V: LongInt;
    Err: Word;
begin
  if Updating or Writing or Closing or not CanVolume or not VolumeReady then Exit;
  if not Independent then RightLevel := LeftLevel;
  V := MixPack(LeftLevel,RightLevel);
  Writing := True;
  try
    Err := SetVolume(V);
    LastChange := timeGetTime;
  finally
    Writing := False;
  end;
  if Err<>0 then begin Edit2.Text := ErrorText(Err); ReadVolume; Exit; end;
  CurrentVolume := V; DisplayVolume;
  ReadVolume;
end;

procedure TForm1.ScrollBar1Change(Sender: TObject);
begin
  if Updating or not Independent then Exit;
  WriteVolume(MixLevel(ScrollBar1.Position),MixRight(CurrentVolume));
end;

procedure TForm1.ScrollBar2Change(Sender: TObject);
begin
  if Updating or not Independent then Exit;
  WriteVolume(MixLeft(CurrentVolume),MixLevel(ScrollBar2.Position));
end;

procedure TForm1.ScrollBar3Change(Sender: TObject);
var V: Word;
begin
  if Updating then Exit;
  V := MixLevel(ScrollBar3.Position); WriteVolume(V,V);
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  EnumerateDevices;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  WriteVolume(0,0);
end;

procedure TForm1.ModeChange(Sender: TObject);
begin
  if Updating then Exit;
  if (CurrentMode=2) and not Advanced.CloseDevice then begin
    Updating := True; ModeBox.ItemIndex := 2; Updating := False; Exit;
  end;
  CurrentMode := ModeBox.ItemIndex;
  EnumerateDevices;
end;

procedure TForm1.DeviceChange(Sender: TObject);
begin
  if (ModeBox.ItemIndex=2) and not Advanced.CanLeave then Exit;
  if not Updating and not Writing and not Closing then ShowSelectedDevice;
end;

procedure TForm1.PollVolume(Sender: TObject);
begin
  if timeGetTime-LastChange<750 then Exit;
  ReadVolume;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Closing := True;
  if PollTimer<>nil then PollTimer.Enabled := False;
  if DeviceBox<>nil then FreeDeviceList;
  Advanced.Free; Advanced := nil;
  MxFreeAPI;
end;

procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := True;
  if Advanced<>nil then CanClose := Advanced.RequestClose;
end;

procedure TForm1.FormCreate(Sender: TObject);
var L: TLabel;
    I: Integer;
begin
  Updating := True; Writing := False; Closing := False;
  CanVolume := False; Independent := False; VolumeReady := False;
  CurrentVolume := 0; LastChange := timeGetTime-1000;
  PreferredID[0] := -1; PreferredID[1] := -1; PreferredID[2] := -1;
  CurrentMode := 0;
  OnDestroy := FormDestroy;
  OnCloseQuery := FormCloseQuery;
  Caption := 'Audio Mixer 1.4';
  BorderStyle := bsSingle;
  ClientWidth := 600; ClientHeight := 400;
  if Width<=Screen.Width then Left := (Screen.Width-Width) div 2;
  if Height<=Screen.Height then Top := (Screen.Height-Height) div 2;

  { Keep the compiler-tested original binary DFM, replacing its obsolete
    numeric selector with runtime-created standard Delphi 1 combo boxes. }
  SpinEdit1.Free; SpinEdit1 := nil;
  L := TLabel.Create(Self); L.Parent := Self;
  L.SetBounds(8,12,40,16); L.Caption := 'Type:';
  ModeBox := TComboBox.Create(Self); ModeBox.Parent := Self;
  ModeBox.Style := csDropDownList; ModeBox.SetBounds(52,8,100,24);
  ModeBox.Items.Add('Wave'); ModeBox.Items.Add('AUX');
  if MxLoadAPI then ModeBox.Items.Add('Mixer');
  ModeBox.ItemIndex := 0; ModeBox.OnChange := ModeChange; ModeBox.TabOrder := 0;
  DeviceBox := TComboBox.Create(Self); DeviceBox.Parent := Self;
  DeviceBox.Style := csDropDownList; DeviceBox.SetBounds(164,8,428,24);
  DeviceBox.OnChange := DeviceChange; DeviceBox.TabOrder := 1;
  Button1.SetBounds(8,44,90,26); Button1.Caption := 'Refresh'; Button1.TabOrder := 2;
  Edit1.SetBounds(108,44,484,24); Edit1.ReadOnly := True; Edit1.TabStop := False;
  Memo1.SetBounds(8,80,405,280); Memo1.ReadOnly := True;
  Memo1.ScrollBars := ssVertical; Memo1.WordWrap := False;
  ScrollBar1.SetBounds(436,108,17,232);
  ScrollBar2.SetBounds(493,108,17,232);
  ScrollBar3.SetBounds(550,108,17,232);
  ScrollBar1.Min := 0; ScrollBar1.Max := 100;
  ScrollBar2.Min := 0; ScrollBar2.Max := 100;
  ScrollBar3.Min := 0; ScrollBar3.Max := 100;
  ScrollBar1.SmallChange := 1; ScrollBar1.LargeChange := 5;
  ScrollBar2.SmallChange := 1; ScrollBar2.LargeChange := 5;
  ScrollBar3.SmallChange := 1; ScrollBar3.LargeChange := 5;
  for I:=0 to 2 do begin
    L := TLabel.Create(Self); L.Parent := Self;
    L.SetBounds(422+I*57,82,46,16); L.Alignment := taCenter;
    case I of
      0: L.Caption := 'Left';
      1: L.Caption := 'Right';
      2: L.Caption := 'Both';
    end;
    VolumeLabels[I] := TLabel.Create(Self); VolumeLabels[I].Parent := Self;
    VolumeLabels[I].SetBounds(422+I*57,346,46,16);
    VolumeLabels[I].Alignment := taCenter; VolumeLabels[I].Caption := '-';
  end;
  Edit2.SetBounds(8,370,584,24); Edit2.ReadOnly := True; Edit2.TabStop := False;
  Advanced := TMxPanel.Create(Self); Advanced.Parent := Self;
  Advanced.SetBounds(8,80,584,310); Advanced.Visible := False;
  PollTimer := TTimer.Create(Self); PollTimer.Enabled := False;
  PollTimer.Interval := 500; PollTimer.OnTimer := PollVolume;
  Updating := False;
  EnableVolumes(False); EnumerateDevices;
  PollTimer.Enabled := True;
end;

end.
