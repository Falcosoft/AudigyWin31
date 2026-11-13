{ Win16 MIDI entry. The resident audio timer owns synthesis and the FIFO.
  Public entries only publish bounded timestamped MIDI packets. }
{$S-}
procedure MidiInvalidate;
var Flags: Word;
begin
  asm
    pushf
    pop ax
    mov Flags,ax
    cli
  end;
  MidiHead := 0; MidiTail := 0;
  if MidiEpoch=$7FFFFFFF then MidiEpoch := 1 else Inc(MidiEpoch);
  if MidiConfigured and (OplOwner<>0) then OplStopping := True;
  asm
    mov ax,Flags
    push ax
    popf
  end;
end;
{$S+}

procedure MidiNotify(const Client: TMidiOpen16; Flags,Message: Word;
                     Param: LongInt);
begin
  if (Flags<>0) and (Client.Callback<>0) then
    DriverCallback(Client.Callback,Flags,Client.Device,Message,Client.Instance,Param,0);
end;

procedure MidiGetClient(var Client: TMidiOpen16);
begin
  Client.Device := MidiHandle;
  Client.Callback := MidiCallback;
  Client.Instance := MidiInstance;
end;

{$S-} { MIDI players may issue short messages from a multimedia callback. }
function MidiEnqueue(var Event: TOplEvent; Cookie,Epoch: LongInt): Boolean;
var Flags,Next,Depth: Word;
    AudioBusy: Boolean;
begin
  Result := False;
  Event.Tick := timeGetTime;
  { Serialize producers and queue invalidation. Publish the complete slot
    before moving the tail. Keep API calls outside the critical section. }
  asm
    pushf
    pop ax
    mov Flags,ax
    cli
  end;
  if Enabled and not DriverExiting and not MidiFault and (MidiEvents<>nil) and
     (Cookie<>0) and (Cookie=MidiCookie) and (Epoch=MidiEpoch) then begin
    AudioBusy := Busy or TimerActive;
    if (Event.Size<>0) and AudioBusy then Inc(MidiDiag.BusyRejects)
    else begin
      Next := (MidiTail+1) and (OplEventSlots-1);
      if Next=MidiHead then Inc(MidiDiag.FullRejects)
      else begin
        MidiEvents^[MidiTail] := Event;
        MidiTail := Next;
        Depth := (Next+OplEventSlots-MidiHead) and (OplEventSlots-1);
        if Depth>MidiDiag.PeakQueue then MidiDiag.PeakQueue := Depth;
        Inc(MidiDiag.Accepted);
        if AudioBusy then begin
          Inc(MidiDiag.AcceptedBusy);
          if Outputs[1]<>nil then
            if Outputs[1]^.Opened then Inc(MidiDiag.AcceptedBusyWave2);
        end;
        if Event.Size<>0 then Inc(MidiDiag.LongPackets)
        else case Event.Data[0] and $F0 of
          $90: if Event.Data[2]<>0 then Inc(MidiDiag.NoteOns);
          $B0: begin
            Inc(MidiDiag.Controllers);
            if (Event.Data[1]=120) or (Event.Data[1]=121) or
               (Event.Data[1]=123) then Inc(MidiDiag.ResetCCs);
          end;
          $C0: Inc(MidiDiag.Programs);
        end;
        Result := True;
      end;
    end;
  end;
  asm
    mov ax,Flags
    push ax
    popf
  end;
end;
{$S+}

function ModMessage(Device,Message: Word; User,Param1,Param2: LongInt): LongInt; export;
var Client: TMidiOpen16;
    Caps: TMidiOutCaps;
    Event: TOplEvent;
    Header: PMidiHdr;
    N: Word;
    L,Epoch: LongInt;
