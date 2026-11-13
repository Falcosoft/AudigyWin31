/* Resident fixed-point renderer. The Win16 gateway supplies a private stack. */
#include "SFCORE.H"
#include "SFMATH.H"

enum { SF_DELAY, SF_ATTACK, SF_HOLD, SF_DECAY, SF_SUSTAIN, SF_RELEASE, SF_DONE };
enum { SF_EFFECT_FRAMES = 32, SF_MAX_HEADROOM_DB = 24 };
enum { SF_MODE_GM, SF_MODE_GS, SF_MODE_XG, SF_MODE_GM2 };

typedef struct {
    uint32_t left, phase, step;
    uint16_t start_gain;
    uint8_t stage;
} SfEnvelope;

typedef struct {
    uint32_t phase, delay;
} SfLfo;

typedef struct {
    const SfRegion SF_FAR *region;
    uint32_t pos, frac, step, serial, loop_end;
    int32_t base_pitch, last_pitch, gain, velocity_gain;
    int32_t filter_fc, z1, z2;
    SfFilter filter;
    SfEnvelope amp, mod;
    SfLfo mod_lfo, vib_lfo;
    uint16_t preset;
    uint8_t channel, key, held, quick;
} SfVoice;

typedef struct {
    uint16_t preset, bank, pitch, pan, volume, expression, modulation, rpn, data;
    int16_t coarse, fine, range;
    uint16_t program_bank;
    uint8_t sustain, pressure, program, drum;
    int32_t pitch_cents, gain, vibrato;
} SfChannel;

static SfBank sf_bank;
static SfVoice sf_voices[SF_MAX_VOICES];
static SfChannel sf_channels[16];
static int32_t sf_mix[SF_MAX_FRAMES * 2];
static uint32_t sf_serial;
static unsigned sf_limit;
static unsigned sf_ready;
static unsigned sf_mode;
static unsigned sf_headroom_gain = SF_GAIN_ONE;
static unsigned sf_output_gain;
static unsigned sf_rate = SF_DEFAULT_RATE;
static unsigned sf_quick_release;
static const int32_t *sf_tan_values;

static uint32_t sf_key_time(uint32_t plain, int timecents, int track, int key)
{
    int32_t tc;
    if (!track) return plain;
    tc = timecents + (int32_t)track * (60 - key);
    if (tc < -10000L) return 0;
    return (uint32_t)sf_mul_shift(sf_ratio(tc), sf_rate, 24);
}

static void sf_env_start(SfEnvelope *e, unsigned stage, uint32_t frames)
{
    e->stage = (uint8_t)stage;
    e->left = frames;
    e->phase = 0;
    e->step = frames ? (uint32_t)sf_div(SF_PHASE_ONE, frames) : 0;
}

static void sf_env_next(SfEnvelope *e, const SfEnvelopeSpec SF_FAR *s, int key, int amp)
{
    uint32_t frames;
    for (;;) {
        switch (e->stage) {
        case SF_DELAY:
            sf_env_start(e, SF_ATTACK, s->attack);
            break;
        case SF_ATTACK:
            frames = sf_key_time(s->hold, s->hold_timecents, s->hold_track, key);
            sf_env_start(e, SF_HOLD, frames);
            break;
        case SF_HOLD:
            frames = sf_key_time(s->decay, s->decay_timecents, s->decay_track, key);
            if (amp)
                frames = (uint32_t)sf_mul_shift(frames, s->decay_scale, 15);
            else
                frames = (uint32_t)sf_mul_shift(frames, SF_GAIN_ONE - s->sustain, 15);
            if (frames > SF_TIME_MAX) frames = SF_TIME_MAX;
            sf_env_start(e, SF_DECAY, frames);
            break;
        case SF_DECAY:
            sf_env_start(e, SF_SUSTAIN, 0);
            return;
        default:
            sf_env_start(e, SF_DONE, 0);
            return;
        }
        if (e->left) return;
    }
}

static int32_t sf_env_level(const SfEnvelope *e, const SfEnvelopeSpec SF_FAR *s, int amp)
{
    int32_t progress = e->phase >> 9;
    switch (e->stage) {
    case SF_ATTACK:
        if (amp) return progress;
        progress = SF_GAIN_ONE - progress;
        return SF_GAIN_ONE - sf_mul_shift(progress, progress, 15);
    case SF_HOLD:
        return SF_GAIN_ONE;
    case SF_DECAY:
        if (amp) return sf_gain(sf_mul_shift(progress, s->decay_cb, 15));
        return SF_GAIN_ONE - sf_mul_shift(progress, SF_GAIN_ONE - s->sustain, 15);
    case SF_SUSTAIN:
        return s->sustain;
    case SF_RELEASE:
        if (amp) return sf_mul_shift(e->start_gain, sf_gain((progress * 802L) >> 15), 15);
        return sf_mul_shift(e->start_gain, SF_GAIN_ONE - progress, 15);
    }
    return 0;
}

