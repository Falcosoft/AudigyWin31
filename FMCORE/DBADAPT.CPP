#include <stddef.h>
#include <string.h>
#include "DBOPL.H"

#if defined(__WATCOMC__) && defined(__I86__)
// The standard placement-new stub in the far runtime has a far pointer ABI.
inline void *operator new(size_t, void *ptr) { return ptr; }
#else
#include <new>
#endif

typedef char CheckChipWidth[sizeof(Bitu) == 4 && sizeof(Bits) == 4 ? 1 : -1];
typedef char CheckPCMWidth[sizeof(Bit16s) == 2 ? 1 : -1];
#if defined(__I86__)
typedef char CheckWin16Int[sizeof(int) == 2 && sizeof(void *) == 2 &&
                           sizeof(void __far *) == 4 ? 1 : -1];
#endif

void OPL::adlib_init(long rate)
{
    typedef DBOPL::Chip Chip;
    // Reset even the per-operator history on Stop / Play score again.
    chip.~Chip();
    OPL_MEMSET(&chip, 0, sizeof(chip));
    new (&chip) Chip(true);
    chip.Setup((uint32_t)rate);
}
