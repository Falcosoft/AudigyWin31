{ Task-only mixer facade. No hardware port access, new timer or memory owner.
  Standard Win16 MXDM messages with stable control IDs. }
function MxSourceName(N: Word): string;
begin
  case N of
    0: Result := 'Line-In'; 1: Result := 'Microphone';
    2: Result := 'CD analog'; 3: Result := 'Aux';
    4: Result := 'CD Digital'; 5: Result := 'AudigyDrive S/PDIF';
  else Result := 'Wave';
  end;
end;

function MxCount(LineID: LongInt): Word;
begin
  Result := 0;
  if LineID=1 then Result := MxControlCount-3;
  if LineID=2 then Result := 3;
end;

function MxControlLine(ID: Word): LongInt;
begin
  Result := 1;
  if (ID=2) or (ID=3) or (ID=7) then Result := 2;
end;

procedure MxDescribe(ID: Word; var C: TMxControl);
begin
  FillChar(C,SizeOf(C),0); C.Size := SizeOf(C); C.ID := ID;
  C.Kind := MX_FADER; C.Flags := MX_UNIFORM;
  C.Maximum := 65535; C.Steps := 101;
  case ID of
    1,15,MxFMVolume: begin
      C.Kind := MX_VOLUME; C.Flags := 0; C.Steps := 65536;
      if ID=1 then StrPCopy(C.Name,'Playback 1 volume')
      else if ID=15 then StrPCopy(C.Name,'Playback 2 volume')
      else StrPCopy(C.Name,'FM Synth volume');
    end;
    2: StrPCopy(C.Name,'Recording level');
    3: begin C.Kind := MX_MUX; C.Items := 7; StrPCopy(C.Name,'Recording source'); end;
    4: begin C.Kind := MX_VOLUME; StrPCopy(C.Name,'Monitor level'); end;
    5: begin C.Kind := MX_ONOFF; StrPCopy(C.Name,'Monitor enabled'); end;
    6: begin C.Kind := MX_SINGLE; C.Items := 6; StrPCopy(C.Name,'Monitor source'); end;
    7: StrPCopy(C.Name,'Analog source level');
    8: StrPCopy(C.Name,'Playback 1 Front/Rear');
    16: StrPCopy(C.Name,'Playback 2 Front/Rear');
    MxFMFader: StrPCopy(C.Name,'FM Synth Front/Rear');
    9: begin C.Kind := MX_ONOFF; StrPCopy(C.Name,'Equalizer enabled'); end;
    10: begin C.Steps := 25; StrPCopy(C.Name,'Equalizer preamp'); end;
    11: begin
      C.Kind := MX_EQUALIZER; C.Items := 10; C.Steps := 25;
      StrPCopy(C.Name,'Ten-band equalizer');
    end;
    12: begin C.Kind := MX_ONOFF; StrPCopy(C.Name,'Reverb enabled'); end;
    13: StrPCopy(C.Name,'Reverb level');
    14: begin C.Kind := MX_SINGLE; C.Items := 4; StrPCopy(C.Name,'Reverb preset'); end;
    MxBassRedirect: begin
      C.Kind := MX_ONOFF; StrPCopy(C.Name,'Bass Redirect');
    end;
    MxBassCutoff: begin
      C.Steps := AudBassSteps+1; StrPCopy(C.Name,'Bass Redirect Cutoff');
    end;
  end;
  if C.Items<>0 then C.Flags := C.Flags or MX_MULTIPLE;
  if (C.Kind=MX_ONOFF) or (C.Kind=MX_SINGLE) or (C.Kind=MX_MUX) then begin
    C.Maximum := 1; C.Steps := 2;
  end;
  Move(C.Name,C.ShortName,15); C.ShortName[15] := #0;
end;

function MxScale(Value,Maximum: LongInt): LongInt;
begin
  Result := (Value*65535+Maximum div 2) div Maximum;
end;

procedure MxValues(ID: Word; var V: TMxValues);
var I: Word;
    C: TAudSettings;
    SavedBusy: Boolean;