static void sf_env_advance(SfEnvelope *e, const SfEnvelopeSpec SF_FAR *s,
                           unsigned frames, int key, int amp)
{
    if (e->left) {
        e->phase += e->step * frames;
        e->left -= frames;
        if (!e->left) sf_env_next(e, s, key, amp);
    }
}

static void sf_release(SfVoice *v, int quick)
{
    const SfRegion SF_FAR *r = v->region;
    if (v->amp.stage >= SF_RELEASE && (!quick || v->quick)) return;
    v->held = 0;
    v->quick = (uint8_t)quick;
    v->amp.start_gain = (uint16_t)sf_env_level(&v->amp, &r->amp, 1);
    if (!v->amp.start_gain) { v->region = 0; return; }
    v->mod.start_gain = (uint16_t)sf_env_level(&v->mod, &r->mod, 0);
    sf_env_start(&v->amp, SF_RELEASE, quick ? sf_quick_release : r->amp.release);
    sf_env_start(&v->mod, SF_RELEASE, quick ? sf_quick_release : r->mod.release);
    if (r->loop_mode == 2) v->loop_end = 0;
}

static int32_t sf_lfo_level(const SfLfo *l)
{
    uint32_t p = l->phase;
    if (p < 0x400000UL) return p >> 7;
    if (p < 0xc00000UL) return (0x800000L - (int32_t)p) >> 7;
    return ((int32_t)p - 0x1000000L) >> 7;
}

static void sf_lfo_advance(SfLfo *l, uint32_t step, unsigned frames)
{
    if (l->delay >= frames) { l->delay -= frames; return; }
    frames -= (unsigned)l->delay;
    l->delay = 0;
    l->phase = (l->phase + step * frames) & SF_PHASE_MASK;
}

static unsigned sf_find_preset(unsigned bank, unsigned program)
{
    unsigned low = 0, high = sf_bank.preset_count, i;
    const SfPreset SF_FAR *p;
    while (low < high) {
        i = low + (high - low) / 2;
        p = &sf_bank.presets[i];
        if (p->bank < bank || (p->bank == bank && p->program < program)) low = i + 1;
        else high = i;
    }
    if (low == sf_bank.preset_count) return 0xffffU;
    p = &sf_bank.presets[low];
    return p->bank == bank && p->program == program ? low : 0xffffU;
}

static int sf_uses_drum_bank_msb(const SfChannel *c)
{
    return c->drum && (sf_mode == SF_MODE_XG || sf_mode == SF_MODE_GM2);
}

static void sf_select_preset(SfChannel *c)
{
    unsigned bank = c->program_bank;
    unsigned program = c->program;
    unsigned preset = 0xffffU;
    if (c->drum) {
        /* XG and GM2 bank MSBs select percussion mode, not an SF2 bank. */
        if (sf_uses_drum_bank_msb(c)) bank = 0;
        preset = sf_find_preset(128U | bank, program);
        if (preset == 0xffffU && bank) preset = sf_find_preset(128, program);
        if (preset == 0xffffU) preset = sf_find_preset(128, 0);
    }
    if (preset == 0xffffU && bank && bank != 128U) preset = sf_find_preset(bank, program);
    if (preset == 0xffffU) preset = sf_find_preset(0, program);
    if (preset == 0xffffU) preset = sf_find_preset(0, 0);
    c->preset = preset == 0xffffU ? 0 : preset;
}

static void sf_program(unsigned channel, unsigned program)
{
    SfChannel *c = &sf_channels[channel];
    c->program = (uint8_t)program;
    if (!sf_uses_drum_bank_msb(c)) c->program_bank = c->bank & 0x7fffU;
    sf_select_preset(c);
}

static void sf_set_drum(SfChannel *c, unsigned drum)
{
    if (c->drum == drum) return;
    c->drum = (uint8_t)drum;
    sf_select_preset(c);
}

static void sf_pitch_channel(SfChannel *c)
{
    c->pitch_cents = c->coarse * 100L + c->fine +
                    (((int32_t)c->pitch - 8192) * c->range >> 13);
}

