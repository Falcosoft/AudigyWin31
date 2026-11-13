{ Task-context configuration load/save/requests. Hardware application is
  separate (ApplyConfigIRQ), using the existing resident timer and Busy gate. }

function ConfigReadInputs(var C: TAudSettings): Boolean;
var B: array[0..63] of Char;
    FN: array[0..255] of Char;
    V: LongInt;
    Err: Integer;
begin
  Result := False; StrPCopy(FN,IniName);
  GetPrivateProfileString('AUDIGY1','InputSource','LineIn',B,SizeOf(B),FN);
  if not AudSourceNumber(StrPas(B),C.Source) then Exit;
  C.MonitorSource := C.Source;
  if C.Source=6 then begin
    GetPrivateProfileString('AUDIGY1','MonitorSource','LineIn',B,SizeOf(B),FN);
    if not AudSourceNumber(StrPas(B),C.MonitorSource) then Exit;
    if C.MonitorSource>5 then Exit;
  end;
  GetPrivateProfileString('AUDIGY1','InputLevel','100',B,SizeOf(B),FN);
  Val(StrPas(B),V,Err);
  if (Err<>0) or (V<0) or (V>100) then Exit;
  C.InputLevel := Word(V);
  GetPrivateProfileString('AUDIGY1','InputSourceLevel','50',B,SizeOf(B),FN);
  Val(StrPas(B),V,Err);
  if (Err<>0) or (V<0) or (V>100) then Exit;
  C.SourceLevel := Word(V); Result := True;
end;

procedure LoadEQ(var E: TEqSettings);
var I: Word;
    B: array[0..31] of Char;
    FN: array[0..255] of Char;
    Key: array[0..15] of Char;
    V: Integer;
    Err: Integer;
begin
  FillChar(E,SizeOf(E),0); StrPCopy(FN,IniName);
  E.Enabled := ConfigNumber('EQEnabled',0,0,1);
  GetPrivateProfileString('AUDIGY1','EQPreamp','0',B,SizeOf(B),FN);
  Val(StrPas(B),V,Err);
  if (Err=0) and (V>= -24) and (V<=0) then E.Preamp := V;
  for I:=0 to EqBands-1 do begin
    StrPCopy(Key,'EQBand'+IntToStr(I+1));
    GetPrivateProfileString('AUDIGY1',Key,'0',B,SizeOf(B),FN);
    Val(StrPas(B),V,Err);
    if (Err=0) and (V>= -12) and (V<=12) then E.Band[I] := V;
  end;
end;

procedure ConfigLoad;
var Base: LongInt;
    Index: Word;
    Path: array[0..255] of Char;
    FN: array[0..255] of Char;