begin
  FillChar(V,SizeOf(V),0);
  SavedBusy := Busy; Busy := True;
  C := ActiveSettings;
  if MxOwnsConfig and ConfigPending then C := RequestedSettings;
  Busy := SavedBusy;
  case ID of
    1: begin V[0] := LoWord(Volume[0]); V[1] := HiWord(Volume[0]); end;
    15: begin V[0] := LoWord(Volume[1]); V[1] := HiWord(Volume[1]); end;
    MxFMVolume: begin V[0] := LoWord(Volume[2]); V[1] := HiWord(Volume[2]); end;
    MxFMFader: V[0] := MxScale(FMFader,100);
    2: V[0] := MxScale(C.InputLevel,100);
    3: V[C.Source] := 1;
    4: V[0] := C.MonitorVolume;
    5: V[0] := C.MonitorOn;
    6: if C.Source<6 then V[C.Source] := 1;
    7: V[0] := MxScale(C.SourceLevel,100);
    8: V[0] := MxScale(C.Fader1,100);
    16: V[0] := MxScale(C.Fader2,100);
    9: V[0] := C.EQ.Enabled;
    10: V[0] := MxScale(LongInt(C.EQ.Preamp)+24,24);
    11: for I:=0 to 9 do V[I] := MxScale(LongInt(C.EQ.Band[I])+12,24);
    12: V[0] := C.Rev.Enabled;
    13: V[0] := MxScale(C.Rev.Level,100);
    14: V[C.Rev.Preset] := 1;
    MxBassRedirect: V[0] := C.BassOn;
    MxBassCutoff: V[0] := MxScale((C.BassHz-AudBassMinHz) div AudBassStepHz,
                                AudBassSteps);
  end;
end;

procedure MxNotify;
var ID,I,J,N: Word;
    V: TMxValues;
    Bit: LongInt;
    Changed,OK: Boolean;
    ClientCopy: TMxClient;
begin
  { Never call the manager's callback from a multimedia interrupt/MMTASK.
    Ordinary mixer requests and Control Panel polling service notifications. }
  if Busy or TimerActive or MxNotifying or DriverExiting then Exit;
  MxNotifying := True;
  for ID:=1 to MxControlCount do begin
    MxValues(ID,V); Changed := False;
    for J:=0 to 9 do if V[J]<>MxSeen[ID,J] then Changed := True;
    MxSeen[ID] := V;
    if Changed and MxObserved then begin
      Bit := LongInt(1) shl (ID-1);
      for I:=0 to 7 do if MxClients[I].Cookie<>0 then
        MxClients[I].Pending := MxClients[I].Pending or Bit;
    end;
  end;
  MxObserved := True;
  for I:=0 to 7 do if MxClients[I].Cookie<>0 then begin
    { At most one coalesced control notice per client per task entry. }
    ID := 1; Bit := 1; N := 0;
    while (ID<=MxControlCount) and ((MxClients[I].Pending and Bit)=0) do begin
      Inc(ID); Bit := Bit shl 1;
    end;
    if (ID<=MxControlCount) and (MxClients[I].Desc.Callback<>0) then begin
      ClientCopy := MxClients[I];
      MxClients[I].Pending := MxClients[I].Pending and not Bit;
      with ClientCopy do OK := DriverCallback(Desc.Callback,HiWord(Flags) or 8,
        Desc.Handle,MX_CONTROL_CHANGE,Desc.Instance,ID,0);
    end;
  end;
  MxNotifying := False;
end;

procedure MxMaintain;
var A,S: TAudSettings;
    Status: Word;
begin
  if Busy or TimerActive or ConfigSaving or MonitorSaving then Exit;
  if (VolumeDirty[2] or FMFaderDirty) and (MidiCookie=0) and
     not AnyOutputActive and not InputOpened then SaveVolume;
  if MxOwnsConfig and not ConfigPending and (timeGetTime-MxSaveTick>=500) then begin
    Status := ConfigPoll(A,S);
    if Status<>0 then MxOwnsConfig := False;
  end;
  MxNotify;
end;

function MxLineInfo(P: PMxLine; Flags: LongInt): LongInt;
var L: TMxLine;
    ID,Dest,Source: LongInt;
    I: Word;