static void sf_gain_channel(SfChannel *c)
{
    /* The default SF2 volume and expression modulators each give a square-law amplitude. */
    int32_t gain = ((int32_t)(c->volume + 1) * (c->expression + 1)) >> 13;
    c->gain = sf_mul_shift(gain, gain, 15);
}

static void sf_vibrato_channel(SfChannel *c)
{
    c->vibrato = ((int32_t)c->modulation * 50 >> 14) + ((int32_t)c->pressure * 50 >> 7);
}

static void sf_stop_playback(void)
{
    unsigned i;
    for (i = 0; i < sf_limit; ++i) sf_voices[i].region = 0;
    for (i = 0; i < 16; ++i) sf_channels[i].sustain = 0;
    sf_serial = 0;
}

static void sf_reset(unsigned mode)
{
    unsigned i;
    SfChannel *c;
    sf_stop_playback();
    sf_mode = mode;
    sf_output_gain = sf_headroom_gain;
    for (i = 0; i < 16; ++i) {
        c = &sf_channels[i];
        c->bank = c->program_bank = c->modulation = c->data = c->pressure = 0;
        c->pitch = c->pan = 8192;
        c->volume = c->expression = 16383;
        c->rpn = 0xffffU;
        c->range = 200;
        c->coarse = c->fine = 0;
        c->pitch_cents = c->vibrato = 0;
        c->gain = SF_GAIN_ONE;
        c->drum = i == 9;
        sf_program(i, 0);
    }
}

static void sf_note_on(unsigned channel, unsigned key, unsigned velocity)
{
    unsigned preset = sf_channels[channel].preset;
    const SfPreset SF_FAR *p = &sf_bank.presets[preset];
    const SfRegion SF_FAR *r;
    SfVoice *v, *slot, *released;
    unsigned zone, i;
    uint32_t release_age, oldest_release;
    uint32_t serial = ++sf_serial;
    int32_t vel = sf_div((int32_t)velocity * SF_GAIN_ONE, 127);
    int32_t velocity_gain = sf_mul_shift(vel, vel, 15);

    for (zone = 0; zone < p->count; ++zone) {
        r = &p->regions[zone];
        if (key < r->low_key || key > r->high_key ||
            velocity < r->low_vel || velocity > r->high_vel) continue;
        slot = released = 0;
        oldest_release = 0;
        for (i = 0; i < sf_limit; ++i) {
            v = &sf_voices[i];
            if (!v->region) {
                if (!slot) slot = v;
            } else {
                if (r->group && v->region->group == r->group && v->channel == channel &&
                    v->preset == preset && v->serial != serial) sf_release(v, 1);
                if (!v->region) {
                    if (!slot) slot = v;
                } else if (v->amp.stage == SF_RELEASE) {
                    release_age = (v->quick ? sf_quick_release : v->region->amp.release) - v->amp.left;
                    if (!released || release_age > oldest_release) {
                        released = v;
                        oldest_release = release_age;
                    }
                }
            }
        }
        if (!slot) slot = released;
        if (!slot) {
            uint32_t oldest_held = 0;
            /* These notes have already received Note Off. Reuse the oldest
               pedal-held voice before dropping a new attack. */
            for (i = 0; i < sf_limit; ++i) {
                v = &sf_voices[i];
                if (v->held && serial - v->serial > oldest_held) {
                    oldest_held = serial - v->serial;
                    slot = v;
                }
            }
            if (!slot) continue;
        }
        slot->region = r;
        slot->channel = (uint8_t)channel;
        slot->key = (uint8_t)key;
        slot->serial = serial;
        slot->held = slot->quick = 0;
        slot->preset = (uint16_t)preset;
        slot->pos = r->start;
        slot->frac = 0;
        slot->loop_end = r->loop_end;
        slot->base_pitch = r->pitch_base + (int32_t)r->pitch_track * key;
        slot->last_pitch = 0x7fffffffL;
        slot->velocity_gain = velocity_gain;
        slot->gain = sf_mul_shift(velocity_gain, sf_gain(r->attenuation), 15);
        slot->filter.a0 = r->filter.a0;
        slot->filter.b1 = r->filter.b1;
        slot->filter.b2 = r->filter.b2;
        slot->filter_fc = r->filter_fc;
        slot->z1 = slot->z2 = 0;
        sf_env_start(&slot->amp, SF_DELAY, r->amp.delay);
        sf_env_start(&slot->mod, SF_DELAY, r->mod.delay);
        if (!slot->amp.left) sf_env_next(&slot->amp, &r->amp, key, 1);
        if (!slot->mod.left) sf_env_next(&slot->mod, &r->mod, key, 0);
        slot->mod_lfo.delay = r->mod_delay;
        slot->vib_lfo.delay = r->vib_delay;
        slot->mod_lfo.phase = slot->vib_lfo.phase = 0;
    }
}

