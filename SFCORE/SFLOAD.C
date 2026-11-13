/* SoundFont loading and coefficient preparation. Task context only. */
#include "SFCORE.H"
#include <math.h>
#include <stdlib.h>
#include <string.h>

#ifdef __I86__
#if !defined(__HUGE__)
#error Compile the Win16 loader with -mh.
#endif

typedef struct {
    uint32_t size;
    HGLOBAL handle;
    uint16_t pinned;
} SfAllocation;
typedef char SfAllocationSize[(sizeof(SfAllocation) == 8) ? 1 : -1];

/* Watcom supplies CX:BX and DI:SI for these 32-bit operands.
   DPMI 0600h/0601h take the address in BX:CX and length in SI:DI.
   Restore the register pairs after the interrupt, preserving carry. */
static unsigned sf_lock_linear(unsigned command, uint32_t base, uint32_t bytes);
#pragma aux sf_lock_linear = \
    "xchg bx,cx" "xchg si,di" "int 31h" \
    "xchg si,di" "xchg bx,cx" "sbb ax,ax" "inc ax" \
    parm [ax] [bx cx] [si di] value [ax] modify exact [ax];

static void *sf_alloc(uint32_t bytes)
{
    SfAllocation *header;
    HGLOBAL handle;
    if (!bytes || bytes > 0x7ffffff0UL) return 0;
    handle = GlobalAlloc(GMEM_MOVEABLE | GMEM_SHARE | GMEM_ZEROINIT,
                         bytes + sizeof(SfAllocation));
    if (!handle) return 0;
    header = (SfAllocation *)GlobalLock(handle);
    if (!header) { GlobalFree(handle); return 0; }
    if (FP_OFF(header)) {
        GlobalUnlock(handle);
        GlobalFree(handle);
        return 0;
    }
    header->size = bytes + sizeof(SfAllocation);
    header->handle = handle;
    return header + 1;
}

static uint32_t sf_linear(const void *ptr)
{
    return GetSelectorBase(FP_SEG(ptr)) + FP_OFF(ptr);
}

static int sf_pin(void *ptr)
{
    SfAllocation *header = (SfAllocation *)ptr - 1;
    header->pinned = sf_lock_linear(0x0600U, sf_linear(header), header->size);
    return header->pinned != 0;
}

static void sf_free(void *ptr)
{
    SfAllocation *header;
    HGLOBAL handle;
    if (!ptr) return;
    header = (SfAllocation *)ptr - 1;
    handle = header->handle;
    if (header->pinned)
        sf_lock_linear(0x0601U, sf_linear(header), header->size);
    GlobalUnlock(handle);
    GlobalFree(handle);
}

static void *sf_memcpy(void *dst, const void *src, uint32_t bytes)
{
    if (bytes) hmemcpy(dst, src, (long)bytes);
    return dst;
}

static void *sf_memset(void *ptr, int byte, uint32_t bytes)
{
    unsigned char *p = (unsigned char *)ptr;
    while (bytes) {
        uint32_t room = 65536UL - FP_OFF(p);
        unsigned n = bytes > 0x7f00U ? 0x7f00U : (unsigned)bytes;
        if (room < n) n = (unsigned)room;
        _fmemset((void __far *)p, byte, n);
        p += n;
        bytes -= n;
    }
    return ptr;
}

#define SF_FILE HFILE
#define SF_FILE_BAD HFILE_ERROR
#define sf_file_open(path) _lopen(path, OF_READ | OF_SHARE_DENY_NONE)
#define sf_file_close(file) _lclose(file)
#define sf_file_seek(file, offset, origin) _llseek(file, offset, origin)
#else
#include <stdio.h>

static void *sf_alloc(uint32_t bytes) { return calloc(1, bytes); }
static int sf_pin(void *ptr) { return ptr != 0; }
#define sf_free free
#define sf_memset memset
#define sf_memcpy memcpy
#define SF_FILE FILE *
#define SF_FILE_BAD NULL
#define sf_file_open(path) fopen(path, "rb")
#define sf_file_close(file) fclose(file)
static long sf_file_seek(FILE *file, long offset, int origin)
{
    if (fseek(file, offset, origin)) return -1;
    return ftell(file);
}
#endif

#define TSF_MALLOC sf_alloc
#define TSF_FREE sf_free
#define TSF_MEMCPY sf_memcpy
#define TSF_MEMSET sf_memset
#define TSF_POWF(a,b) ((float)pow(a,b))
#define TSF_STATIC
#define TSF_IMPLEMENTATION
#include "TSF16.H"