begin
  FillChar(ActiveSettings,SizeOf(ActiveSettings),0);
  Base := $08000000; Index := 0;
  if not ReadConfig(Base,Index) then begin Base := $08000000; Index := 0; end;
  ActiveSettings.PhysicalBase := Base; ActiveSettings.CardIndex := Index;
  ActiveSettings.HalfMS := AudBufferHalfMS; ActiveSettings.SliceMS := AudRefillSliceMS;
  ActiveSettings.TimerMS := AudTimerInterval; ActiveSettings.ResolutionMS := AudClockMargin;
  ActiveSettings.MidiSynth := ConfigNumber('MidiSynth',
    ConfigNumber('OplMidi',SynthOPL3,SynthNone,SynthOPL3),SynthNone,SynthSoundFont);
  ActiveSettings.MidiRate := ConfigNumber('MidiRate',MidiRateDefault,0,65535);
  if ActiveSettings.MidiRate<>MidiRateNative then ActiveSettings.MidiRate := MidiRateDefault;
  ActiveSettings.SoundFontVoices :=
    ConfigNumber('SoundFontVoices',SFDefaultVoices,SFMinVoices,SFMaxVoices);
  ActiveSettings.SoundFontHeadroomDB :=
    ConfigNumber('SoundFontHeadroomDB',SFDefaultHeadroomDB,0,SFMaxHeadroomDB);
  StrPCopy(FN,IniName);
  GetPrivateProfileString('AUDIGY1','SoundFont',DefaultSoundFont,Path,SizeOf(Path),FN);
  ActiveSettings.SoundFont := StrPas(Path);
  if ActiveSettings.SoundFont='' then ActiveSettings.SoundFont := DefaultSoundFont;
  ActiveSettings.Playback2Aux := ConfigNumber('Playback2Aux',0,0,1);
  ActiveSettings.Fader1 := ConfigNumber('FrontRear1',50,0,100);
  ActiveSettings.Fader2 := ConfigNumber('FrontRear2',50,0,100);
  ActiveSettings.DebugMode := Ord(DebugEnabled);
  ActiveSettings.ShutdownMode := Ord(ShutdownWorkaround);
  ActiveSettings.Source := 0; ActiveSettings.InputLevel := 100;
  ActiveSettings.SourceLevel := 50;
  ActiveSettings.MonitorOn := ConfigNumber('MonitorInput',0,0,1);
  ActiveSettings.MonitorVolume := AudMonitorValue(ConfigNumber('MonitorLevel',50,0,100));
  ConfigInputValid := ConfigReadInputs(ActiveSettings);
  if ActiveSettings.Source=6 then ActiveSettings.MonitorOn := 0;
  LoadEQ(ActiveSettings.EQ);
  ActiveSettings.Rev.Enabled := ConfigNumber('ReverbEnabled',0,0,1);
  ActiveSettings.Rev.Preset := ConfigNumber('ReverbPreset',0,0,3);
  ActiveSettings.Rev.Level := ConfigNumber('ReverbLevel',50,0,100);
  ActiveSettings.BassOn := ConfigNumber('BassRedirect',0,0,1);
  ActiveSettings.BassHz := ConfigNumber('BassCutoffHz',AudBassDefaultHz,
                                       AudBassMinHz,AudBassMaxHz);
  ActiveSettings.BassHz := AudBassMinHz+AudBassStepHz*
    ((ActiveSettings.BassHz-AudBassMinHz+AudBassStepHz div 2) div AudBassStepHz);
  SavedSettings := ActiveSettings;
  ConfigPending := False; ConfigNeedsSave := False; ConfigError := 0;
  MonitorPending := True; MonitorDirty := False; MonitorFault := False;
  MonitorSaving := False; ConfigSaving := False;
end;

function ConfigPut(Key: PChar; const Value: string): Boolean;
var FN,B: array[0..255] of Char;
begin
  StrPCopy(FN,IniName); StrPCopy(B,Value);
  Result := WritePrivateProfileString('AUDIGY1',Key,B,FN);
end;

function ConfigSave(const C: TAudSettings): Boolean;
var I: Word;
    Key: array[0..15] of Char;
begin
  { No playback Busy gate across disk I/O. The existing timer may continue
    servicing audio. Preserve all unrelated INI sections and [Volume]. }
  Result := False;
  if not ConfigPut('PhysicalBase','$'+IntToHex(C.PhysicalBase,8)) then Exit;
  if not ConfigPut('CardIndex',IntToStr(C.CardIndex)) then Exit;
  if not ConfigPut('HalfBufferMS',IntToStr(C.HalfMS)) then Exit;
  if not ConfigPut('RefillSliceMS',IntToStr(C.SliceMS)) then Exit;
  if not ConfigPut('TimerIntervalMS',IntToStr(C.TimerMS)) then Exit;
  if not ConfigPut('TimerResolutionMS',IntToStr(C.ResolutionMS)) then Exit;
  if not ConfigPut('MidiRate',IntToStr(C.MidiRate)) then Exit;
  if not ConfigPut('SoundFont',C.SoundFont) then Exit;
  if not ConfigPut('SoundFontVoices',IntToStr(C.SoundFontVoices)) then Exit;
  if not ConfigPut('SoundFontHeadroomDB',IntToStr(C.SoundFontHeadroomDB)) then Exit;
  if not ConfigPut('MidiSynth',IntToStr(C.MidiSynth)) then Exit;
  if not ConfigPut('Playback2Aux',IntToStr(C.Playback2Aux)) then Exit;
  if not ConfigPut('InputSource',AudSourceName(C.Source)) then Exit;
  if not ConfigPut('MonitorSource',AudSourceName(C.MonitorSource)) then Exit;
  if not ConfigPut('InputLevel',IntToStr(C.InputLevel)) then Exit;
  if not ConfigPut('InputSourceLevel',IntToStr(C.SourceLevel)) then Exit;
  if not ConfigPut('FrontRear1',IntToStr(C.Fader1)) then Exit;
  if not ConfigPut('FrontRear2',IntToStr(C.Fader2)) then Exit;
  if not ConfigPut('Debug',IntToStr(C.DebugMode)) then Exit;
  if not ConfigPut('ShutdownWorkaround',IntToStr(C.ShutdownMode)) then Exit;
  if not ConfigPut('MonitorInput',IntToStr(C.MonitorOn)) then Exit;
  if not ConfigPut('MonitorLevel',IntToStr(AudMonitorPercent(C.MonitorVolume))) then Exit;
  if not ConfigPut('EQEnabled',IntToStr(C.EQ.Enabled)) then Exit;
  if not ConfigPut('EQPreamp',IntToStr(C.EQ.Preamp)) then Exit;
  if not ConfigPut('ReverbEnabled',IntToStr(C.Rev.Enabled)) then Exit;
  if not ConfigPut('ReverbPreset',IntToStr(C.Rev.Preset)) then Exit;
  if not ConfigPut('ReverbLevel',IntToStr(C.Rev.Level)) then Exit;
  if not ConfigPut('BassRedirect',IntToStr(C.BassOn)) then Exit;
  if not ConfigPut('BassCutoffHz',IntToStr(C.BassHz)) then Exit;
  for I:=0 to EqBands-1 do begin
    StrPCopy(Key,'EQBand'+IntToStr(I+1));
    if not ConfigPut(Key,IntToStr(C.EQ.Band[I])) then Exit;
  end;
  Result := True;
