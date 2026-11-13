/* The timer uses 386 integer instructions and statically initialized tables. */
#include "SFTABLE.H"

#ifdef __I86__
static int32_t sf_mul_shift(int32_t a, int32_t b, unsigned shift);
#pragma aux sf_mul_shift = \
    "shl edx,16" "mov dx,ax" "mov eax,edx" \
    "shl esi,16" "mov si,bx" "imul esi" "shrd eax,edx,cl" \
    "mov edx,eax" "shr edx,16" \
    parm [dx ax] [si bx] [cx] value [dx ax] modify exact [ax dx si];

static int32_t sf_div_q28(int32_t a, int32_t b);
#pragma aux sf_div_q28 = \
    "shl edx,16" "mov dx,ax" "mov eax,edx" \
    "shl ecx,16" "mov cx,bx" \
    "cdq" "shld edx,eax,28" "shl eax,28" "idiv ecx" \
    "mov edx,eax" "shr edx,16" \
    parm [dx ax] [cx bx] value [dx ax] modify exact [ax dx cx];

static int32_t sf_div(int32_t a, int32_t b);
#pragma aux sf_div = \
    "shl edx,16" "mov dx,ax" "mov eax,edx" \
    "shl ecx,16" "mov cx,bx" "cdq" "idiv ecx" \
    "mov edx,eax" "shr edx,16" \
    parm [dx ax] [cx bx] value [dx ax] modify exact [ax dx cx];
#else
static int32_t sf_mul_shift(int32_t a, int32_t b, unsigned shift)
{
    return (int32_t)(((int64_t)a * b) >> shift);
}

static int32_t sf_div_q28(int32_t a, int32_t b)
{
    return (int32_t)((int64_t)a * (1L << 28) / b);
}

static int32_t sf_div(int32_t a, int32_t b)
{
    return a / b;
}
#endif

static int32_t sf_clip(int32_t value, int32_t lo, int32_t hi)
{
    if (value < lo) return lo;
    if (value > hi) return hi;
    return value;
}

static int32_t sf_ratio(int32_t cents)
{
    int octave;
    unsigned whole, frac;
    uint32_t low, high, ratio;
    if (cents <= -30000L) return 0;
    if (cents >= 8400) return 0x7fffffffL;
    octave = (int)sf_div(cents, 1200);
    cents -= octave * 1200L;
    if (cents < 0) { cents += 1200; --octave; }
    whole = (unsigned)cents / 10;
    frac = (unsigned)cents % 10;
    low = sf_pitch_table[whole];
    high = sf_pitch_table[whole + 1];
    ratio = low + (uint32_t)sf_div((high - low) * frac, 10);
    if (octave < 0) return ratio >> -octave;
    return ratio << octave;
}

static int32_t sf_gain(int32_t centibels)
{
    /* 1200 * log2(10) / 200, scaled by 100. Keep Q15 gain in int32_t. */
    int32_t cents = sf_div(-sf_clip(centibels, -900, 1500) * 1993L, 100);
    if (cents >= 7200) return sf_ratio(cents - 12000) << 1;
    return sf_ratio(cents) >> 9;
}

static int32_t sf_pan_gain(int32_t pan)
{
    unsigned entry, frac;
    int32_t gain;
    if (pan <= 0) return 0;
    if (pan >= SF_GAIN_ONE) return SF_GAIN_ONE;
    entry = (unsigned)pan >> 7;
    frac = (unsigned)pan & 127;
    gain = sf_pan_table[entry];
    return gain + (((int32_t)sf_pan_table[entry + 1] - gain) * frac >> 7);
}

static void sf_filter_coeff(SfFilter *f, int32_t cutoff, int32_t q, const int32_t *table)
{
    int32_t k, kk, damping, sum, delta;
    unsigned entry, frac;
    if (cutoff > 13500) {
        if (q == SF_FILTER_DAMPING_FLAT) { f->a0 = 0; return; }
        cutoff = 13500;
    }
    if (cutoff < 0) cutoff = 0;
    entry = (unsigned)cutoff / 50;
    frac = (unsigned)cutoff % 50;
    k = table[entry];
    if (frac) {
        delta = table[entry + 1] - k;
        k += sf_div(delta * frac, 50);
    }
    kk = sf_mul_shift(k, k, 16);
    damping = sf_mul_shift(k, q, 16);
    sum = 65536L + kk + damping;
    f->a0 = sf_div_q28(kk, sum);
    f->b1 = sf_div_q28(2 * (kk - 65536L), sum);
    f->b2 = sf_div_q28(65536L + kk - damping, sum);
}