static void sf_note_off(unsigned channel, unsigned key)
{
    SfVoice *v;
    unsigned i;
    uint32_t age = 0;
    int found = 0;
    for (i = 0; i < sf_limit; ++i) {
        v = &sf_voices[i];
        if (v->region && v->channel == channel && v->key == key &&
            v->amp.stage < SF_RELEASE && !v->held &&
            (!found || sf_serial - v->serial > age)) {
            age = sf_serial - v->serial;
            found = 1;
        }
    }
    if (!found) return;
    for (i = 0; i < sf_limit; ++i) {
        v = &sf_voices[i];
        if (v->region && v->channel == channel && v->key == key &&
            sf_serial - v->serial == age) {
            if (sf_channels[channel].sustain) v->held = 1;
            else sf_release(v, 0);
        }
    }
}

static void sf_release_channel(unsigned channel, int held_only, int quick)
{
    unsigned i;
    for (i = 0; i < sf_limit; ++i) {
        SfVoice *v = &sf_voices[i];
        if (v->region && v->channel == channel && (!held_only || v->held))
            sf_release(v, quick);
    }
}

static void sf_control(unsigned channel, unsigned cc, unsigned value)
{
    SfChannel *c = &sf_channels[channel];
    switch (cc) {
    case 0:
        c->bank = 0x8000U | value;
        if (sf_mode == SF_MODE_XG && (value == 127 || channel != 9))
            sf_set_drum(c, value == 127);
        else if (sf_mode == SF_MODE_GM2)
            sf_set_drum(c, value == 120);
        return;
    case 32:  c->bank = (c->bank & 0x8000U ? (c->bank & 127U) << 7 : 0) | value; return;
    case 1:   c->modulation = (c->modulation & 127U) | (value << 7); break;
    case 33:  c->modulation = (c->modulation & 0x3f80U) | value; break;
    case 7:   c->volume = (c->volume & 127U) | (value << 7); break;
    case 39:  c->volume = (c->volume & 0x3f80U) | value; break;
    case 11:  c->expression = (c->expression & 127U) | (value << 7); break;
    case 43:  c->expression = (c->expression & 0x3f80U) | value; break;
    case 10:  c->pan = (c->pan & 127U) | (value << 7); return;
    case 42:  c->pan = (c->pan & 0x3f80U) | value; return;
    case 64:
        if (c->sustain && value < 64) sf_release_channel(channel, 1, 0);
        c->sustain = value >= 64;
        return;
    case 101: c->rpn = ((c->rpn == 0xffffU ? 0 : c->rpn) & 127U) | (value << 7); return;
    case 100: c->rpn = ((c->rpn == 0xffffU ? 0 : c->rpn) & 0x3f80U) | value; return;
    case 98:
    case 99:  c->rpn = 0xffffU; return;
    case 6:
    case 38:
        if (cc == 6) c->data = (c->data & 127U) | (value << 7);
        else c->data = (c->data & 0x3f80U) | value;
        if (!c->rpn) c->range = (int16_t)((c->data >> 7) * 100 + (c->data & 127U));
        else if (c->rpn == 1) c->fine = (int16_t)((((int32_t)c->data - 8192) * 100) >> 13);
        else if (c->rpn == 2 && cc == 6) c->coarse = (int16_t)((int)value - 64);
        sf_pitch_channel(c);
        return;
    case 120: sf_release_channel(channel, 0, 1); return;
    case 123:
    case 124:
    case 125: sf_release_channel(channel, 0, 0); return;
    case 121:
        c->expression = 16383;
        c->rpn = 0xffffU;
        c->data = c->modulation = c->pressure = 0;
        c->range = 200;
        c->fine = c->coarse = 0;
        if (c->sustain) sf_release_channel(channel, 1, 0);
        c->sustain = 0;
        sf_pitch_channel(c);
        sf_vibrato_channel(c);
        sf_gain_channel(c);
        return;
    default: return;
    }
    if (cc == 1 || cc == 33) sf_vibrato_channel(c);
    else sf_gain_channel(c);
}

