Creative Audigy 1 and Audigy 2/ZS audio drivers for Windows 3.1x
=============================================================

Version 2.0

FEATURES

Requires Windows 3.1x in 386 Enhanced mode and a supported Creative card:
  Audigy 1:    AUDIGY1.DLL
  Audigy 2/ZS: AUDIGY2.DLL
  Audigy 4 Pro: AUDIGY2.DLL (compatible architecture, unverified on hardware).

The drivers require a compatible EMU10K2-family Audigy PCI card.

- Playback: 8-bit or 16-bit, mono/stereo, 8000..48000 Hz.
- Recording: 16-bit mono/stereo at 8000, 11025, 16000, 22050, 24000,
  32000, 44100 or 48000 Hz. 8-bit recording is not supported.
- Two WaveOut playback devices, one application per device, plus recording.
- Independent stereo volume and front/rear balance for both WaveOut devices.
- OPL3 and SoundFont software MIDI engines with a dedicated stereo playback pair.
- Selectable recording sources, input monitoring and Wave loopback recording.
- Hardware ten-band equalizer, Room, Chamber, Plate and Hall reverb, and
  analog LFE bass redirection.
- Audio Mixer application for convenient access to driver controls.

MIDI synthesis runs on the CPU and plays through the Audigy's DSP mixer.
The drivers run directly under Windows without a DOS TSR.

INSTALLATION

1. Back up your working configuration. Before starting Windows, configure
   your XMS provider as described under MEMORY CONFIGURATION below.
2. Put SETUP.EXE, the driver DLLs, AUDMIXER.EXE, OPLCORE.DLL, SFCORE.DLL
   and this README.TXT in the same folder. If Windows SYSTEM lacks
   MSMIXMGR.DLL, also place your copy of that DLL beside Setup.
   Run SETUP.EXE in Windows.
3. Select the driver matching your card. Check the displayed memory information
   and PhysicalBase; the reserved area must be installed, unused physical RAM.
   If Windows memory cannot be detected, enter your current CONFIG.SYS XMS
   limit when requested. Setup does not change your XMS configuration.
4. Confirm the settings and choose Install. Restart Windows normally.
5. Open Audio Utilities -> Audio Mixer in Program Manager to adjust controls.

Setup installs the selected driver, mixer and both synth DLLs in Windows\SYSTEM
and installs MSMIXMGR.DLL when missing. It registers WaveOut, AUX, mixer and
MIDI using available SYSTEM.INI aliases. It preserves other sound drivers
and explicit settings. If installing both Audigy drivers, run Setup for
each and assign separate PhysicalBase areas. They share one Audio Mixer icon.
Enable the built-in synth on only one Audigy driver per Windows session.

For updates, remove the driver in Control Panel -> Drivers, restart
Windows and run Setup. Close audio applications and AUDMIXER first.
To update from DOS, exit Windows and replace the driver DLL and both
synth DLLs in Windows\SYSTEM, keeping your INI file. When upgrading
from 1.5, add the MIDI alias below. Setup can reuse an identical core
DLL while it is loaded. Exit Windows to replace an in-use DLL.

To uninstall, select the appropriate Audigy in Control Panel -> Drivers,
choose Remove and restart Windows. Settings, files and the shared mixer icon
are left in place. Setup keeps the first SYSTEM.INI backup as AUD1INST.BAK
or AUD2INST.BAK in the Windows directory; existing backups are not overwritten.

MANUAL INSTALLATION (ALTERNATIVE TO SETUP)

1. Exit Windows and back up SYSTEM.INI and your current audio settings.
2. Copy the appropriate AUDIGY1.DLL or AUDIGY2.DLL, AUDMIXER.EXE,
   OPLCORE.DLL and SFCORE.DLL to Windows SYSTEM. Copy MSMIXMGR.DLL
   there if missing.
3. Create AUDIGY1.INI or AUDIGY2.INI in the Windows directory, with the matching
   [AUDIGY1] or [AUDIGY2] section and a valid PhysicalBase BEFORE loading it.
4. Append msmixmgr.dll after mmsystem.dll on the existing [boot] drivers line:

     [boot]
     drivers=mmsystem.dll msmixmgr.dll

   Keep any other entries already on that line; do not repeat msmixmgr.dll.
5. Add these entries under [drivers] in SYSTEM.INI for Audigy 1:

     [drivers]
     wave=Audigy1.dll
     aux=Audigy1.dll
     mixer=Audigy1.dll
     midi=Audigy1.dll

   For Audigy 2/ZS use Audigy2.dll on all four lines.
   To keep another driver such as HDA2, use available numbered names
   such as wave1, aux1, mixer1 and midi1.
6. Start Windows and run Windows\SYSTEM\AUDMIXER.EXE.

