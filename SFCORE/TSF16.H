/* TinySoundFont v0.9, https://github.com/schellingb/TinySoundFont
   VSBHDA-derived Win16 SF2 parser. The driver uses a separate fixed-point
   playback engine and keeps the PCM16 sample chunk in its original format.

   LICENSE (MIT)

   Copyright (C) 2017-2023 Bernhard Schelling
   Based on SFZero, Copyright (C) 2012 Steve Folta (https://github.com/stevefolta/SFZero)

   Permission is hereby granted, free of charge, to any person obtaining a copy of this
   software and associated documentation files (the "Software"), to deal in the Software
   without restriction, including without limitation the rights to use, copy, modify, merge,
   publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
   to whom the Software is furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
   INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
   PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
   LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
   USE OR OTHER DEALINGS IN THE SOFTWARE.

*/

#ifndef TSF_INCLUDE_TSF_INL
#define TSF_INCLUDE_TSF_INL

#ifdef __cplusplus
extern "C" {
#endif

//define this if you want the API functions to be static
#ifdef TSF_STATIC
#define TSFDEF static
#else
#define TSFDEF extern
#endif

typedef struct tsf tsf;

/* Win16 port: types that must retain VSBHDA/wcc386 widths. */
typedef int32_t tsf_s32;
typedef uint32_t tsf_u32;

struct tsf_stream
{
    void* data;
    tsf_u32 (*read)(void* data, void* ptr, tsf_u32 size);
    int (*skip)(void* data, tsf_u32 count);
    int (*read_samples)(void* data, tsf_u32 bytes);
};
TSFDEF tsf* tsf_load(struct tsf_stream* stream);
TSFDEF void tsf_close(tsf* f);

#ifdef __cplusplus
}
#endif
#endif /* TSF_INCLUDE_TSF_INL */

#ifdef TSF_IMPLEMENTATION
#undef TSF_IMPLEMENTATION

#include <stddef.h>

#define TSF_TRUE 1
#define TSF_FALSE 0
#define TSF_BOOL char
#define TSF_NULL 0