static void sf_short(uint32_t data)
{
    unsigned channel = (unsigned)data & 15U;
    unsigned a = (unsigned)(data >> 8) & 127U;
    unsigned b = (unsigned)(data >> 16) & 127U;
    SfChannel *c = &sf_channels[channel];
    switch ((unsigned)data & 0xf0U) {
    case 0x90:
        if (b) { sf_note_on(channel, a, b); return; }
        /* Fall through for zero-velocity note-on. */
    case 0x80: sf_note_off(channel, a); return;
    case 0xb0: sf_control(channel, a, b); return;
    case 0xc0: sf_program(channel, a); return;
    case 0xd0: c->pressure = (uint8_t)a; sf_vibrato_channel(c); return;
    case 0xe0: c->pitch = a | (b << 7); sf_pitch_channel(c); return;
    }
}

static void sf_long(unsigned bytes, const uint8_t SF_FAR *p)
{
    unsigned part, channel, volume;
    if (p[0] != 0xf0 || p[bytes - 1] != 0xf7) return;
    if (bytes == 6 && p[1] == 0x7e && p[3] == 0x09) {
        if (p[4] == 3) sf_reset(SF_MODE_GM2);
        else if (p[4] == 1 || p[4] == 2) sf_reset(SF_MODE_GM);
    } else if (bytes == 8 && p[1] == 0x7f && p[2] < 128 &&
               p[3] == 4 && p[4] == 1 && p[5] < 128 && p[6] < 128) {
        /* Combine MIDI Master Volume with the user's mix headroom. */
        volume = ((unsigned)p[6] << 7) | p[5];
        volume = (volume + (volume >> 13)) * 2U; /* 0..32768 */
        sf_output_gain = (unsigned)sf_mul_shift(sf_headroom_gain, volume, 15);
    } else if (bytes == 9 && p[1] == 0x43 && (p[2] & 0xf0) == 0x10 && p[3] == 0x4c &&
               !p[4] && !p[5] && p[6] == 0x7e && !p[7]) {
        sf_reset(SF_MODE_XG);
    } else if (bytes == 11 && p[1] == 0x41 && p[3] == 0x42 && p[4] == 0x12 &&
               ((p[5] + p[6] + p[7] + p[8] + p[9]) & 127) == 0) {
        if ((p[5] == 0x40 || p[5] == 0x00) && !p[6] && p[7] == 0x7f && !p[8])
            sf_reset(SF_MODE_GS);
        else if (p[5] == 0x40 && (p[6] & 0xf0) == 0x10 && p[7] == 0x15) {
            /* GS parts 0, 1..9 and 10..15 are MIDI channels 10, 1..9 and 11..16. */
            part = p[6] & 15;
            channel = part == 0 ? 9 : (part < 10 ? part - 1 : part);
            sf_set_drum(&sf_channels[channel], p[8] != 0);
        }
    }
}

#ifdef __I86__
typedef struct {
    uint32_t page;
    unsigned selector;
} SfSampleWindow;

static const int16_t SF_FAR *sf_far_sample(unsigned selector, unsigned offset);
#pragma aux sf_far_sample = "" parm [dx] [ax] value [dx ax] modify exact [];

static const int16_t SF_FAR *sf_sample_ptr(SfSampleWindow *w, uint32_t byte)
{
    uint32_t page = byte >> 16;
    if (w->page != page) {
        w->page = page;
        w->selector = FP_SEG(sf_bank.sample_pages[(unsigned)page]);
    }
    return sf_far_sample(w->selector, (unsigned)byte);
}

static int32_t sf_sample(SfSampleWindow *w, uint32_t pos, uint32_t next, uint32_t frac)
{
    uint32_t byte = pos << 1;
    const int16_t SF_FAR *p = sf_sample_ptr(w, byte);
    int32_t a = p[0], b;
    if (next == pos + 1 && (unsigned)byte != 0xfffeU) b = p[1];
    else b = *sf_sample_ptr(w, next << 1);
    return a + sf_mul_shift(b - a, (int32_t)(frac >> 9), 15);
}
#else
typedef int SfSampleWindow;

static int32_t sf_sample(SfSampleWindow *w, uint32_t pos, uint32_t next, uint32_t frac)
{
    int32_t a = sf_bank.sample_pages[pos >> 15][pos & 0x7fffU];
    int32_t b = sf_bank.sample_pages[next >> 15][next & 0x7fffU];
    (void)w;
    return a + sf_mul_shift(b - a, (int32_t)(frac >> 9), 15);
}
#endif