typedef struct {
    SF_FILE handle;
    uint32_t remaining;
    SfBank SF_FAR *bank;
    int error;
} SfFile;

#define SF_SAMPLE_BLOCK_BYTES 0x400000UL
#define SF_SAMPLE_PAGE_BYTES 65536UL
#ifdef __I86__
/* sf_alloc puts its header at selector offset zero. Align the PCM so each
   64 KiB logical page starts at offset zero, including across blocks. */
#define SF_SAMPLE_PAD (SF_SAMPLE_PAGE_BYTES - sizeof(SfAllocation))
#else
#define SF_SAMPLE_PAD 0
#endif

static uint32_t sf_file_read(void *data, void *ptr, uint32_t size)
{
    SfFile *file = (SfFile *)data;
    long got;
    if (size > file->remaining) {
        file->error = SF_READ_ERROR;
        return 0;
    }
#ifdef __I86__
    got = _hread(file->handle, ptr, (long)size);
#else
    got = (long)fread(ptr, 1, size, file->handle);
#endif
    if (got != (long)size) {
        file->error = SF_READ_ERROR;
        return 0;
    }
    file->remaining -= size;
    return size;
}

static int sf_file_skip(void *data, uint32_t size)
{
    SfFile *file = (SfFile *)data;
    if (size > file->remaining || sf_file_seek(file->handle, (long)size, 1) < 0) {
        file->error = SF_READ_ERROR;
        return 0;
    }
    file->remaining -= size;
    return 1;
}

static int sf_load_sample_blocks(SfFile *file, uint32_t bytes)
{
    SfBank SF_FAR *bank = file->bank;
    uint32_t remaining, page_bytes, n, read_bytes, offset;
    unsigned page = 0, blocks;
    unsigned char *allocation, *pcm;

    if (bytes > file->remaining) return SF_READ_ERROR;
    /* Include a zero guard sample for interpolation at the end of the bank. */
    remaining = bytes + sizeof(int16_t);
    page_bytes = ((remaining - 1) / SF_SAMPLE_PAGE_BYTES + 1) * sizeof(SfSamplePage);
    if (page_bytes > 65520UL) return SF_REGION_ERROR;
    blocks = (unsigned)((remaining - 1) / SF_SAMPLE_BLOCK_BYTES + 1);
    bank->sample_pages = (SfSamplePage SF_FAR *)sf_alloc(page_bytes);
    bank->sample_blocks = (SfSampleBlock SF_FAR *)sf_alloc((uint32_t)blocks * sizeof(SfSampleBlock));
    if (!bank->sample_pages || !bank->sample_blocks) return SF_MEMORY_ERROR;

    while (remaining) {
        n = remaining > SF_SAMPLE_BLOCK_BYTES ? SF_SAMPLE_BLOCK_BYTES : remaining;
        allocation = (unsigned char *)sf_alloc(n + SF_SAMPLE_PAD);
        if (!allocation) return SF_MEMORY_ERROR;
        bank->sample_blocks[bank->sample_block_count++] = allocation;
        pcm = allocation + SF_SAMPLE_PAD;
#ifdef __I86__
        if (FP_OFF(pcm)) return SF_REGION_ERROR;
#endif
        read_bytes = bytes < n ? bytes : n;
        if (read_bytes && sf_file_read(file, pcm, read_bytes) != read_bytes) return SF_READ_ERROR;
        for (offset = 0; offset < n; offset += SF_SAMPLE_PAGE_BYTES)
            bank->sample_pages[page++] = (SfSamplePage)(pcm + offset);
        if (!sf_pin(allocation)) return SF_PIN_ERROR;
        bytes -= read_bytes;
        remaining -= n;
    }
    return sf_pin(bank->sample_pages) ? SF_OK : SF_PIN_ERROR;
}

static int sf_file_samples(void *data, uint32_t bytes)
{
    SfFile *file = (SfFile *)data;
    int result = sf_load_sample_blocks(file, bytes);
    if (result == SF_OK) return 1;
    file->error = result;
    return 0;
}

static tsf *sf_read_font(const char SF_FAR *path, SfBank SF_FAR *bank, int *result)
{
    SfFile file;
    struct tsf_stream stream;
    tsf *font = 0;
    long length;
    file.handle = sf_file_open(path);
    if (file.handle == SF_FILE_BAD) { *result = SF_OPEN_ERROR; return 0; }
    length = sf_file_seek(file.handle, 0, 2);
    file.error = SF_FILE_ERROR;
    if (length < 0) file.error = SF_READ_ERROR;
    else if (length >= 12 && length <= 0x7ffffff0L) {
        if (sf_file_seek(file.handle, 0, 0) != 0) file.error = SF_READ_ERROR;
        else {
            file.remaining = (uint32_t)length;
            file.bank = bank;
            file.error = 0;
            stream.data = &file;
            stream.read = sf_file_read;
            stream.skip = sf_file_skip;
            stream.read_samples = sf_file_samples;
            font = tsf_load(&stream);
            if (file.error) { tsf_close(font); font = 0; }
        }
    }
    sf_file_close(file.handle);
    *result = file.error ? file.error : SF_FILE_ERROR;
    return font;
}

