#ifndef TEST_DBOPL_H
#define TEST_DBOPL_H

#include "DBCHIP.H"

typedef uint8_t Bit8u;
typedef uint16_t Bit16u;
typedef int16_t Bit16s;
typedef uint32_t Bit32u;
typedef int32_t Bit32s;

// Keep the existing MIDI synth interface and its Fat Man patch mapping.
class OPL {
    DBOPL::Chip chip;
public:
    OPL() : chip(true) {}
    void adlib_init(long rate);
    void adlib_write(Bit16u reg, Bit8u value) { chip.WriteReg(reg, value); }
    void adlib_getsample(Bit16s *pcm, Bit32u frames) {
        chip.GenerateBlock3(frames, pcm);
    }
};

#endif