typedef struct {
    int32_t z1, z2, a0, b1, b2, left, right;
} SfMixer;

#ifdef __I86__
/* All hot filter/mix arithmetic stays in 386 dword registers. SfMixer
   and the output accumulator both live in the resident DGROUP. */
typedef char SfMixerSize[(sizeof(SfMixer) == 28) ? 1 : -1];
static void sf_mix_sample(SfMixer *mix, int32_t sample, int32_t *out);
#pragma aux sf_mix_sample = \
    "shl edx,16" "mov dx,ax" "mov eax,edx" \
    "cmp dword ptr [bx+8],0" "je sf_mix_pan" \
    "shl eax,8" "imul dword ptr [bx+8]" "shrd eax,edx,28" \
    "mov ecx,eax" "add eax,dword ptr [bx]" \
    "cmp eax,0fe000000h" "jge sf_mix_upper" "mov eax,0fe000000h" \
    "sf_mix_upper:" "cmp eax,01ffffffh" "jle sf_mix_filter" "mov eax,01ffffffh" \
    "sf_mix_filter:" "mov esi,eax" \
    "imul dword ptr [bx+12]" "shrd eax,edx,28" \
    "mov edx,dword ptr [bx+4]" "lea edx,[edx+ecx*2]" "sub edx,eax" \
    "mov dword ptr [bx],edx" \
    "mov eax,esi" "imul dword ptr [bx+16]" "shrd eax,edx,28" \
    "sub ecx,eax" "mov dword ptr [bx+4],ecx" \
    "mov eax,esi" "sar eax,8" \
    "sf_mix_pan:" "mov ecx,eax" \
    "imul dword ptr [bx+20]" "shrd eax,edx,15" "add dword ptr [di],eax" \
    "mov eax,ecx" "imul dword ptr [bx+24]" "shrd eax,edx,15" "add dword ptr [di+4],eax" \
    parm [bx] [dx ax] [di] modify exact [ax cx dx si];
#define SF_STACK_PTR(type, var) ((type *)(unsigned)FP_OFF(&(var)))
#else
static void sf_mix_sample(SfMixer *mix, int32_t sample, int32_t *out)
{
    if (mix->a0) {
        int32_t input = sf_mul_shift(sample * 256L, mix->a0, 28);
        int32_t output = sf_clip(input + mix->z1, -33554432L, 33554431L);
        mix->z1 = 2 * input + mix->z2 - sf_mul_shift(output, mix->b1, 28);
        mix->z2 = input - sf_mul_shift(output, mix->b2, 28);
        sample = output >> 8;
    }
    out[0] += sf_mul_shift(sample, mix->left, 15);
    out[1] += sf_mul_shift(sample, mix->right, 15);
}
#define SF_STACK_PTR(type, var) (&(var))
#endif

