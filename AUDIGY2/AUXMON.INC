{ Win16 auxiliary outputs: input monitor, optional FM synth, then the
  optional Playback 2 alias for Creative's legacy master AUX lookup. }

function AuxMessage(DeviceID,Message: Word; User,Param1,Param2: LongInt): LongInt; export;
const AUXCAPS_MASTER=$0008; { Creative fallback, mapped to Playback 2 }
      AUXCAPS_MIDI=$0040;
      AUXCAPS_LRVOLUME=$0002;
var Caps: TAuxCaps;
    AuxCount,N,V: Word;
    MidiAux,WaveAux: Boolean;
begin
  Result := MMSYSERR_NOTSUPPORTED;
  if Message=100 then begin Result := 0; Exit; end; { AUXM_INIT }
  AuxCount := 1; { input monitor }
  if MidiEvents<>nil then Inc(AuxCount);
  WaveAux := (ActiveSettings.Playback2Aux<>0) and (DeviceID=AuxCount);
  if ActiveSettings.Playback2Aux<>0 then Inc(AuxCount);
  if Message=3 then begin { AUXDM_GETNUMDEVS }
    Result := 0;
    if Enabled and AudIsOpen then Result := AuxCount;
    Exit;
  end;
  Result := MMSYSERR_BADDEVICEID;
  if DeviceID>=AuxCount then Exit;
  MidiAux := (DeviceID=1) and (MidiEvents<>nil);
  Result := MMSYSERR_NOTENABLED;
  if not Enabled or not AudIsOpen then Exit;
  case Message of
    4: begin { AUXDM_GETDEVCAPS: Win16 AUXCAPS is 44 bytes }
      Result := MMSYSERR_INVALPARAM;
      if (Param1=0) or (Param2<=0) then Exit;
      N := SizeOf(Caps); if Param2<LongInt(N) then N := Word(Param2);
      if IsBadWritePtr(Pointer(Param1),N) then Exit;
      FillChar(Caps,SizeOf(Caps),0);
      Caps.wMid := 0; Caps.wPid := 0; Caps.vDriverVersion := AudDriverVersion;
      if WaveAux then begin
        StrPCopy(Caps.szPname,'Audigy 2 Playback 2 Volume');
        Caps.wTechnology := AUXCAPS_MASTER;
        Caps.dwSupport := AUXCAPS_VOLUME or AUXCAPS_LRVOLUME;
      end else if MidiAux then begin
        StrPCopy(Caps.szPname,MidiPortName);
        Caps.wTechnology := AUXCAPS_MIDI;
        Caps.dwSupport := AUXCAPS_VOLUME or AUXCAPS_LRVOLUME;
      end else begin
        StrPCopy(Caps.szPname,'Creative Audigy 2 Input Monitor');
        Caps.wTechnology := AUXCAPS_AUXIN;
        Caps.dwSupport := AUXCAPS_VOLUME;
      end;
      Move(Caps,Pointer(Param1)^,N); Result := 0;
    end;
    5: begin { AUXDM_GETVOLUME }
      if WaveAux then begin
        Result := WodMessage(1,WODM_GETVOLUME,0,Param1,0);
        Exit;
      end;
      if MidiAux then begin
        Result := ModMessage(0,MODM_GETVOLUME,0,Param1,0);
        Exit;
      end;
      Result := MMSYSERR_INVALPARAM;
      if (Param1=0) or IsBadWritePtr(Pointer(Param1),4) then Exit;
      V := ActiveSettings.MonitorVolume;
      if (ActiveSettings.MonitorOn=0) or (ActiveSettings.Source=6) then V := 0;
      PLongValue(Param1)^ := LongInt(V) or (LongInt(V) shl 16);
      Result := 0;
    end;
    6: begin { AUXDM_SETVOLUME }
      if WaveAux then begin
        Result := WodMessage(1,WODM_SETVOLUME,0,Param1,0);
        Exit;
      end;
      if MidiAux then begin
        Result := ModMessage(0,MODM_SETVOLUME,0,Param1,0);
        Exit;
      end;
      { The input monitor uses the low word as its common stereo level. }
      Result := MMSYSERR_ALLOCATED;
      if Busy or TimerActive or ConfigPending or ConfigNeedsSave or
         ConfigSaving or MonitorSaving then Exit;
      Busy := True;
      V := LoWord(Param1);
      if V=0 then ActiveSettings.MonitorOn := 0
      else begin
        ActiveSettings.MonitorVolume := V;
        if ActiveSettings.Source=6 then ActiveSettings.MonitorOn := 0
        else ActiveSettings.MonitorOn := 1;
      end;
      MonitorDirty := True; MonitorPending := True; MonitorFault := False;
      Busy := False;
      if not AnyOutputActive and not InputOpened then SaveMonitor;
      Result := 0;
    end;
  else
    Result := MMSYSERR_NOTSUPPORTED;
  end;
end;