#ifdef __cplusplus
extern "C" {
#endif

typedef char tsf_fourcc[4];
typedef signed char tsf_s8;
typedef unsigned char tsf_u8;
typedef unsigned short tsf_u16;
typedef signed short tsf_s16;
/* tsf_u32 is declared in the public Win16 section above. */
typedef char tsf_char20[20];

#define TSF_FourCCEquals(value1, value2) (value1[0] == value2[0] && value1[1] == value2[1] && value1[2] == value2[2] && value1[3] == value2[3])

struct tsf
{
	struct tsf_preset* presets;
	tsf_u32 sampleCount;
	int presetNum;
};

enum { TSF_LOOPMODE_NONE, TSF_LOOPMODE_CONTINUOUS, TSF_LOOPMODE_SUSTAIN };


struct tsf_hydra
{
	struct tsf_hydra_phdr *phdrs; struct tsf_hydra_pbag *pbags; struct tsf_hydra_pmod *pmods;
	struct tsf_hydra_pgen *pgens; struct tsf_hydra_inst *insts; struct tsf_hydra_ibag *ibags;
	struct tsf_hydra_imod *imods; struct tsf_hydra_igen *igens; struct tsf_hydra_shdr *shdrs;
	tsf_u32 phdrNum, pbagNum, pmodNum, pgenNum, instNum, ibagNum, imodNum, igenNum, shdrNum;
};

union tsf_hydra_genamount { struct { tsf_u8 lo, hi; } range; tsf_s16 shortAmount; tsf_u16 wordAmount; };
struct tsf_hydra_phdr { tsf_char20 presetName; tsf_u16 preset, bank, presetBagNdx; tsf_u32 library, genre, morphology; };
struct tsf_hydra_pbag { tsf_u16 genNdx, modNdx; };
struct tsf_hydra_pmod { tsf_u16 modSrcOper, modDestOper; tsf_s16 modAmount; tsf_u16 modAmtSrcOper, modTransOper; };
struct tsf_hydra_pgen { tsf_u16 genOper; union tsf_hydra_genamount genAmount; };
struct tsf_hydra_inst { tsf_char20 instName; tsf_u16 instBagNdx; };
struct tsf_hydra_ibag { tsf_u16 instGenNdx, instModNdx; };
struct tsf_hydra_imod { tsf_u16 modSrcOper, modDestOper; tsf_s16 modAmount; tsf_u16 modAmtSrcOper, modTransOper; };
struct tsf_hydra_igen { tsf_u16 genOper; union tsf_hydra_genamount genAmount; };
struct tsf_hydra_shdr { tsf_char20 sampleName; tsf_u32 start, end, startLoop, endLoop, sampleRate; tsf_u8 originalPitch; tsf_s8 pitchCorrection; tsf_u16 sampleLink, sampleType; };

#define TSFR(FIELD) if (stream->read(stream->data, &i->FIELD, sizeof(i->FIELD)) != sizeof(i->FIELD)) return 0;
static int tsf_hydra_read_phdr(struct tsf_hydra_phdr* i, struct tsf_stream* stream) { TSFR(presetName) TSFR(preset) TSFR(bank) TSFR(presetBagNdx) TSFR(library) TSFR(genre) TSFR(morphology) return 1; }
static int tsf_hydra_read_pbag(struct tsf_hydra_pbag* i, struct tsf_stream* stream) { TSFR(genNdx) TSFR(modNdx) return 1; }
static int tsf_hydra_read_pmod(struct tsf_hydra_pmod* i, struct tsf_stream* stream) { TSFR(modSrcOper) TSFR(modDestOper) TSFR(modAmount) TSFR(modAmtSrcOper) TSFR(modTransOper) return 1; }
static int tsf_hydra_read_pgen(struct tsf_hydra_pgen* i, struct tsf_stream* stream) { TSFR(genOper) TSFR(genAmount) return 1; }
static int tsf_hydra_read_inst(struct tsf_hydra_inst* i, struct tsf_stream* stream) { TSFR(instName) TSFR(instBagNdx) return 1; }
static int tsf_hydra_read_ibag(struct tsf_hydra_ibag* i, struct tsf_stream* stream) { TSFR(instGenNdx) TSFR(instModNdx) return 1; }
static int tsf_hydra_read_imod(struct tsf_hydra_imod* i, struct tsf_stream* stream) { TSFR(modSrcOper) TSFR(modDestOper) TSFR(modAmount) TSFR(modAmtSrcOper) TSFR(modTransOper) return 1; }
static int tsf_hydra_read_igen(struct tsf_hydra_igen* i, struct tsf_stream* stream) { TSFR(genOper) TSFR(genAmount) return 1; }
static int tsf_hydra_read_shdr(struct tsf_hydra_shdr* i, struct tsf_stream* stream) { TSFR(sampleName) TSFR(start) TSFR(end) TSFR(startLoop) TSFR(endLoop) TSFR(sampleRate) TSFR(originalPitch) TSFR(pitchCorrection) TSFR(sampleLink) TSFR(sampleType) return 1; }
#undef TSFR

struct tsf_riffchunk { tsf_fourcc id; tsf_u32 size; };
struct tsf_envelope { float delay, attack, hold, decay, sustain, release, keynumToHold, keynumToDecay; };

struct tsf_region
{
	int loop_mode;
	tsf_u32 sample_rate;
	unsigned char lokey, hikey, lovel, hivel;
	unsigned int group;
	tsf_u32 offset, end, loop_start, loop_end;
	int transpose, tune, pitch_keycenter, pitch_keytrack, pitch_correction;
	float attenuation, pan;
	struct tsf_envelope ampenv, modenv;
	int initialFilterQ, initialFilterFc;
	int modEnvToPitch, modEnvToFilterFc, modLfoToFilterFc, modLfoToVolume;
	float delayModLFO;
	int freqModLFO, modLfoToPitch;
	float delayVibLFO;
	int freqVibLFO, vibLfoToPitch;
};

struct tsf_preset
{
	tsf_char20 presetName;
	tsf_u16 preset, bank;
	struct tsf_region* regions;
	int regionNum;
};


static float tsf_timecents2Secsf(float timecents) { return TSF_POWF(2.0f, timecents / 1200.0f); }
static float tsf_decibelsToGain(float db) { return (db > -100.f ? TSF_POWF(10.0f, db * 0.05f) : 0); }

static TSF_BOOL tsf_riffchunk_read(struct tsf_riffchunk* parent, struct tsf_riffchunk* chunk, struct tsf_stream* stream)
{
	TSF_BOOL IsRiff, IsList;
	if (parent && sizeof(tsf_fourcc) + sizeof(tsf_u32) > parent->size) return TSF_FALSE;
	if (stream->read(stream->data, &chunk->id, sizeof(tsf_fourcc)) != sizeof(tsf_fourcc) || *chunk->id <= ' ' || *chunk->id >= 'z') return TSF_FALSE;
	if (stream->read(stream->data, &chunk->size, sizeof(tsf_u32)) != sizeof(tsf_u32)) return TSF_FALSE;
	if (parent && chunk->size > parent->size - sizeof(tsf_fourcc) - sizeof(tsf_u32)) return TSF_FALSE;
	if (parent) parent->size -= sizeof(tsf_fourcc) + sizeof(tsf_u32) + chunk->size;
	IsRiff = TSF_FourCCEquals(chunk->id, "RIFF"), IsList = TSF_FourCCEquals(chunk->id, "LIST");
	if ((IsRiff && parent) || ((IsRiff || IsList) && chunk->size < 4)) return TSF_FALSE; //not allowed
	if (!IsRiff && !IsList) return TSF_TRUE; //custom type without sub type
	if (stream->read(stream->data, &chunk->id, sizeof(tsf_fourcc)) != sizeof(tsf_fourcc) || *chunk->id <= ' ' || *chunk->id >= 'z') return TSF_FALSE;
	chunk->size -= sizeof(tsf_fourcc);
	return TSF_TRUE;
}

static void tsf_region_clear(struct tsf_region* i, TSF_BOOL for_relative)
{
	TSF_MEMSET(i, 0, sizeof(struct tsf_region));
	i->hikey = i->hivel = 127;
	i->pitch_keycenter = 60; // C4
	if (for_relative) return;

	i->pitch_keytrack = 100;

	i->pitch_keycenter = -1;

	// SF2 defaults in timecents.
	i->ampenv.delay = i->ampenv.attack = i->ampenv.hold = i->ampenv.decay = i->ampenv.release = -12000.0f;
	i->modenv.delay = i->modenv.attack = i->modenv.hold = i->modenv.decay = i->modenv.release = -12000.0f;

	i->initialFilterFc = 13500;

	i->delayModLFO = -12000.0f;
	i->delayVibLFO = -12000.0f;
}

static void tsf_region_operator(struct tsf_region* region, tsf_u16 genOper, union tsf_hydra_genamount* amount, struct tsf_region* merge_region)
{
	enum
	{
		_GEN_TYPE_MASK       = 0x0F,
		GEN_FLOAT            = 0x01,
		GEN_INT              = 0x02,
		GEN_UINT_ADD         = 0x03,
		GEN_UINT_ADD15       = 0x04,
		GEN_KEYRANGE         = 0x05,
		GEN_VELRANGE         = 0x06,
		GEN_LOOPMODE         = 0x07,
		GEN_GROUP            = 0x08,
		GEN_KEYCENTER        = 0x09,

		_GEN_LIMIT_MASK      = 0xF0,
		GEN_INT_LIMIT12K     = 0x10, //min -12000, max 12000
		GEN_INT_LIMITFC      = 0x20, //min 1500, max 13500
		GEN_INT_LIMITQ       = 0x30, //min 0, max 960
		GEN_INT_LIMIT960     = 0x40, //min -960, max 960
		GEN_INT_LIMIT16K4500 = 0x50, //min -16000, max 4500
		GEN_FLOAT_LIMIT12K5K = 0x60, //min -12000, max 5000
		GEN_FLOAT_LIMIT12K8K = 0x70, //min -12000, max 8000
		GEN_FLOAT_LIMIT1200  = 0x80, //min -1200, max 1200
		GEN_FLOAT_LIMITPAN   = 0x90, //* .001f, min -.5f, max .5f,
		GEN_FLOAT_LIMITATTN  = 0xA0, //* .1f, min 0, max 144.0
		GEN_FLOAT_MAX1000    = 0xB0, //min 0, max 1000
		GEN_FLOAT_MAX1440    = 0xC0, //min 0, max 1440

		_GEN_MAX = 59
	};
	/* Win16 may place a 32-bit field at a two-byte boundary. Use exact
	   byte offsets before converting the address to the generator type. */
	#define TSF_REGION_OFFSET(FIELD) offsetof(struct tsf_region, FIELD)
	static const struct { unsigned char mode; size_t offset; } genMetas[_GEN_MAX] =
	{
		{ GEN_UINT_ADD                     , TSF_REGION_OFFSET(offset                       ) }, // 0 StartAddrsOffset
		{ GEN_UINT_ADD                     , TSF_REGION_OFFSET(end                          ) }, // 1 EndAddrsOffset
		{ GEN_UINT_ADD                     , TSF_REGION_OFFSET(loop_start                   ) }, // 2 StartloopAddrsOffset
		{ GEN_UINT_ADD                     , TSF_REGION_OFFSET(loop_end                     ) }, // 3 EndloopAddrsOffset
		{ GEN_UINT_ADD15                   , TSF_REGION_OFFSET(offset                       ) }, // 4 StartAddrsCoarseOffset
		{ GEN_INT   | GEN_INT_LIMIT12K     , TSF_REGION_OFFSET(modLfoToPitch                ) }, // 5 ModLfoToPitch
		{ GEN_INT   | GEN_INT_LIMIT12K     , TSF_REGION_OFFSET(vibLfoToPitch                ) }, // 6 VibLfoToPitch
		{ GEN_INT   | GEN_INT_LIMIT12K     , TSF_REGION_OFFSET(modEnvToPitch                ) }, // 7 ModEnvToPitch
		{ GEN_INT   | GEN_INT_LIMITFC      , TSF_REGION_OFFSET(initialFilterFc              ) }, // 8 InitialFilterFc
		{ GEN_INT   | GEN_INT_LIMITQ       , TSF_REGION_OFFSET(initialFilterQ               ) }, // 9 InitialFilterQ
		{ GEN_INT   | GEN_INT_LIMIT12K     , TSF_REGION_OFFSET(modLfoToFilterFc             ) }, //10 ModLfoToFilterFc
		{ GEN_INT   | GEN_INT_LIMIT12K     , TSF_REGION_OFFSET(modEnvToFilterFc             ) }, //11 ModEnvToFilterFc
		{ GEN_UINT_ADD15                   , TSF_REGION_OFFSET(end                          ) }, //12 EndAddrsCoarseOffset
		{ GEN_INT   | GEN_INT_LIMIT960     , TSF_REGION_OFFSET(modLfoToVolume               ) }, //13 ModLfoToVolume
		{ 0                                , (0                                                  ) }, //   Unused
		{ 0                                , (0                                                  ) }, //15 ChorusEffectsSend (unsupported)
		{ 0                                , (0                                                  ) }, //16 ReverbEffectsSend (unsupported)
		{ GEN_FLOAT | GEN_FLOAT_LIMITPAN   , TSF_REGION_OFFSET(pan                          ) }, //17 Pan
		{ 0                                , (0                                                  ) }, //   Unused
		{ 0                                , (0                                                  ) }, //   Unused
		{ 0                                , (0                                                  ) }, //   Unused
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K5K , TSF_REGION_OFFSET(delayModLFO                  ) }, //21 DelayModLFO
		{ GEN_INT   | GEN_INT_LIMIT16K4500 , TSF_REGION_OFFSET(freqModLFO                   ) }, //22 FreqModLFO
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K5K , TSF_REGION_OFFSET(delayVibLFO                  ) }, //23 DelayVibLFO
		{ GEN_INT   | GEN_INT_LIMIT16K4500 , TSF_REGION_OFFSET(freqVibLFO                   ) }, //24 FreqVibLFO
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K5K , TSF_REGION_OFFSET(modenv.delay                 ) }, //25 DelayModEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K8K , TSF_REGION_OFFSET(modenv.attack                ) }, //26 AttackModEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K5K , TSF_REGION_OFFSET(modenv.hold                  ) }, //27 HoldModEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K8K , TSF_REGION_OFFSET(modenv.decay                 ) }, //28 DecayModEnv
		{ GEN_FLOAT | GEN_FLOAT_MAX1000    , TSF_REGION_OFFSET(modenv.sustain               ) }, //29 SustainModEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K8K , TSF_REGION_OFFSET(modenv.release               ) }, //30 ReleaseModEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT1200  , TSF_REGION_OFFSET(modenv.keynumToHold          ) }, //31 KeynumToModEnvHold
		{ GEN_FLOAT | GEN_FLOAT_LIMIT1200  , TSF_REGION_OFFSET(modenv.keynumToDecay         ) }, //32 KeynumToModEnvDecay
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K5K , TSF_REGION_OFFSET(ampenv.delay                 ) }, //33 DelayVolEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K8K , TSF_REGION_OFFSET(ampenv.attack                ) }, //34 AttackVolEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K5K , TSF_REGION_OFFSET(ampenv.hold                  ) }, //35 HoldVolEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K8K , TSF_REGION_OFFSET(ampenv.decay                 ) }, //36 DecayVolEnv
		{ GEN_FLOAT | GEN_FLOAT_MAX1440    , TSF_REGION_OFFSET(ampenv.sustain               ) }, //37 SustainVolEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT12K8K , TSF_REGION_OFFSET(ampenv.release               ) }, //38 ReleaseVolEnv
		{ GEN_FLOAT | GEN_FLOAT_LIMIT1200  , TSF_REGION_OFFSET(ampenv.keynumToHold          ) }, //39 KeynumToVolEnvHold
		{ GEN_FLOAT | GEN_FLOAT_LIMIT1200  , TSF_REGION_OFFSET(ampenv.keynumToDecay         ) }, //40 KeynumToVolEnvDecay
		{ 0                                , (0                                                  ) }, //   Instrument (special)
		{ 0                                , (0                                                  ) }, //   Reserved
		{ GEN_KEYRANGE                     , (0                                                  ) }, //43 KeyRange
		{ GEN_VELRANGE                     , (0                                                  ) }, //44 VelRange
		{ GEN_UINT_ADD15                   , TSF_REGION_OFFSET(loop_start                   ) }, //45 StartloopAddrsCoarseOffset
		{ 0                                , (0                                                  ) }, //46 Keynum (special)
		{ 0                                , (0                                                  ) }, //47 Velocity (special)
		{ GEN_FLOAT | GEN_FLOAT_LIMITATTN  , TSF_REGION_OFFSET(attenuation                  ) }, //48 InitialAttenuation
		{ 0                                , (0                                                  ) }, //   Reserved
		{ GEN_UINT_ADD15                   , TSF_REGION_OFFSET(loop_end                     ) }, //50 EndloopAddrsCoarseOffset
		{ GEN_INT                          , TSF_REGION_OFFSET(transpose                    ) }, //51 CoarseTune
		{ GEN_INT                          , TSF_REGION_OFFSET(tune                         ) }, //52 FineTune
		{ 0                                , (0                                                  ) }, //   SampleID (special)
		{ GEN_LOOPMODE                     , TSF_REGION_OFFSET(loop_mode                    ) }, //54 SampleModes
		{ 0                                , (0                                                  ) }, //   Reserved
		{ GEN_INT                          , TSF_REGION_OFFSET(pitch_keytrack               ) }, //56 ScaleTuning
		{ GEN_GROUP                        , TSF_REGION_OFFSET(group                        ) }, //57 ExclusiveClass
		{ GEN_KEYCENTER                    , TSF_REGION_OFFSET(pitch_keycenter              ) }, //58 OverridingRootKey
	};
	#undef TSF_REGION_OFFSET
	if (amount)
	{
		unsigned char *field;
		if (genOper >= _GEN_MAX) return;
		field = (unsigned char*)region + genMetas[genOper].offset;
		switch (genMetas[genOper].mode & _GEN_TYPE_MASK)
		{
			case GEN_FLOAT:      *(float*)field  = amount->shortAmount;     return;
			case GEN_INT:        *(int*)field  = amount->shortAmount;     return;
			case GEN_UINT_ADD:   *(tsf_u32*)field += amount->shortAmount;     return;
			case GEN_UINT_ADD15: *(tsf_u32*)field += (tsf_s32)amount->shortAmount * 32768L; return;
			case GEN_KEYRANGE:   region->lokey = amount->range.lo; region->hikey = amount->range.hi; return;
			case GEN_VELRANGE:   region->lovel = amount->range.lo; region->hivel = amount->range.hi; return;
			case GEN_LOOPMODE:   region->loop_mode       = ((amount->wordAmount&3) == 3 ? TSF_LOOPMODE_SUSTAIN : ((amount->wordAmount&3) == 1 ? TSF_LOOPMODE_CONTINUOUS : TSF_LOOPMODE_NONE)); return;
			case GEN_GROUP:      region->group           = amount->wordAmount;  return;
			case GEN_KEYCENTER:  region->pitch_keycenter = amount->shortAmount; return;
		}
	}
	else //merge regions and clamp values
	{
		for (genOper = 0; genOper != _GEN_MAX; genOper++)
		{
			size_t offset = genMetas[genOper].offset;
			unsigned char *field = (unsigned char*)region + offset;
			const unsigned char *merge_field = (const unsigned char*)merge_region + offset;
			switch (genMetas[genOper].mode & _GEN_TYPE_MASK)
			{
				case GEN_FLOAT:
				{
					float *val = (float*)field, vfactor, vmin, vmax;
					*val += *(const float*)merge_field;
					switch (genMetas[genOper].mode & _GEN_LIMIT_MASK)
					{
						case GEN_FLOAT_LIMIT12K5K: vfactor =   1.0f; vmin = -12000.0f; vmax = 5000.0f; break;
						case GEN_FLOAT_LIMIT12K8K: vfactor =   1.0f; vmin = -12000.0f; vmax = 8000.0f; break;
						case GEN_FLOAT_LIMIT1200:  vfactor =   1.0f; vmin =  -1200.0f; vmax = 1200.0f; break;
						case GEN_FLOAT_LIMITPAN:   vfactor = 0.001f; vmin =     -0.5f; vmax =    0.5f; break;
						case GEN_FLOAT_LIMITATTN:  vfactor = 0.04f;  vmin =   -57.60f; vmax =  57.60f; break;
						case GEN_FLOAT_MAX1000:    vfactor =   1.0f; vmin =      0.0f; vmax = 1000.0f; break;
						case GEN_FLOAT_MAX1440:    vfactor =   1.0f; vmin =      0.0f; vmax = 1440.0f; break;
						default: continue;
					}
					*val *= vfactor;
					if      (*val < vmin) *val = vmin;
					else if (*val > vmax) *val = vmax;
					continue;
				}
				case GEN_INT:
				{
					int *val = (int*)field, vmin, vmax;
					tsf_s32 sum = (tsf_s32)*val + *(const int*)merge_field;
					switch (genMetas[genOper].mode & _GEN_LIMIT_MASK)
					{
						case GEN_INT_LIMIT12K:     vmin = -12000; vmax = 12000; break;
						case GEN_INT_LIMITFC:      vmin =   1500; vmax = 13500; break;
						case GEN_INT_LIMITQ:       vmin =      0; vmax =   960; break;
						case GEN_INT_LIMIT960:     vmin =   -960; vmax =   960; break;
						case GEN_INT_LIMIT16K4500: vmin = -16000; vmax =  4500; break;
						default: vmin = -32768L; vmax = 32767; break;
					}
					if      (sum < vmin) *val = vmin;
					else if (sum > vmax) *val = vmax;
					else *val = (int)sum;
					continue;
				}
				case GEN_UINT_ADD:
				{
					*(tsf_u32*)field += *(const tsf_u32*)merge_field;
					continue;
				}
			}
		}
	}
}

