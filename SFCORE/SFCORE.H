#ifndef SFCORE_H
#define SFCORE_H

#include <stdint.h>

#ifdef __I86__
#include <windows.h>
#include <i86.h>
#define SF_FAR __far
#else
#define SF_FAR
#endif

#define SF_DEFAULT_RATE 44100U
#define SF_NATIVE_RATE 48000U
#define SF_MIN_VOICES 32
#define SF_MAX_VOICES 128
#define SF_MAX_FRAMES 512
#define SF_PHASE_ONE 0x1000000UL
#define SF_PHASE_MASK 0xffffffUL
#define SF_GAIN_ONE 32768L
#define SF_FILTER_DAMPING_FLAT 92682L  /* sqrt(2) in Q16 */
#define SF_TIME_MAX 0xffffffUL

enum {
    SF_OK = 1, SF_FILE_ERROR = 2, SF_REGION_ERROR, SF_MEMORY_ERROR, SF_PIN_ERROR,
    SF_OPEN_ERROR, SF_READ_ERROR
};

typedef struct {
    uint32_t delay, attack, hold, decay, release;
    int16_t hold_track, decay_track;
    int16_t hold_timecents, decay_timecents;
    uint16_t sustain, decay_cb;
    uint32_t decay_scale;
} SfEnvelopeSpec;

typedef struct {
    int32_t a0, b1, b2;
} SfFilter;

typedef struct {
    uint32_t start, end, loop_start, loop_end;
    SfEnvelopeSpec amp, mod;
    uint32_t mod_delay, vib_delay, mod_step, vib_step;
    SfFilter filter;
    int32_t filter_q;
    int16_t pitch_base, pitch_track, pan, attenuation;
    int16_t filter_fc, mod_env_pitch, mod_env_filter, mod_lfo_filter;
    int16_t mod_lfo_pitch, mod_lfo_gain, vib_lfo_pitch;
    uint16_t group, filter_gain_limit;
    uint8_t low_key, high_key, low_vel, high_vel, loop_mode;
} SfRegion;

typedef struct {
    SfRegion SF_FAR *regions;
    uint16_t count, bank, program;
} SfPreset;

typedef const int16_t SF_FAR *SfSamplePage;
typedef void SF_FAR *SfSampleBlock;

typedef struct {
    SfPreset SF_FAR *presets;
    SfSamplePage SF_FAR *sample_pages;
    SfSampleBlock SF_FAR *sample_blocks;
    uint16_t preset_count, sample_block_count;
} SfBank;

int SF_FAR sf_load(const char SF_FAR *path, SfBank SF_FAR *bank, unsigned rate);
void SF_FAR sf_unload(SfBank SF_FAR *bank);

#ifndef __I86__
int sf_host_open(const char *path, unsigned voices);
int sf_host_open_rate(const char *path, unsigned voices, unsigned rate);
void sf_host_close(void);
unsigned sf_host_cmd(unsigned command, unsigned value, uintptr_t data);
unsigned sf_host_voices(void);
#endif

#endif