begin
  Result := 0;
  if Message=MODM_INIT then Exit;
  if Message=MODM_GETNUMDEVS then begin
    if Enabled and (MidiEvents<>nil) then Result := 1;
    Exit;
  end;
  Result := MMSYSERR_BADDEVICEID;
  if Device<>0 then Exit;
  if (Message=MODM_GETDEVCAPS) or (Message=MODM_OPEN) or
     (Message=MODM_GETVOLUME) or (Message=MODM_SETVOLUME) then begin
    Result := MMSYSERR_NOTENABLED;
    if not Enabled or DriverExiting or (MidiEvents=nil) then Exit;
  end;
  { Win16 volume calls address the device, not an open MIDI stream.
    Use the same stereo cache as the FM mixer, with no DSP or disk I/O. }
  if Message=MODM_GETVOLUME then begin
    Result := MMSYSERR_INVALPARAM;
    if (Param1<>0) and not IsBadWritePtr(Pointer(Param1),4) then begin
      PLongValue(Param1)^ := Volume[2]; Result := 0;
    end;
    Exit;
  end;
  if Message=MODM_SETVOLUME then begin
    CachePlaybackVolume(2,Param1);
    Result := 0; Exit;
  end;
  if Message=MODM_GETDEVCAPS then begin
    Result := MMSYSERR_INVALPARAM;
    if (Param1=0) or (Param2<=0) then Exit;
    L := Param2;
    if L>SizeOf(Caps) then L := SizeOf(Caps);
    N := Word(L);
    if IsBadWritePtr(Pointer(Param1),N) then Exit;
    FillChar(Caps,SizeOf(Caps),0);
    Caps.vDriverVersion := AudDriverVersion;
    StrPCopy(Caps.szPname,MidiPortName);
    if ActiveSettings.MidiSynth=SynthSoundFont then begin
      Caps.wTechnology := 2; { MOD_SYNTH }
      Caps.wVoices := ActiveSettings.SoundFontVoices;
    end else begin
      Caps.wTechnology := MOD_FMSYNTH; Caps.wVoices := 18;
    end;
    Caps.wNotes := Caps.wVoices; Caps.wChannelMask := $FFFF;
    Caps.dwSupport := MIDICAPS_VOLUME or MIDICAPS_LRVOLUME;
    Move(Caps,Pointer(Param1)^,N);
    Result := 0; Exit;
  end;
  if Message=MODM_OPEN then begin
    Result := MMSYSERR_INVALPARAM;
    if (User=0) or (Param1=0) then Exit;
    if IsBadWritePtr(Pointer(User),4) or
       IsBadReadPtr(Pointer(Param1),SizeOf(Client)) then Exit;
    Result := MMSYSERR_ALLOCATED;
    if (MidiCookie<>0) or MidiLaunching then Exit;
    Result := MIDIERR_NOTREADY;
    if Busy or TimerActive then Exit;
    Client := PMidiOpen16(Param1)^;
    Result := MMSYSERR_NODRIVER;
    if ActiveSettings.MidiSynth=SynthSoundFont then begin
      if not MidiCoreReady then Exit;
    end else if not EnsureMidiCore then Exit;
    Result := MIDIERR_NOTREADY;
    if not Enabled or DriverExiting or Busy or TimerActive then Exit;
    Busy := True;
    MidiFullResetPending := True;
    MidiInvalidate; MidiFault := False;
    OplFailed := False;
    MidiHandle := Client.Device;
    MidiCallback := Client.Callback; MidiInstance := Client.Instance;
    MidiFlags := HiWord(Param2) and 7;
    MidiCookie := MidiEpoch; PLongValue(User)^ := MidiCookie;
    Inc(MidiDiag.Opens); MidiDiag.LastOpen := timeGetTime;
    Busy := False;
    MidiNotify(Client,MidiFlags,MOM_OPEN,0);
    Result := 0; Exit;
  end;
  if Message=MODM_RESET then begin
    Inc(MidiDiag.ResetCalls); MidiDiag.LastReset := timeGetTime;
  end else if Message=MODM_CLOSE then begin
    Inc(MidiDiag.CloseCalls); MidiDiag.LastClose := timeGetTime;
  end;
  Result := MMSYSERR_INVALHANDLE;
  if (MidiCookie=0) or (User<>MidiCookie) then Exit;
  Epoch := MidiEpoch;
  Result := MMSYSERR_NOTSUPPORTED;
  case Message of
    MODM_DATA: begin
      Result := 0;
      if (Byte(Param1)<$80) or (Byte(Param1)>=$F0) then Exit;
      FillChar(Event,SizeOf(Event),0);
      Event.Data[0] := Byte(Param1);
      Event.Data[1] := Byte(Param1 shr 8);
      Event.Data[2] := Byte(Param1 shr 16);
      if not MidiEnqueue(Event,User,Epoch) then Result := MIDIERR_NOTREADY;
    end;
    MODM_LONGDATA: begin
      Result := MIDIERR_NOTREADY;
      if Busy or TimerActive then begin Inc(MidiDiag.BusyRejects); Exit; end;
      if not Enabled or MidiFault then Exit;
      Result := MMSYSERR_INVALPARAM;
      if (Param1=0) or (Param2<SizeOf(TMidiHdr)) then Exit;
      Header := PMidiHdr(Param1);
      if IsBadWritePtr(Header,SizeOf(TMidiHdr)) then Exit;
      if (Header^.dwFlags and MHDR_PREPARED)=0 then begin
        Result := MIDIERR_UNPREPARED; Exit;
      end;
      if (Header^.dwFlags and MHDR_INQUEUE)<>0 then begin
        Result := MIDIERR_STILLPLAYING; Exit;
      end;
      L := Header^.dwBufferLength;
      if (L<0) or (Header^.lpData=nil) then Exit;
      { The tested core accepts complete short reset/configuration SysEx.
        Copy them now; unsupported packets complete without retaining a header. }
      if (L=6) or (L=8) or (L=9) or (L=11) then begin
        N := Word(L);
        if IsBadReadPtr(Header^.lpData,N) then Exit;
        FillChar(Event,SizeOf(Event),0); Event.Size := Byte(N);
        Move(Header^.lpData^,Event.Data[0],N);
        if not MidiEnqueue(Event,User,Epoch) then begin
          Result := MIDIERR_NOTREADY; Exit;
        end;
      end;
      Header^.dwFlags := Header^.dwFlags or MHDR_DONE;
      MidiGetClient(Client);
      MidiNotify(Client,MidiFlags,MOM_DONE,Param1);
      Result := 0;
    end;
    MODM_CLOSE, MODM_RESET: begin
      Result := MIDIERR_NOTREADY;
      if Busy or TimerActive then Exit;
      Busy := True;
      MidiGetClient(Client); N := MidiFlags;
      if Message=MODM_CLOSE then MidiCookie := 0;
      MidiFault := not MidiCoreReady; MidiInvalidate;
      if Message=MODM_CLOSE then begin
        Inc(MidiDiag.CloseOK);
      end else begin
        OplFailed := False;
        Inc(MidiDiag.ResetOK);
      end;
      Busy := False;
      if not TimerActive then MidiRendererLog;
      if Message=MODM_CLOSE then MidiNotify(Client,N,MOM_CLOSE,0);
      Result := 0;
    end;
  end;
end;