static void sf_voice_render(SfVoice *v, unsigned frames)
{
    const SfRegion SF_FAR *r = v->region;
    const SfChannel *c = &sf_channels[v->channel];
    uint32_t pos = v->pos, frac = v->frac, end = r->end;
    uint32_t loop_end = v->loop_end, loop_start = r->loop_start;
    uint32_t loop_size = loop_end ? loop_end - loop_start + 1 : 0;
    int32_t gain_limit = r->filter_gain_limit;
    int32_t pan = sf_clip((int32_t)r->pan + ((int32_t)c->pan * 2), 0, SF_GAIN_ONE);
    int32_t pan_left = sf_pan_gain(SF_GAIN_ONE - pan), pan_right = sf_pan_gain(pan);
    int32_t *out = sf_mix;
    int32_t amp, mod, lfo, vib, pitch, cutoff, gain, sample;
    SfMixer mix;
    unsigned block, n;
    SfSampleWindow window;

    mix.z1 = v->z1;
    mix.z2 = v->z2;
#ifdef __I86__
    window.page = 0xffffffffUL;
    window.selector = 0;
#endif

    while (frames && pos < end && v->amp.stage != SF_DONE) {
        block = frames > SF_EFFECT_FRAMES ? SF_EFFECT_FRAMES : frames;
        if (v->amp.left && v->amp.left < block) block = (unsigned)v->amp.left;
        if (v->mod.left && v->mod.left < block) block = (unsigned)v->mod.left;

        amp = sf_env_level(&v->amp, &r->amp, 1);
        if (!amp && v->amp.stage >= SF_SUSTAIN) {
            v->region = 0;
            return;
        }
        mod = sf_env_level(&v->mod, &r->mod, 0);
        lfo = sf_lfo_level(&v->mod_lfo);
        vib = sf_lfo_level(&v->vib_lfo);
        pitch = v->base_pitch + c->pitch_cents +
            ((lfo * r->mod_lfo_pitch) >> 15) + ((mod * r->mod_env_pitch) >> 15) +
            ((vib * (r->vib_lfo_pitch + c->vibrato)) >> 15);
        if (pitch != v->last_pitch) {
            v->last_pitch = pitch;
            v->step = (uint32_t)sf_ratio(pitch);
            if (!v->step) v->step = 1;
        }

        if (r->mod_lfo_filter || r->mod_env_filter) {
            cutoff = r->filter_fc + ((lfo * r->mod_lfo_filter) >> 15) +
                     ((mod * r->mod_env_filter) >> 15);
            if (cutoff != v->filter_fc) {
                v->filter_fc = cutoff;
                sf_filter_coeff(&v->filter, cutoff, r->filter_q, sf_tan_values);
            }
        }

        gain = v->gain;
        if (r->mod_lfo_gain) {
            gain = sf_gain(r->attenuation - ((lfo * r->mod_lfo_gain) >> 15));
            gain = sf_mul_shift(gain, v->velocity_gain, 15);
        }
        gain = sf_mul_shift(gain, c->gain, 15);
        if (gain > gain_limit) gain = gain_limit;
        gain = sf_mul_shift(gain, amp, 15);
        mix.left = sf_mul_shift(gain, pan_left, 15);
        mix.right = sf_mul_shift(gain, pan_right, 15);
        mix.a0 = v->filter.a0;
        mix.b1 = v->filter.b1;
        mix.b2 = v->filter.b2;

        for (n = 0; n < block && pos < end; ++n) {
            if (mix.left || mix.right || mix.a0) {
                sample = sf_sample(SF_STACK_PTR(SfSampleWindow, window), pos,
                                   loop_size && pos == loop_end ? loop_start : pos + 1, frac);
                sf_mix_sample(SF_STACK_PTR(SfMixer, mix), sample, out);
            }
            out += 2;
            frac += v->step;
            pos += frac >> 24;
            frac &= SF_PHASE_MASK;
            if (loop_size && pos > loop_end) {
                pos -= loop_size;
                if (pos > loop_end) {
                    uint32_t offset = pos - loop_start;
                    pos -= loop_size * (uint32_t)sf_div(offset, loop_size);
                }
            }
        }

        sf_env_advance(&v->amp, &r->amp, block, v->key, 1);
        sf_env_advance(&v->mod, &r->mod, block, v->key, 0);
        sf_lfo_advance(&v->mod_lfo, r->mod_step, block);
        sf_lfo_advance(&v->vib_lfo, r->vib_step, block);
        frames -= block;
    }
    v->pos = pos;
    v->frac = frac;
    v->z1 = mix.z1;
    v->z2 = mix.z2;
    if (pos >= end || v->amp.stage == SF_DONE) v->region = 0;
}

static void sf_render(int16_t SF_FAR *pcm, unsigned frames)
{
    unsigned i;
    for (i = 0; i < frames * 2; ++i) sf_mix[i] = 0;
    for (i = 0; i < sf_limit; ++i)
        if (sf_voices[i].region) sf_voice_render(&sf_voices[i], frames);
    /* Scale the wide mix before narrowing to stereo PCM16. */
    if (sf_output_gain == SF_GAIN_ONE) {
        for (i = 0; i < frames * 2; ++i)
            pcm[i] = (int16_t)sf_clip(sf_mix[i], -32768L, 32767L);
    } else {
        for (i = 0; i < frames * 2; ++i)
            pcm[i] = (int16_t)sf_clip(sf_mul_shift(sf_mix[i], sf_output_gain, 15),
                                     -32768L, 32767L);
    }
}

#ifdef __I86__
typedef DWORD SfAddress;
#else
typedef uintptr_t SfAddress;
#endif

