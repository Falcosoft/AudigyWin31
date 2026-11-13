/* Audigy OPL timer core. Initialization is task-only; high-bit commands
   2..6 are the bounded integer/private-stack runtime interface. */
#include <windows.h>
#include <string.h>
#include "FMCORE.H"

/* The DLL keeps its far-pointer ABI. All synthesis data and the scratch
   block are in DGROUP, so the renderer only needs near data pointers. */
static short pcmBlock[512 * 2];
static unsigned char sysex[11];
static WORD irqStack[2048];
static WORD savedSS, savedSP;
static WORD requestCommand, requestValue;
static DWORD requestData;
static WORD ready;
static WORD renderRate = 44100U;
enum { MASTER_GAIN_ONE = 16384U };
static WORD masterGain = MASTER_GAIN_ONE;

static WORD modeReset(WORD n)
{
    /* Match the reset messages recognized by OPLSynth::PlaySysex. */
    if (sysex[0] != 0xf0 || sysex[n - 1] != 0xf7) return 0;
    switch (n) {
    case 6:
        return sysex[1] == 0x7e && sysex[2] == 0x7f && sysex[3] == 9 &&
               (sysex[4] == 1 || sysex[4] == 3);
    case 9:
        return sysex[1] == 0x43 && sysex[2] == 0x10 && sysex[3] == 0x4c &&
               !sysex[4] && !sysex[5] && sysex[6] == 0x7e && !sysex[7];
    case 11:
        return sysex[1] == 0x41 && sysex[2] == 0x10 && sysex[3] == 0x42 &&
               sysex[4] == 0x12 && !sysex[6] && sysex[7] == 0x7f && !sysex[8] &&
               ((sysex[5] == 0x40 && sysex[9] == 0x41) ||
                (!sysex[5] && sysex[9] == 1));
    }
    return 0;
}

static void playLong(WORD n)
{
    WORD volume;
    if (n == 8 && sysex[0] == 0xf0 && sysex[1] == 0x7f && sysex[2] < 128 &&
        sysex[3] == 4 && sysex[4] == 1 && sysex[5] < 128 && sysex[6] < 128 &&
        sysex[7] == 0xf7) {
        volume = ((WORD)sysex[6] << 7) | sysex[5];
        masterGain = volume + (volume >> 13);
        return;
    }
    if (modeReset(n)) masterGain = MASTER_GAIN_ONE;
    fmLong(sysex, n);
}

#if defined(__WATCOMC__) && defined(__I86__)
static short masterSample(short sample, WORD gain);
#pragma aux masterSample = "imul dx" "shrd ax,dx,14" \
    parm [ax] [dx] value [ax] modify exact [ax dx];
#else
static short masterSample(short sample, WORD gain)
{
    return (short)(((long)sample * gain) >> 14);
}
#endif

static void renderPCM(WORD frames)
{
    short *sample;
    WORD gain;
    fmRender(pcmBlock, frames);
    gain = masterGain;
    if (gain == MASTER_GAIN_ONE) return;
    for (sample = pcmBlock; sample < pcmBlock + frames * 2U; ++sample)
        *sample = masterSample(*sample, gain);
}

static void quickReset(void)
{
    masterGain = MASTER_GAIN_ONE;
    fmQuickReset();
}

/* All runtime paths use integers only. The assembly gateway preserves
   the interrupted SS:SP and registers; the synth runs on its own 4K stack. */
static WORD dispatchIRQ(void)
{
    WORD n;
    if (!ready) return 0;
    switch (requestCommand) {
    case 2:
        if ((BYTE)requestData < 0x80 || (BYTE)requestData >= 0xf0) return 0;
        fmShort((BYTE)requestData, (BYTE)(requestData >> 8),
                (BYTE)(requestData >> 16));
        return 1;
    case 3:
        n = requestValue;
        if (n < 2 || n > sizeof(sysex)) return 0;
        if (!HIWORD(requestData) || (DWORD)LOWORD(requestData) + n > 65536UL)
            return 0;
        _fmemcpy(sysex, (const void FAR *)requestData, n);
        playLong(n);
        return 1;
    case 4:
        if (!requestValue || requestValue > 512) return 0;
        n = requestValue * 4U;
        if (!HIWORD(requestData) || (DWORD)LOWORD(requestData) + n > 65536UL)
            return 0;
        renderPCM(requestValue);
        _fmemcpy((void FAR *)requestData, pcmBlock, n);
        return 1;
    case 5:
        quickReset();
        return 1;
    case 6:
        fmStopPlayback();
        return 1;
    }
    return 0;
}

static WORD privateStack(void);
#pragma aux privateStack = \
    "push bp" "push si" "push di" "push ds" "push es" \
    "mov savedSS,ss" "mov savedSP,sp" \
    "pushf" "pop ax" "cli" "mov bx,ds" "mov ss,bx" \
    "mov sp,offset irqStack+4096" "push ax" "popf" \
    "call dispatchIRQ" "mov dx,ax" \
    "pushf" "pop bx" "cli" "mov ss,savedSS" "mov sp,savedSP" \
    "push bx" "popf" "mov ax,dx" \
    "pop es" "pop ds" "pop di" "pop si" "pop bp" \
    value [ax] modify [bx cx dx];

static WORD dataSelector(void);
#pragma aux dataSelector = "mov ax,ds" value [ax] modify exact [ax];

BOOL WINAPI __loadds LibMain(HINSTANCE inst, WORD data, WORD heap, LPSTR cmd)
{
    (void)inst; (void)data; (void)heap; (void)cmd;
    return TRUE;
}

WORD WINAPI __export __loadds OPLCORE(WORD command, WORD value, DWORD data)
{
    WORD n;
    if (command == 0) return 0xa302; /* audited integer/private-stack ABI */
    if (command == 7) return dataSelector();
    if (command & 0x8000U) {
        requestCommand = command & 0x7fffU;
        requestValue = value;
        requestData = data;
        return privateStack();
    }
    switch (command) {
    case 8:
        if (value != 44100U && value != 48000U) return 0;
        if (ready && value != renderRate) return 0;
        renderRate = value;
        return 1;
    case 1:
        fmReset((long)renderRate);
        masterGain = MASTER_GAIN_ONE;
        ready = 1;
        return 1;
    case 5:
        if (!ready) return 0;
        quickReset();
        return 1;
    case 2:
        if ((BYTE)data < 0x80 || (BYTE)data >= 0xf0) return 0;
        fmShort((BYTE)data, (BYTE)(data >> 8), (BYTE)(data >> 16));
        return 1;
    case 3:
        if (value < 2 || value > 11) return 0;
        n = value;
        break;
    case 4:
        if (!value || value > 512) return 0;
        n = value * 4U;
        break;
    default:
        return 0;
    }
    if (!HIWORD(data) || (DWORD)LOWORD(data) + n > 65536UL) return 0;
    if (command == 3) {
        _fmemcpy(sysex, (const void FAR *)data, n);
        playLong(value);
    } else {
        renderPCM(value);
        _fmemcpy((void FAR *)data, pcmBlock, n);
    }
    return 1;
}