static void tsf_region_envtosecs(struct tsf_envelope* p, TSF_BOOL sustainIsGain)
{
	// EG times need to be converted from timecents to seconds.
	// Pin very short EG segments.  Timecents don't get to zero, and our EG is
	// happier with zero values.
	p->delay   = (p->delay   < -11950.0f ? 0.0f : tsf_timecents2Secsf(p->delay));
	p->attack  = (p->attack  < -11950.0f ? 0.0f : tsf_timecents2Secsf(p->attack));
	p->release = (p->release < -11950.0f ? 0.0f : tsf_timecents2Secsf(p->release));

	// If we have dynamic hold or decay times depending on key number we need
	// to keep the values in timecents so we can calculate it during startNote
	if (!p->keynumToHold)  p->hold  = (p->hold  < -11950.0f ? 0.0f : tsf_timecents2Secsf(p->hold));
	if (!p->keynumToDecay) p->decay = (p->decay < -11950.0f ? 0.0f : tsf_timecents2Secsf(p->decay));

	if (p->sustain < 0.0f) p->sustain = 0.0f;
	else if (sustainIsGain) p->sustain = tsf_decibelsToGain(-p->sustain / 10.0f);
	else p->sustain = 1.0f - (p->sustain / 1000.0f);
}

/* The terminal records supply each following index used by the zone walker. */
static int tsf_valid_hydra(const struct tsf_hydra* h)
{
    tsf_u32 i;
    if (h->phdrNum < 2 || h->phdrNum > 32767UL || h->instNum < 2 ||
        h->shdrNum < 2 || !h->pbagNum || !h->pgenNum || !h->ibagNum || !h->igenNum)
        return 0;
    for (i = 0; i < h->phdrNum; ++i)
        if (h->phdrs[i].presetBagNdx >= h->pbagNum ||
            (i && h->phdrs[i].presetBagNdx < h->phdrs[i-1].presetBagNdx)) return 0;
    for (i = 0; i < h->pbagNum; ++i)
        if (h->pbags[i].genNdx >= h->pgenNum ||
            (i && h->pbags[i].genNdx < h->pbags[i-1].genNdx)) return 0;
    for (i = 0; i < h->instNum; ++i)
        if (h->insts[i].instBagNdx >= h->ibagNum ||
            (i && h->insts[i].instBagNdx < h->insts[i-1].instBagNdx)) return 0;
    for (i = 0; i < h->ibagNum; ++i)
        if (h->ibags[i].instGenNdx >= h->igenNum ||
            (i && h->ibags[i].instGenNdx < h->ibags[i-1].instGenNdx)) return 0;
    for (i = 0; i + 1 < h->pgenNum; ++i)
        if (h->pgens[i].genOper == 41 && h->pgens[i].genAmount.wordAmount >= h->instNum - 1)
            return 0;
    for (i = 0; i + 1 < h->igenNum; ++i)
        if (h->igens[i].genOper == 53 && h->igens[i].genAmount.wordAmount >= h->shdrNum - 1)
            return 0;
    return 1;
}