end;

procedure SaveMonitor;
var C: TAudSettings;
begin
  if not MonitorDirty or MonitorSaving or ConfigSaving or ConfigPending or
     ConfigNeedsSave or TimerActive then Exit;
  { Called on task stacks, with no Busy gate across INI writes. AUX changes
    made during audio are saved later, on an idle AUX call or driver unload. }
  C := ActiveSettings; MonitorSaving := True;
  if ConfigPut('MonitorInput',IntToStr(C.MonitorOn)) and
     ConfigPut('MonitorLevel',IntToStr(AudMonitorPercent(C.MonitorVolume))) then begin
    SavedSettings.MonitorOn := C.MonitorOn;
    SavedSettings.MonitorVolume := C.MonitorVolume;
    if (ActiveSettings.MonitorOn=C.MonitorOn) and
       (ActiveSettings.MonitorVolume=C.MonitorVolume) then MonitorDirty := False;
  end;
  MonitorSaving := False;
end;

function ConfigSubmit(const Settings: TAudSettings): Word;
begin
  Result := 1;
  if Busy or TimerActive or ConfigPending or ConfigSaving or MonitorSaving then Exit;
  Result := 2;
  if not Enabled or not AudIsOpen or (AudTimerID=0) then Exit;
  Result := 3;
  if not AudSettingsValid(Settings) then Exit;
  { All floating point is task-only, before publishing to the resident IRQ. }
  EqBuild(Settings.EQ,RequestedEQ);
  if Busy or TimerActive or ConfigPending then begin Result := 1; Exit; end;
  { A plain cache publication. Never perform GUI, INI or hardware calls
    while this short critical section prevents timer service. }
  Busy := True;
  MxOwnsConfig := False; { the submitting interface owns this new request }
  RequestedSettings := Settings;
  EQChanged := not EqSame(ActiveSettings.EQ,Settings.EQ);
  RevChanged := not RevSame(ActiveSettings.Rev,Settings.Rev);
  if RequestedSettings.Source<6 then
    RequestedSettings.MonitorSource := RequestedSettings.Source
  else RequestedSettings.MonitorOn := 0;
  ConfigError := 0; ConfigNeedsSave := True; ConfigPending := True;
  Busy := False; Result := 0;
end;

function ConfigCancel: Boolean;
begin
  Result := False;
  if Busy or TimerActive then Exit;
  Busy := True;
  if ConfigPending then begin
    ConfigPending := False; ConfigNeedsSave := False; ConfigError := 4;
  end;
  Busy := False; Result := True;
end;

function ConfigPoll(var Active,Saved: TAudSettings): Word;
begin
  Active := ActiveSettings; Saved := SavedSettings;
  Result := 0;
  if ConfigPending then Exit;
  if ConfigError<>0 then begin Result := ConfigError; Exit; end;
  if ConfigNeedsSave then begin
    ConfigSaving := True;
    if not ConfigSave(RequestedSettings) then begin
      ConfigSaving := False; ConfigNeedsSave := False; Result := 3; Exit;
    end;
    ConfigSaving := False; ConfigNeedsSave := False; MonitorDirty := False;
    SavedSettings := RequestedSettings; Saved := SavedSettings;
  end;
  if not AnyOutputActive and not InputOpened then SaveMonitor;
  Saved := SavedSettings;
  Active := ActiveSettings; Result := 1;
  MxNotify;
end;