For manual removal, exit Windows and remove only this driver's registrations.
Do not remove MSMIXMGR.DLL or its boot entry while another driver needs it.

MEMORY CONFIGURATION

The default PhysicalBase=$08000000 starts at 128 MiB and uses addresses
$08000000..$0803FFFF. It requires MORE than 128 MB installed RAM; in practice,
192 MB or more is a convenient configuration, not an absolute driver minimum.

Configure the XMS provider (HIMEM.SYS, HIMEMX, etc.) to expose 64 MB of XMS
normally, and no more than 128 MB. The entire driver area must lie in real
RAM ABOVE all memory managed by DOS/Windows or used by other software.
Note that 128 MB of XMS above the first 1 MB can extend past the default
PhysicalBase. With that base, use 64 MB XMS (or at most 127 MB), or move
PhysicalBase higher, e.g. $09000000, if enough physical RAM is installed.

Smaller-memory systems can also be used. Example with 96 MB installed:
limit XMS to 64 MB and set PhysicalBase=$05000000 (80 MiB). The driver uses
$05000000..$0503FFFF, above that XMS area and within installed RAM.
Do NOT keep the default $08000000 on a 96 MB machine: no RAM exists there.

Check how your memory manager's limit option is defined: an XMS-size limit
is not necessarily the same as a total physical-memory limit. Keep HDA2 and
Audigy areas separate; neither area may be used by the XMS provider.
Two Audigy drivers also need separate areas, e.g. $08000000 and $09000000
when enough physical RAM is installed and XMS is limited to 64 MB.

SETTINGS, MIXER AND RECORDING

Open Control Panel -> Drivers -> the appropriate Audigy -> Setup.
Settings are saved in AUDIGY1.INI or AUDIGY2.INI in the Windows directory.
The dialog separates settings that take effect during the session from
those requiring a Windows restart.

For convenient real-time adjustments, open Audio Utilities -> Audio Mixer.
Select the Audigy mixer device for playback, recording, input monitoring,
equalizer and reverb controls. The same AUDMIXER.EXE works with both drivers.
Extended controls require MSMIXMGR.DLL; basic wave/AUX volume controls remain
available without it.

Playback 1, Playback 2 and the built-in synth have separate volume and
Front/Rear controls. A fader value of 50 uses both pairs, 100 uses the
front pair and 0 uses the rear pair. To give WinGroove its own playback
and volume path, select the second Audigy WaveOut device in WinGroove.

Choose Line-In, Mic, CD analog, Aux, CD Digital, AudigyDrive SPDIF or Wave
as the recording source. Your recording application selects the audio format.
Some physical inputs require the appropriate connectors or an AudigyDrive.
Recording level controls recording volume; 100 is the starting point.
Analog source level is available for Line-In, CD analog and Aux; 50 means no
boost or attenuation. Digital inputs and Mic do not use this control.

Enable Monitor to hear the selected physical input through your speakers
without recording. Monitor level is independent of recording level and can
also be adjusted with an AUX-compatible mixer. Avoid microphone feedback.

Wave records both playback devices and the built-in synth from the
selected Audigy before output volume, faders, EQ and reverb. With recording
level at 100, the recording keeps the source level. Speaker volume and
mute do not change the recording level.
Audio sent only to another sound card is not captured. External physical
inputs are not included. Monitor is automatically unchecked and disabled
for Wave. Do not enable software monitoring back to the same Audigy in your
recording application, as this can create feedback.

MIDI SETUP

Open the driver's Setup dialog and choose MIDI Settings. Select OPL3 Synth,
SF2 Synth or None, and a sample rate of 44.1 kHz (default) or 48 kHz.
Restart Windows to apply MIDI settings. OPL3 is the default when neither
MidiSynth nor the legacy OplMidi setting is present.

For SF2 Synth, select a PCM16 SF2 file with Browse or type its path.
Loading the bank requires an x87 FPU. Playback uses integer arithmetic.
The engine does not implement SoundFont modulators or per-channel chorus
and reverb sends. The Audigy hardware reverb control is available.
Relative paths are resolved from Windows SYSTEM. The default filename
is 4GMGSMT.SF2. Supply your own SoundFont. The core keeps its PCM samples
in locked Windows memory. A large bank needs enough free Windows-managed
RAM for its sample data and some additional memory for presets and loading.
This memory is separate from the PhysicalBase reservation.

The SF2 voice limit is 32 through 128 and defaults to 64. A layered or
stereo patch can use several sample voices for one note. Try 32 voices
if your system struggles to keep up. Headroom is 0 through 24 dB and
defaults to 3 dB. Increase it if dense playback clips.

Both engines use the same MIDI port on a given card:
  Audigy 1 MIDI Synth
  Audigy 2 MIDI Synth