static unsigned sf_dispatch(unsigned command, unsigned value, SfAddress data)
{
    if (!sf_ready) return 0;
    switch (command) {
    case 2:
        if ((uint8_t)data < 0x80 || (uint8_t)data >= 0xf0) return 0;
        sf_short((uint32_t)data);
        return 1;
    case 3:
        if ((value != 6 && value != 8 && value != 9 && value != 11) || !data) return 0;
#ifdef __I86__
        if (!HIWORD(data) || (uint32_t)LOWORD(data) + value > 65536UL) return 0;
#endif
        sf_long(value, (const uint8_t SF_FAR *)data);
        return 1;
    case 4:
        if (!value || value > SF_MAX_FRAMES || !data) return 0;
#ifdef __I86__
        if (!HIWORD(data) || (uint32_t)LOWORD(data) + value * 4U > 65536UL) return 0;
#endif
        sf_render((int16_t SF_FAR *)data, value);
        return 1;
    case 5:
        sf_reset(SF_MODE_GM);
        return 1;
    case 6:
        sf_stop_playback();
        return 1;
    }
    return 0;
}

static unsigned sf_set_rate(unsigned rate)
{
    if (rate != SF_DEFAULT_RATE && rate != SF_NATIVE_RATE) return 0;
    if (sf_ready && rate != sf_rate) return 0;
    sf_rate = rate;
    return 1;
}

static unsigned sf_set_headroom(unsigned db)
{
    if (sf_ready || db > SF_MAX_HEADROOM_DB) return 0;
    sf_headroom_gain = (unsigned)sf_gain((int32_t)db * 10);
    return 1;
}

static unsigned sf_open(const char SF_FAR *path, unsigned voices)
{
    unsigned result;
    if (sf_ready || !path || voices < SF_MIN_VOICES || voices > SF_MAX_VOICES) return 0;
    result = sf_load(path, &sf_bank, sf_rate);
    if (result != SF_OK) return result;
    sf_limit = voices;
    sf_quick_release = sf_rate / 100;
    sf_tan_values = sf_rate == SF_NATIVE_RATE ? sf_tan_48000 : sf_tan_44100;
    sf_reset(SF_MODE_GM);
    sf_ready = 1;
    return SF_OK;
}

static void sf_close(void)
{
    if (!sf_ready) return;
    sf_ready = 0;
    sf_limit = 0;
    sf_unload(&sf_bank);
}

#ifdef __I86__
static WORD irq_stack[4096];
static WORD saved_ss, saved_sp, request_result;
static WORD request_command, request_value;
static DWORD request_data;

static WORD dispatch_irq(void)
{
    return sf_dispatch(request_command, request_value, request_data);
}

static WORD private_stack(void);
#pragma aux private_stack = \
    "pushad" "push ds" "push es" \
    "mov saved_ss,ss" "mov saved_sp,sp" \
    "pushf" "pop ax" "cli" "mov bx,ds" "mov ss,bx" \
    "mov sp,offset irq_stack+8192" "push ax" "popf" \
    "call dispatch_irq" "mov request_result,ax" \
    "pushf" "pop bx" "cli" "mov ss,saved_ss" "mov sp,saved_sp" \
    "push bx" "popf" \
    "pop es" "pop ds" "popad" "mov ax,request_result" \
    value [ax] modify exact [ax];

static WORD data_selector(void);
#pragma aux data_selector = "mov ax,ds" value [ax] modify exact [ax];

BOOL WINAPI __loadds LibMain(HINSTANCE inst, WORD data, WORD heap, LPSTR cmd)
{
    (void)inst; (void)data; (void)heap; (void)cmd;
    return TRUE;
}

WORD WINAPI __export __loadds SFCORE(WORD command, WORD value, DWORD data)
{
    if (command & 0x8000U) {
        request_command = command & 0x7fffU;
        request_value = value;
        request_data = data;
        return private_stack();
    }
    switch (command) {
    case 0: return 0x5342;
    case 1: return sf_open((const char SF_FAR *)data, value);
    case 6: sf_close(); return 1;
    case 7: return data_selector();
    case 8: return sf_set_rate(value);
    case 9: return sf_set_headroom(value);
    }
    return 0;
}
#else
int sf_host_open_rate(const char *path, unsigned voices, unsigned rate)
{
    return sf_set_rate(rate) && sf_set_headroom(0) ? sf_open(path, voices) : 0;
}

int sf_host_open(const char *path, unsigned voices)
{
    return sf_host_open_rate(path, voices, SF_DEFAULT_RATE);
}
void sf_host_close(void) { sf_close(); }

unsigned sf_host_cmd(unsigned command, unsigned value, uintptr_t data)
{
    return sf_dispatch(command, value, data);
}

unsigned sf_host_voices(void)
{
    unsigned i, voices = 0;
    for (i = 0; i < sf_limit; ++i)
        if (sf_voices[i].region) ++voices;
    return voices;
}
#endif