static int tsf_load_presets(tsf* res, struct tsf_hydra *hydra, tsf_u32 fontSampleCount)
{
	enum { GenInstrument = 41, GenKeyRange = 43, GenVelRange = 44, GenSampleID = 53 };
	// Read each preset.
	struct tsf_hydra_phdr *pphdr, *pphdrMax;
	res->presetNum = hydra->phdrNum - 1;
	res->presets = (struct tsf_preset*)TSF_MALLOC((tsf_u32)res->presetNum * sizeof(struct tsf_preset));
	if (!res->presets) return 0;
	else { int i; for (i = 0; i != res->presetNum; i++) res->presets[i].regions = TSF_NULL; }
	for (pphdr = hydra->phdrs, pphdrMax = pphdr + hydra->phdrNum - 1; pphdr != pphdrMax; pphdr++)
	{
		int sortedIndex = 0, region_index = 0;
		struct tsf_hydra_phdr *otherphdr;
		struct tsf_preset* preset;
		struct tsf_hydra_pbag *ppbag, *ppbagEnd;
		struct tsf_region globalRegion;
		for (otherphdr = hydra->phdrs; otherphdr != pphdrMax; otherphdr++)
		{
			if (otherphdr == pphdr || otherphdr->bank > pphdr->bank) continue;
			else if (otherphdr->bank < pphdr->bank) sortedIndex++;
			else if (otherphdr->preset > pphdr->preset) continue;
			else if (otherphdr->preset < pphdr->preset) sortedIndex++;
			else if (otherphdr < pphdr) sortedIndex++;
		}

		preset = &res->presets[sortedIndex];
		TSF_MEMCPY(preset->presetName, pphdr->presetName, sizeof(preset->presetName));
		preset->presetName[sizeof(preset->presetName)-1] = '\0'; //should be zero terminated in source file but make sure
		preset->bank = pphdr->bank;
		preset->preset = pphdr->preset;
		preset->regionNum = 0;

		//count regions covered by this preset
		for (ppbag = hydra->pbags + pphdr->presetBagNdx, ppbagEnd = hydra->pbags + pphdr[1].presetBagNdx; ppbag != ppbagEnd; ppbag++)
		{
			unsigned char plokey = 0, phikey = 127, plovel = 0, phivel = 127;
			struct tsf_hydra_pgen *ppgen, *ppgenEnd; struct tsf_hydra_inst *pinst; struct tsf_hydra_ibag *pibag, *pibagEnd; struct tsf_hydra_igen *pigen, *pigenEnd;
			for (ppgen = hydra->pgens + ppbag->genNdx, ppgenEnd = hydra->pgens + ppbag[1].genNdx; ppgen != ppgenEnd; ppgen++)
			{
				if (ppgen->genOper == GenKeyRange) { plokey = ppgen->genAmount.range.lo; phikey = ppgen->genAmount.range.hi; continue; }
				if (ppgen->genOper == GenVelRange) { plovel = ppgen->genAmount.range.lo; phivel = ppgen->genAmount.range.hi; continue; }
				if (ppgen->genOper != GenInstrument) continue;
				if (ppgen->genAmount.wordAmount >= hydra->instNum - 1) continue;
				pinst = hydra->insts + ppgen->genAmount.wordAmount;
				for (pibag = hydra->ibags + pinst->instBagNdx, pibagEnd = hydra->ibags + pinst[1].instBagNdx; pibag != pibagEnd; pibag++)
				{
					unsigned char ilokey = 0, ihikey = 127, ilovel = 0, ihivel = 127;
					for (pigen = hydra->igens + pibag->instGenNdx, pigenEnd = hydra->igens + pibag[1].instGenNdx; pigen != pigenEnd; pigen++)
					{
						if (pigen->genOper == GenKeyRange) { ilokey = pigen->genAmount.range.lo; ihikey = pigen->genAmount.range.hi; continue; }
						if (pigen->genOper == GenVelRange) { ilovel = pigen->genAmount.range.lo; ihivel = pigen->genAmount.range.hi; continue; }
						if (pigen->genOper == GenSampleID && ihikey >= plokey && ilokey <= phikey && ihivel >= plovel && ilovel <= phivel) {
                            if (preset->regionNum == 32767) return 0;
                            preset->regionNum++;
                        }
					}
				}
			}
		}

		if (!preset->regionNum) continue;
		preset->regions = (struct tsf_region*)TSF_MALLOC((tsf_u32)preset->regionNum * sizeof(struct tsf_region));
		if (!preset->regions) return 0;
		tsf_region_clear(&globalRegion, TSF_TRUE);

		// Zones.
		for (ppbag = hydra->pbags + pphdr->presetBagNdx, ppbagEnd = hydra->pbags + pphdr[1].presetBagNdx; ppbag != ppbagEnd; ppbag++)
		{
			struct tsf_hydra_pgen *ppgen, *ppgenEnd; struct tsf_hydra_inst *pinst; struct tsf_hydra_ibag *pibag, *pibagEnd; struct tsf_hydra_igen *pigen, *pigenEnd;
			struct tsf_region presetRegion = globalRegion;
			int hadGenInstrument = 0;

			// Generators.
			for (ppgen = hydra->pgens + ppbag->genNdx, ppgenEnd = hydra->pgens + ppbag[1].genNdx; ppgen != ppgenEnd; ppgen++)
			{
				// Instrument.
				if (ppgen->genOper == GenInstrument)
				{
					struct tsf_region instRegion;
					tsf_u16 whichInst = ppgen->genAmount.wordAmount;
					if (whichInst >= hydra->instNum - 1) continue;

					tsf_region_clear(&instRegion, TSF_FALSE);
					pinst = &hydra->insts[whichInst];
					for (pibag = hydra->ibags + pinst->instBagNdx, pibagEnd = hydra->ibags + pinst[1].instBagNdx; pibag != pibagEnd; pibag++)
					{
						// Generators.
						struct tsf_region zoneRegion = instRegion;
						int hadSampleID = 0;
						for (pigen = hydra->igens + pibag->instGenNdx, pigenEnd = hydra->igens + pibag[1].instGenNdx; pigen != pigenEnd; pigen++)
						{
							if (pigen->genOper == GenSampleID)
							{
								struct tsf_hydra_shdr* pshdr;

								//preset region key and vel ranges are a filter for the zone regions
								if (zoneRegion.hikey < presetRegion.lokey || zoneRegion.lokey > presetRegion.hikey) continue;
								if (zoneRegion.hivel < presetRegion.lovel || zoneRegion.lovel > presetRegion.hivel) continue;
								if (presetRegion.lokey > zoneRegion.lokey) zoneRegion.lokey = presetRegion.lokey;
								if (presetRegion.hikey < zoneRegion.hikey) zoneRegion.hikey = presetRegion.hikey;
								if (presetRegion.lovel > zoneRegion.lovel) zoneRegion.lovel = presetRegion.lovel;
								if (presetRegion.hivel < zoneRegion.hivel) zoneRegion.hivel = presetRegion.hivel;

								//sum regions
								tsf_region_operator(&zoneRegion, 0, TSF_NULL, &presetRegion);

								// EG times need to be converted from timecents to seconds.
								tsf_region_envtosecs(&zoneRegion.ampenv, TSF_TRUE);
								tsf_region_envtosecs(&zoneRegion.modenv, TSF_FALSE);

								// LFO times need to be converted from timecents to seconds.
								zoneRegion.delayModLFO = (zoneRegion.delayModLFO < -11950.0f ? 0.0f : tsf_timecents2Secsf(zoneRegion.delayModLFO));
								zoneRegion.delayVibLFO = (zoneRegion.delayVibLFO < -11950.0f ? 0.0f : tsf_timecents2Secsf(zoneRegion.delayVibLFO));

								// Fixup sample positions
								if (pigen->genAmount.wordAmount >= hydra->shdrNum - 1 ||
                                    region_index >= preset->regionNum) return 0;
                                pshdr = &hydra->shdrs[pigen->genAmount.wordAmount];
								zoneRegion.offset += pshdr->start;
								zoneRegion.end += pshdr->end;
								zoneRegion.loop_start += pshdr->startLoop;
								zoneRegion.loop_end += pshdr->endLoop;
								if (pshdr->endLoop > 0) zoneRegion.loop_end -= 1;
								if (zoneRegion.loop_end > fontSampleCount) zoneRegion.loop_end = fontSampleCount;
								if (zoneRegion.pitch_keycenter == -1) zoneRegion.pitch_keycenter = pshdr->originalPitch;
								zoneRegion.pitch_correction = pshdr->pitchCorrection;
								zoneRegion.sample_rate = pshdr->sampleRate;
								if (zoneRegion.end && zoneRegion.end < fontSampleCount) zoneRegion.end++;
								else zoneRegion.end = fontSampleCount;

								preset->regions[region_index] = zoneRegion;
								region_index++;
								hadSampleID = 1;
							}
							else tsf_region_operator(&zoneRegion, pigen->genOper, &pigen->genAmount, TSF_NULL);
						}

						// Handle instrument's global zone.
						if (pibag == hydra->ibags + pinst->instBagNdx && !hadSampleID)
							instRegion = zoneRegion;

						// Modulators (TODO)
						//if (ibag->instModNdx < ibag[1].instModNdx) addUnsupportedOpcode("any modulator");
					}
					hadGenInstrument = 1;
				}
				else tsf_region_operator(&presetRegion, ppgen->genOper, &ppgen->genAmount, TSF_NULL);
			}

			// Modulators (TODO)
			//if (pbag->modNdx < pbag[1].modNdx) addUnsupportedOpcode("any modulator");

			// Handle preset's global zone.
			if (ppbag == hydra->pbags + pphdr->presetBagNdx && !hadGenInstrument)
				globalRegion = presetRegion;
		}
        preset->regionNum = region_index;
	}
	return 1;
}