static int32_t sf_quantize(double value, int32_t lo, int32_t hi)
{
    if (value <= lo) return lo;
    if (value >= hi) return hi;
    return (int32_t)(value < 0 ? value - 0.5 : value + 0.5);
}

static uint32_t sf_frames(double seconds, unsigned rate)
{
    return (uint32_t)sf_quantize(seconds * rate, 0, SF_TIME_MAX);
}

static void sf_prepare_env(SfEnvelopeSpec *out, const struct tsf_envelope *env, unsigned rate)
{
    double sustain = env->sustain;
    double depth;
    out->delay = sf_frames(env->delay, rate);
    out->attack = sf_frames(env->attack, rate);
    out->hold = env->keynumToHold ? 0 : sf_frames(env->hold, rate);
    out->decay = env->keynumToDecay ? 0 : sf_frames(env->decay, rate);
    out->release = sf_frames(env->release, rate);
    if (!out->release) out->release = rate / 100;
    out->hold_track = (int16_t)sf_quantize(env->keynumToHold, -32768L, 32767);
    out->decay_track = (int16_t)sf_quantize(env->keynumToDecay, -32768L, 32767);
    out->hold_timecents = (int16_t)sf_quantize(env->hold, -32768L, 32767);
    out->decay_timecents = (int16_t)sf_quantize(env->decay, -32768L, 32767);
    out->sustain = (uint16_t)sf_quantize(sustain * SF_GAIN_ONE, 0, SF_GAIN_ONE);
    depth = sustain > 0 ? -log(sustain) : 9.226;
    out->decay_scale = (uint32_t)sf_quantize(depth / 9.226 * SF_GAIN_ONE, 0, 65536L);
    out->decay_cb = (uint16_t)sf_quantize(depth * 200.0 / log(10.0), 0, 1600);
}

static uint32_t sf_lfo_step(int cents, unsigned rate)
{
    double hz = 8.176 * pow(2.0, cents / 1200.0);
    return (uint32_t)sf_quantize(hz * SF_PHASE_ONE / rate, 0, 0x400000L);
}

static void sf_prepare_filter(SfRegion *out, const struct tsf_region *r, unsigned rate)
{
    double fc = 8.176 * pow(2.0, r->initialFilterFc / 1200.0) / rate;
    double damping = SF_FILTER_DAMPING_FLAT * pow(10.0, -r->initialFilterQ / 200.0);
    double k, kk, norm;
    out->filter_fc = (int16_t)r->initialFilterFc;
    out->filter_q = sf_quantize(damping, 0, SF_FILTER_DAMPING_FLAT);
    if (r->initialFilterFc > 13500 || fc >= 0.499) {
        out->filter.a0 = out->filter.b1 = out->filter.b2 = 0;
        return;
    }
    k = tan(3.141592653589793 * fc);
    kk = k * k;
    damping = k * out->filter_q / 65536.0;
    norm = 268435456.0 / (1 + damping + kk);
    out->filter.a0 = sf_quantize(kk * norm, 1, 0x10000000L);
    out->filter.b1 = sf_quantize(2 * (kk - 1) * norm, -0x20000000L, 0x20000000L);
    out->filter.b2 = sf_quantize((1 - damping + kk) * norm, -0x10000000L, 0x10000000L);
}