Select this port in your MIDI application or Windows MIDI Mapper. If you
used a development build with an older port name, update its Port Name
entries once. The synth stereo volume is available from MIDI volume APIs,
the matching MIDI AUX control and Audio Mixer. Enable Playback 2 AUX
volume in MIDI Settings to expose a separate AUX control for a synth
such as WinGroove that uses Playback 2.

EQUALIZER, REVERB AND BASS REDIRECTION

These are hardware DSP effects, so they do not consume much CPU.
Open Setup -> Equalizer for ten bands (31 Hz to 16 kHz), each -12..+12 dB,
with a -24..0 dB preamp. Reduce preamp when boosting to avoid distortion.
Setup -> Reverb offers Room, Chamber, Plate and Hall, with level 0..100
(default 50). Chamber has a shorter tail than Plate and Hall.
Both effects are disabled by default, and affect playback and monitored
inputs on front/rear speakers. Recordings remain unprocessed.
Apply lets you hear and save changes without closing; OK applies and closes.
Cancel discards only unapplied changes. Settings are restored at startup.
Applying effects may briefly interrupt sound. Start at a low volume.
The same effect controls are also available through Audio Mixer.
Bass Redirect sends low frequencies to the analog LFE output. The
crossover is adjustable from 60 to 160 Hz, with a default of 100 Hz.
Enable it in Setup when using a compatible analog subwoofer connection.

INI SETTINGS

Example AUDIGY1.INI:

  [AUDIGY1]
  PhysicalBase=$08000000
  CardIndex=0
  FrontRear1=50
  FrontRear2=50
  FrontRearFM=50
  MidiSynth=1
  MidiRate=44100
  SoundFont=4GMGSMT.SF2
  SoundFontVoices=64
  SoundFontHeadroomDB=3
  Playback2Aux=0
  BassRedirect=0
  BassCutoffHz=100
  HalfBufferMS=40
  RefillSliceMS=10
  TimerIntervalMS=1
  TimerResolutionMS=1
  InputSource=LineIn
  InputLevel=100
  InputSourceLevel=50
  MonitorInput=0
  MonitorLevel=50
  ShutdownWorkaround=1
  Debug=0

For Audigy 2/ZS use AUDIGY2.INI with [AUDIGY2] instead. Its additional,
startup-only setting is Aud2Gain=0 (0..12 dB; default 0).

PhysicalBase       Start of the reserved 256 KiB area; default $08000000.
                   Must be aligned to 4096 bytes.
CardIndex          0 for the first supported card, 1 for the next card of the
                   same driver family.
FrontRear1/2/FM    0 = rear, 50 = both, 100 = front. FM applies to either
                   built-in synth.
MidiSynth          0 = None, 1 = OPL3, 2 = SF2. If missing, OplMidi=0/1 is
                   honored. With both keys absent the default is OPL3.
MidiRate           44100 (default) or 48000 Hz, for either synth.
SoundFont          PCM16 SF2 file for SF2 mode, default 4GMGSMT.SF2.
SoundFontVoices    32..128, default 64.
SoundFontHeadroomDB 0..24 dB attenuation before PCM conversion, default 3.
Playback2Aux       0=off (default), 1=show a Playback 2 AUX volume control.
BassRedirect       0=off (default), 1=on. BassCutoffHz is 60..160 in 10 Hz
                   steps, default 100.
HalfBufferMS       10..60, default 40. Smaller values reduce playback latency.
RefillSliceMS      5..30, default 10. Normally leave at 10.
TimerIntervalMS    1..20, default 5. The example uses 1 for faster servicing.
TimerResolutionMS  1..10, default 1. Normally leave at 1.
InputSource        LineIn, Mic, CD, Aux, CDDigital, SPDIF or Wave.
InputLevel         0..100, default 100; recording volume.
InputSourceLevel   0..100, default 50; analog source level as described above.
MonitorInput       0=off (default), 1=on; unavailable for Wave.
MonitorLevel       0..100, default 50; listening level of the physical input.
ShutdownWorkaround 0 or 1, default 1. Leave enabled for reliable Windows exit.
Debug              0=off (default), 1=diagnostic logging.
Aud2Gain           Audigy 2/ZS only: 0..12 dB, default 0; digital gain in the
                   output mixer. This also affects analog speaker output.
                   Set in 0.25 dB steps. Requires a Windows restart.

Optional effect settings (normally saved through Setup or Audio Mixer):
EQEnabled=0/1 (default 0), EQPreamp=-24..0 (default 0),
EQBand1..EQBand10=-12..12 (default 0), ordered from bass to treble.
ReverbEnabled=0/1 (default 0), ReverbLevel=0..100 (default 50),
ReverbPreset=0 Room, 1 Hall, 2 Plate, 3 Chamber (default 0).