TSFDEF tsf* tsf_load(struct tsf_stream* stream)
{
	tsf* res = TSF_NULL;
	struct tsf_riffchunk chunkHead;
	struct tsf_riffchunk chunkList;
	struct tsf_hydra hydra;
	tsf_u32 smplCount = 0;

	if (!tsf_riffchunk_read(TSF_NULL, &chunkHead, stream) || !TSF_FourCCEquals(chunkHead.id, "sfbk"))
	{
		//if (e) *e = TSF_INVALID_NOSF2HEADER;
		return res;
	}

	// Read hydra and locate sample data.
	TSF_MEMSET(&hydra, 0, sizeof(hydra));
	while (tsf_riffchunk_read(&chunkHead, &chunkList, stream))
	{
		struct tsf_riffchunk chunk;
		if (TSF_FourCCEquals(chunkList.id, "pdta"))
		{
			while (tsf_riffchunk_read(&chunkList, &chunk, stream))
			{
				#define HandleChunk(chunkName) (TSF_FourCCEquals(chunk.id, #chunkName) && !(chunk.size % chunkName##SizeInFile)) \
					{ \
						tsf_u32 num = chunk.size / chunkName##SizeInFile, i; \
						if (hydra.chunkName##s || !num || num > 65536UL) goto load_failed; \
						hydra.chunkName##Num = num; \
						hydra.chunkName##s = (struct tsf_hydra_##chunkName*)TSF_MALLOC((tsf_u32)num * sizeof(struct tsf_hydra_##chunkName)); \
						if (!hydra.chunkName##s) goto load_failed; \
						for (i = 0; i < num; ++i) \
                            if (!tsf_hydra_read_##chunkName(&hydra.chunkName##s[i], stream)) goto load_failed; \
					}
				enum
				{
					phdrSizeInFile = 38, pbagSizeInFile =  4, pmodSizeInFile = 10,
					pgenSizeInFile =  4, instSizeInFile = 22, ibagSizeInFile =  4,
					imodSizeInFile = 10, igenSizeInFile =  4, shdrSizeInFile = 46
				};
				if      HandleChunk(phdr) else if HandleChunk(pbag) else if HandleChunk(pmod)
				else if HandleChunk(pgen) else if HandleChunk(inst) else if HandleChunk(ibag)
				else if HandleChunk(imod) else if HandleChunk(igen) else if HandleChunk(shdr)
				else stream->skip(stream->data, chunk.size);
				#undef HandleChunk
			}
		}
		else if (TSF_FourCCEquals(chunkList.id, "sdta"))
		{
			while (tsf_riffchunk_read(&chunkList, &chunk, stream))
			{
				if (TSF_FourCCEquals(chunk.id, "smpl") && !smplCount && chunk.size >= sizeof(int16_t))
				{
					if ((chunk.size & 1U) || !stream->read_samples(stream->data, chunk.size)) goto load_failed;
					smplCount = chunk.size / sizeof(int16_t);
				}
				else stream->skip(stream->data, chunk.size);
			}
		}
		else stream->skip(stream->data, chunkList.size);
	}
	if (smplCount && tsf_valid_hydra(&hydra))
	{
		res = (tsf*)TSF_MALLOC(sizeof(tsf));
		if (!res) goto load_failed;
		TSF_MEMSET(res, 0, sizeof(tsf));
		if (!tsf_load_presets(res, &hydra, smplCount)) goto load_failed;
		res->sampleCount = smplCount;
	}
	if (0)
	{
		load_failed:
		tsf_close(res);
		res = TSF_NULL;
	}
	TSF_FREE(hydra.phdrs); TSF_FREE(hydra.pbags); TSF_FREE(hydra.pmods);
	TSF_FREE(hydra.pgens); TSF_FREE(hydra.insts); TSF_FREE(hydra.ibags);
	TSF_FREE(hydra.imods); TSF_FREE(hydra.igens); TSF_FREE(hydra.shdrs);
	return res;
}

TSFDEF void tsf_close(tsf* f)
{
    int i;
    if (!f) return;
    if (f->presets) {
        for (i = 0; i < f->presetNum; ++i) TSF_FREE(f->presets[i].regions);
        TSF_FREE(f->presets);
    }
    TSF_FREE(f);
}
#endif /* TSF_IMPLEMENTATION */