static void sf_prepare_region(SfRegion *out, const struct tsf_region *r, unsigned rate)
{
    double pitch = r->transpose * 100.0 + r->tune
                 + (r->pitch_correction - r->pitch_keycenter * 100.0)
                   * r->pitch_keytrack / 100.0;
    pitch += 1200.0 * log(r->sample_rate / (double)rate) / log(2.0);
    out->pitch_base = (int16_t)sf_quantize(pitch, -32768L, 32767);
    out->pitch_track = (int16_t)r->pitch_keytrack;
    out->start = r->offset;
    out->end = r->end;
    out->loop_mode = (uint8_t)r->loop_mode;
    out->loop_start = r->loop_start;
    out->loop_end = r->loop_mode && r->loop_start >= r->offset &&
                    r->loop_start < r->loop_end && r->loop_end < r->end ? r->loop_end : 0;
    out->pan = (int16_t)sf_quantize(r->pan * SF_GAIN_ONE, -16384, 16384);
    /* Keep signed attenuation until controller and velocity gains are applied.
       The cap retains the filter's DC gain compensation at full note volume. */
    out->attenuation = (int16_t)sf_quantize(r->attenuation * 10.0 + r->initialFilterQ * 0.5,
                                            -576, 1500);
    out->filter_gain_limit = (uint16_t)sf_quantize(
        pow(10.0, -r->initialFilterQ / 400.0) * SF_GAIN_ONE, 0, SF_GAIN_ONE);
    out->group = r->group;
    out->low_key = r->lokey; out->high_key = r->hikey;
    out->low_vel = r->lovel; out->high_vel = r->hivel;
    out->mod_env_pitch = (int16_t)r->modEnvToPitch;
    out->mod_env_filter = (int16_t)r->modEnvToFilterFc;
    out->mod_lfo_filter = (int16_t)r->modLfoToFilterFc;
    out->mod_lfo_pitch = (int16_t)r->modLfoToPitch;
    out->mod_lfo_gain = (int16_t)r->modLfoToVolume;
    out->vib_lfo_pitch = (int16_t)r->vibLfoToPitch;
    out->mod_delay = sf_frames(r->delayModLFO, rate);
    out->vib_delay = sf_frames(r->delayVibLFO, rate);
    out->mod_step = sf_lfo_step(r->freqModLFO, rate);
    out->vib_step = sf_lfo_step(r->freqVibLFO, rate);
    sf_prepare_env(&out->amp, &r->ampenv, rate);
    sf_prepare_env(&out->mod, &r->modenv, rate);
    sf_prepare_filter(out, r, rate);
}

static int sf_alloc_preset(SfPreset *out, const struct tsf_preset *p,
                           uint32_t samples, unsigned rate)
{
    uint32_t bytes = (uint32_t)p->regionNum * sizeof(SfRegion);
    int i;
    const struct tsf_region *r;
    out->bank = p->bank;
    out->program = p->preset;
    if (!bytes) return SF_OK;
    if (bytes > 65520UL) return SF_REGION_ERROR;
    out->regions = (SfRegion *)sf_alloc(bytes);
    if (!out->regions) return SF_MEMORY_ERROR;
    for (i = 0; i < p->regionNum; ++i) {
        r = &p->regions[i];
        if (!r->sample_rate || r->offset >= r->end || r->end > samples) continue;
        sf_prepare_region(&out->regions[out->count], r, rate);
        ++out->count;
    }
    if (!sf_pin(out->regions)) return SF_PIN_ERROR;
    return SF_OK;
}

void SF_FAR sf_unload(SfBank SF_FAR *bank)
{
    unsigned i;
    if (bank->presets) {
        for (i = 0; i < bank->preset_count; ++i) sf_free(bank->presets[i].regions);
        sf_free(bank->presets);
    }
    for (i = 0; i < bank->sample_block_count; ++i) sf_free(bank->sample_blocks[i]);
    sf_free(bank->sample_blocks);
    sf_free(bank->sample_pages);
    sf_memset(bank, 0, sizeof(*bank));
}

int SF_FAR sf_load(const char SF_FAR *path, SfBank SF_FAR *bank, unsigned rate)
{
    tsf *font;
    int i, result = SF_FILE_ERROR;
    uint32_t bytes;
    int regions = 0;
#ifdef __I86__
    if (!(GetWinFlags() & WF_80x87)) return SF_FILE_ERROR;
#endif
    font = sf_read_font(path, bank, &result);
    if (!font) { sf_unload(bank); return result; }

    result = SF_REGION_ERROR;
    bytes = (uint32_t)font->presetNum * sizeof(SfPreset);
    if (!bytes || bytes > 65520UL) goto done;
    bank->presets = (SfPreset *)sf_alloc(bytes);
    if (!bank->presets) { result = SF_MEMORY_ERROR; goto done; }
    bank->preset_count = (uint16_t)font->presetNum;
    for (i = 0; i < font->presetNum; ++i) {
        result = sf_alloc_preset(&bank->presets[i], &font->presets[i], font->sampleCount, rate);
        if (result != SF_OK) goto done;
        if (bank->presets[i].count) regions = 1;
    }
    if (!regions) { result = SF_REGION_ERROR; goto done; }
    result = sf_pin(bank->presets) ? SF_OK : SF_PIN_ERROR;
done:
    tsf_close(font);
    if (result != SF_OK) sf_unload(bank);
    return result;
}