Restart Windows after editing the INI manually. The [Volume] section and
MonitorSource entry are maintained automatically; normally do not edit them.

TROUBLESHOOTING

For lower latency, try HalfBufferMS=20 with RefillSliceMS=10. Change one
setting at a time; larger buffers do not always improve playback.
Check the selected device in applications when using more than one card.
Do not run DOS emulation or hardware utilities on the Audigy during Windows.

For diagnostics, set Debug=1 and restart Windows. AUDIGY1.LOG or AUDIGY2.LOG
is in the Windows directory and is cleared at startup.
Copy it before restarting.
Logging can affect timing, so also report whether Debug=0 has the problem.
With Debug=0 the shutdown workaround may still write dots to the log.
If SF2 fails to start, check the bank path and available lockable Windows
memory. With Debug=1, the log records the load status. Status 2 means
a bad bank file, 3 an invalid region, 4 an allocation failure, 5 a page
lock failure, 6 a file-open failure and 7 a file-read failure.

BUILD

Use Delphi 1 and Build All for each project you need:

  AUDIGY1\AUDIGY1.DPR  Audigy 1 driver
  AUDIGY2\AUDIGY2.DPR  Audigy 2/ZS driver
  SETUP\SETUP.DPR      Common installer
  MIXER\AUDMIXER.DPR   Common mixer

Place the resulting DLLs and EXEs beside this README.TXT and the built
OPLCORE.DLL and SFCORE.DLL. See the next section for the synth build.

REBUILDING THE SYNTH CORES

Use Open Watcom 2.0 with the 16-bit x86 Windows target installed.
The scripts use WCC (16-bit C), WPP (16-bit C++, for OPLCORE) and WLINK.
Install the Win16 headers, the 16-bit runtime and Windows import libraries
under LIB286 and LIB286\WIN, and WLINK's Windows DLL target definitions.

Open a command prompt with the Open Watcom environment initialized.
WATCOM should point to the installation root, and the host directory
containing WCC, WPP and WLINK should be on PATH. INCLUDE needs the Watcom
headers and the Win16 SDK headers. In a DOS/Windows command prompt use

  SET INCLUDE=%WATCOM%\h;%WATCOM%\h\win

From the extracted package root, build each core from its own directory.

  CD Core
  BUILD.BAT
  CD ..\SFCORE
  BUILD.BAT
  CD ..

The scripts produce Core\OPLCORE.DLL and SFCORE\SFCORE.DLL. Copy
both DLLs beside SETUP.EXE and the built driver DLLs when packaging
the release. SFCORE uses the included SFTABLE.H. Python 3 is only
needed to regenerate that header with MKTABLES.PY.

SOURCE and license notes accompany each project.

CHANGELOG

Version 2.0

- Added a built-in OPL3 synth and a PCM16 SoundFont synth, with a common
  MIDI port, an independent synth stereo pair and 44.1/48 kHz selection.
- Added SoundFont bank selection, large bank loading, polyphony and headroom
  settings. Corrected attenuation, tuning, filter response and sustain-heavy
  voice allocation.
- Improved MIDI reset, SysEx handling, MIDI queueing and DMA gap recovery.
  Added MIDI master volume, drum-channel selection and Creative player
  volume compatibility, including optional Playback 2 AUX volume.
- Both synths retry playback after PCM starvation during disk activity.
  Retries are spaced at least 500 ms apart.
- Added analog LFE bass redirection with an adjustable crossover and
  independent synth volume and front/rear balance.
- Updated the common installer to install both cores and register MIDI.

Version 1.5
- Both drivers now offer two independent playback devices. For example,
  a software MIDI synth like WinGroove can use the second while a game uses the first.
- Each device has its own stereo volume and Front/Rear fader.
- Software pause/resume replaces hardware pause for each playback device.
  This fixes COMET and maybe other games that use WAVMIX16.DLL.

version 1.4

- Extended mixer support for playback, recording, input monitoring, equalizer
  and reverb controls, using MSMIXMGR.DLL and the shared AUDMIXER.EXE utility.
- SETUP.EXE installs either driver, prepares its settings and creates an
  Audio Mixer icon in Program Manager. Manual installation remains available.
- Audigy 1 and Audigy 2/ZS drivers are supplied together in one package.

version 1.3

- Added Audigy 2/ZS support through the separate AUDIGY2.DLL driver.
- Added configurable Audigy 2/ZS digital output-stage gain (Aud2Gain).

versions 1.0 - 1.2

- Internal Audigy 1-only development versions.
- Established playback, recording, input monitoring, Wave recording,
  hardware equalizer and reverb functionality.


Zoltan Bacsko (Falcosoft)
Used AI tool: ChatGPT 6.1 Sol
2026.11.12