begin
  Result := MMSYSERR_INVALPARAM;
  if (P=nil) or IsBadWritePtr(P,SizeOf(L)) then Exit;
  if P^.Size<SizeOf(L) then Exit;
  ID := 0; Dest := P^.Destination; Source := P^.Source;
  case Word(Flags and 15) of
    0: if (Dest>=0) and (Dest<2) then ID := Dest+1;
    1: if (Dest>=0) and (Dest<2) and (Source>=0) and (Source<7) then
         ID := 100+Dest*16+Source;
    2: ID := P^.ID;
    3: begin
      if P^.Component=4 then ID := 1;
      if P^.Component=7 then ID := 2;
    end;
    4: Exit; { No ambiguous Wave/AUX device-ID association is guessed. }
  else Exit;
  end;
  FillChar(L,SizeOf(L),0); L.Size := SizeOf(L); L.ID := ID;
  L.Channels := 2; L.Flags := 1;
  if (ID=1) or (ID=2) then begin
    L.Destination := ID-1; L.Connections := 7; L.Controls := MxCount(ID);
    L.Component := 4;
    if ID=1 then StrPCopy(L.Name,'Playback and input monitoring')
    else begin L.Component := 7; StrPCopy(L.Name,'Recording'); end;
  end else begin
    if (ID>=100) and (ID<=106) then begin Dest := 0; Source := ID-100; end
    else if (ID>=116) and (ID<=122) then begin Dest := 1; Source := ID-116; end
    else begin Result := 1024; Exit; end;
    L.Destination := Dest; L.Source := Source; L.Flags := LongInt($80000001);
    I := Word(Source);
    if Dest=0 then begin if I=0 then I := 6 else Dec(I); end;
    L.Component := $1002; { generic line input }
    if I=1 then L.Component := $1003;
    if I=2 then L.Component := $1005;
    if I=6 then L.Component := $1008;
    StrPCopy(L.Name,MxSourceName(I));
  end;
  Move(L.Name,L.ShortName,15); L.ShortName[15] := #0;
  P^ := L; Result := 0;
end;

function MxLineControls(P: PMxLineControls; Flags: LongInt): LongInt;
const ControlOrder: array[1..MxControlCount] of Word =
        (1,15,8,16,MxFMVolume,MxFMFader,2,3,4,5,6,7,9,10,11,12,13,14,
         MxBassRedirect,MxBassCutoff);
var C: TMxControl;
    I,J,N,Want: Word;
    Q: PMxControl;
begin
  Result := MMSYSERR_INVALPARAM;
  if (P=nil) or IsBadReadPtr(P,SizeOf(P^)) then Exit;
  if (P^.Size<SizeOf(P^)) or (P^.ControlSize<SizeOf(C)) then Exit;
  if (Flags and 15)>2 then Exit;
  if (P^.Count<1) or (P^.Count>MxControlCount) then Exit;
  if P^.ControlSize>65535 div P^.Count then Exit;
  if IsBadWritePtr(P^.Data,Word(P^.Count*P^.ControlSize)) then Exit;
  Want := Word(P^.Count); N := 0;
  if (Flags and 15)<>0 then if Want<>1 then Exit;
  for J:=1 to MxControlCount do begin
    I := ControlOrder[J]; { display order is independent of stable control IDs }
    MxDescribe(I,C);
    if (((Flags and 15)=1) and (C.ID=P^.Control)) or
       ((MxControlLine(I)=P^.LineID) and (((Flags and 15)=0) or
        (((Flags and 15)=2) and (C.Kind=P^.Control)))) then begin
      if N>=Want then Exit;
      Q := DataPointer(P^.Data,LongInt(N)*P^.ControlSize); Q^ := C; Inc(N);
      if (Flags and 15)<>0 then Break;
    end;
  end;
  if N=Want then Result := 0 else Result := 1025;
end;

function MxSet(ID: Word; const V: TMxValues): LongInt;
var C: TAudSettings;
    I,N,Choice: Word;
    Status: Word;
