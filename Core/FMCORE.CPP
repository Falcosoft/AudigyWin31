#include "FMCORE.H"
#include "OPLSYN.H"

typedef char CheckPatchSize[sizeof(patchStruct) == 18 ? 1 : -1];
typedef char CheckSampleSize[sizeof(short) == 2 ? 1 : -1];
static OPLSynth synth;
static OPLSynth resetImage;

extern "C" void fmReset(long sampleRate)
{
    synth.Init(sampleRate);
    OPL_MEMSET(&resetImage, 0, sizeof(resetImage));
    OPL_MEMCPY(&resetImage, &synth, sizeof(synth));
}

extern "C" void fmQuickReset(void)
{
    /* No self-relative pointers: waveform pointers reference static tables.
       Restore a fully silent chip without rebuilding DBOPL rate tables. */
    OPL_MEMCPY(&synth, &resetImage, sizeof(synth));
}

extern "C" void fmStopPlayback(void)
{
    synth.StopPlayback(resetImage);
}

extern "C" void fmShort(unsigned char status, unsigned char d1, unsigned char d2)
{
    synth.WriteMidiData((DWORD)status | ((DWORD)d1 << 8) | ((DWORD)d2 << 16));
}

extern "C" void fmLong(unsigned char *data, unsigned size)
{
    synth.PlaySysex(data, size);
}

extern "C" void fmRender(short *pcm, unsigned frames)
{
    synth.GetSample(pcm, frames);
}