begin
  Result := MMSYSERR_ALLOCATED;
  if Busy or TimerActive or ConfigPending or ConfigSaving or MonitorSaving then Exit;
  if ConfigNeedsSave and not MxOwnsConfig then Exit;
  if (ID=1) or (ID=15) or (ID=MxFMVolume) then begin
    Busy := True;
    I := 0;
    if ID=15 then I := 1 else if ID=MxFMVolume then I := 2;
    CachePlaybackVolume(I,V[0] or (V[1] shl 16));
    Busy := False;
    Result := 0; Exit;
  end;
  if ID=MxFMFader then begin
    Busy := True;
    FMFader := Word((V[0]*100+32767) div 65535);
    FMFaderDirty := True; VolumePending[2] := True;
    Busy := False; Result := 0; Exit;
  end;
  Busy := True; C := ActiveSettings; Busy := False;
  { Preserve restart-only edits already saved through the configuration dialog. }
  C.PhysicalBase := SavedSettings.PhysicalBase; C.CardIndex := SavedSettings.CardIndex;
  C.HalfMS := SavedSettings.HalfMS; C.SliceMS := SavedSettings.SliceMS;
  C.TimerMS := SavedSettings.TimerMS; C.ResolutionMS := SavedSettings.ResolutionMS;
  C.GainSteps := SavedSettings.GainSteps; { startup-only Aud2Gain must survive edits }
  C.MidiSynth := SavedSettings.MidiSynth; C.Playback2Aux := SavedSettings.Playback2Aux;
  C.MidiRate := SavedSettings.MidiRate;
  C.SoundFont := SavedSettings.SoundFont; C.SoundFontVoices := SavedSettings.SoundFontVoices;
  C.SoundFontHeadroomDB := SavedSettings.SoundFontHeadroomDB;
  Choice := 0; N := 0;
  if (ID=3) or (ID=6) or (ID=14) then begin
    N := 7; if ID=6 then N := 6;
    if ID=14 then N := 4;
    Choice := $FFFF;
    for I:=0 to N-1 do if V[I]<>0 then begin
      if Choice<>$FFFF then begin Result := 1026; Exit; end; Choice := I;
    end;
    if Choice=$FFFF then begin Result := 1026; Exit; end;
  end;
  case ID of
    2: C.InputLevel := Word((V[0]*100+32767) div 65535);
    3: begin C.Source := Choice; if Choice=6 then C.MonitorOn := 0; end;
    4: C.MonitorVolume := Word(V[0]);
    5: begin
      if (C.Source=6) and (V[0]<>0) then begin Result := 1026; Exit; end;
      C.MonitorOn := Word(V[0]);
    end;
    6: begin C.Source := Choice; C.MonitorSource := Choice; end;
    7: C.SourceLevel := Word((V[0]*100+32767) div 65535);
    8: C.Fader1 := Word((V[0]*100+32767) div 65535);
    16: C.Fader2 := Word((V[0]*100+32767) div 65535);
    9: C.EQ.Enabled := Word(V[0]);
    10: C.EQ.Preamp := Integer((V[0]*24+32767) div 65535)-24;
    11: for I:=0 to 9 do C.EQ.Band[I] := Integer((V[I]*24+32767) div 65535)-12;
    12: C.Rev.Enabled := Word(V[0]);
    13: C.Rev.Level := Word((V[0]*100+32767) div 65535);
    14: C.Rev.Preset := Choice;
    MxBassRedirect: C.BassOn := Word(V[0]);
    MxBassCutoff: C.BassHz := AudBassMinHz+
      Word((V[0]*AudBassSteps+32767) div 65535)*AudBassStepHz;
  else Result := 1025; Exit;
  end;
  Status := ConfigSubmit(C);
  if Status=0 then begin MxOwnsConfig := True; MxSaveTick := timeGetTime; Result := 0; end
  else if Status<>1 then Result := MMSYSERR_NOTENABLED;
end;

function MxDetails(P: PMxDetails; Flags: LongInt; Setting: Boolean): LongInt;
var C: TMxControl;
    V: TMxValues;
    L: TMxListText;
    N,I,ID: Word;
    Q: PLongValue;
    Hz: LongInt;
begin
  Result := MMSYSERR_INVALPARAM;
  if (P=nil) or IsBadReadPtr(P,SizeOf(P^)) then Exit;
  if (P^.Size<SizeOf(P^)) or (P^.ControlID<1) or
     (P^.ControlID>MxControlCount) then Exit;
  ID := Word(P^.ControlID); MxDescribe(ID,C);
  if ((Flags and 15)=1) and not Setting then begin
    if (C.Items=0) or (P^.Items<>C.Items) or (P^.DetailSize<SizeOf(L)) then Exit;
    if P^.DetailSize>65535 div C.Items then Exit;
    if IsBadWritePtr(P^.Data,Word(P^.DetailSize*C.Items)) then Exit;
    for I:=0 to Word(C.Items)-1 do begin
      FillChar(L,SizeOf(L),0);
      if (ID=3) or (ID=6) then begin
        if ID=3 then L.Param1 := 116+I;
        StrPCopy(L.Name,MxSourceName(I));
      end;
      if ID=11 then begin
        Hz := ((LongInt(125) shl I)+2) div 4;
        StrPCopy(L.Name,IntToStr(Hz)+' Hz');
      end;
      if ID=14 then case I of
        0: StrPCopy(L.Name,'Room'); 1: StrPCopy(L.Name,'Hall');
        2: StrPCopy(L.Name,'Plate'); 3: StrPCopy(L.Name,'Chamber');
      end;
      PMxListText(DataPointer(P^.Data,LongInt(I)*P^.DetailSize))^ := L;
    end;
    Result := 0; Exit;
  end;
  if (Flags and 15)<>0 then Exit;
  N := 1;
  if (ID=1) or (ID=15) or (ID=MxFMVolume) then begin
    if (P^.Channels<>1) and (P^.Channels<>2) then Exit;
    N := Word(P^.Channels);
  end else if P^.Channels<>1 then Exit;
  if C.Items<>0 then begin if P^.Items<>C.Items then Exit; N := Word(C.Items); end
  else if P^.Items<>0 then Exit;
  if (P^.DetailSize<4) or (P^.DetailSize>65535 div N) then Exit;
  if Setting then begin
    if IsBadReadPtr(P^.Data,Word(P^.DetailSize*N)) then Exit;
    FillChar(V,SizeOf(V),0);
    for I:=0 to N-1 do begin
      Q := DataPointer(P^.Data,LongInt(I)*P^.DetailSize); V[I] := Q^;
      if (V[I]<0) or (V[I]>C.Maximum) then begin Result := 1026; Exit; end;
    end;
    if ((ID=1) or (ID=15) or (ID=MxFMVolume)) and (N=1) then V[1] := V[0];
    Result := MxSet(ID,V);
  end else begin
    if IsBadWritePtr(P^.Data,Word(P^.DetailSize*N)) then Exit;
    MxValues(ID,V);
    for I:=0 to N-1 do begin
      Q := DataPointer(P^.Data,LongInt(I)*P^.DetailSize); Q^ := V[I];
    end;
    Result := 0;
  end;
end;

function mxdMessage(DeviceID,Message: Word; User,Param1,Param2: LongInt): LongInt;
  export;
var Caps: TMxCaps;
    N,I: Word;
begin
  Result := MMSYSERR_NOTSUPPORTED;
  if Message=100 then begin Result := 0; Exit; end;
  if Message=1 then begin
    Result := 0; if Enabled and AudIsOpen then Result := 1; Exit;
  end;
  Result := MMSYSERR_BADDEVICEID; if DeviceID<>0 then Exit;
  { Closing a manager cookie must remain possible after DRV_DISABLE. }
  if Message=4 then begin
    if Enabled and not DriverExiting and MxOwnsConfig then begin
      if ConfigPending then begin Result := MMSYSERR_ALLOCATED; Exit; end;
      MxSaveTick := timeGetTime-500; MxMaintain;
    end;
    Result := MMSYSERR_INVALHANDLE;
    for I:=0 to 7 do if (User<>0) and (MxClients[I].Cookie=User) then begin
      FillChar(MxClients[I],SizeOf(TMxClient),0); Result := 0; Break;
    end;
    Exit;
  end;
  Result := MMSYSERR_NOTENABLED;
  if not Enabled or not AudIsOpen or DriverExiting then Exit;
  if TimerActive then begin Result := MMSYSERR_ALLOCATED; Exit; end;
  MxMaintain;
  case Message of
    2: begin
      Result := MMSYSERR_INVALPARAM;
      if (Param2<0) or (Param2>65535) then Exit;
      N := SizeOf(Caps); if Param2<N then N := Word(Param2);
      if N=0 then begin Result := 0; Exit; end;
      if (Param1=0) or IsBadWritePtr(Pointer(Param1),N) then Exit;
      FillChar(Caps,SizeOf(Caps),0); Caps.Version := AudDriverVersion;
      StrPCopy(Caps.Name,'Creative Audigy 2/ZS Mixer'); Caps.Destinations := 2;
      Move(Caps,Pointer(Param1)^,N); Result := 0;
    end;
    3: begin
      Result := MMSYSERR_INVALPARAM;
      if (User=0) or IsBadWritePtr(Pointer(User),4) or (Param1=0) then Exit;
      if IsBadReadPtr(Pointer(Param1),SizeOf(TMxOpen)) then Exit;
      Result := MMSYSERR_ALLOCATED;
      for I:=0 to 7 do if MxClients[I].Cookie=0 then begin
        Inc(MxSerial); if MxSerial=0 then Inc(MxSerial);
        MxClients[I].Cookie := MxSerial; MxClients[I].Flags := Param2;
        MxClients[I].Desc := PMxOpen(Param1)^; MxClients[I].Pending := 0;
        PLongValue(User)^ := MxSerial; Result := 0; Break;
      end;
    end;
    5: Result := MxLineInfo(PMxLine(Param1),Param2);
    6: Result := MxLineControls(PMxLineControls(Param1),Param2);
    7: Result := MxDetails(PMxDetails(Param1),Param2,False);
    8: Result := MxDetails(PMxDetails(Param1),Param2,True);
  end;
  MxNotify;
end;
