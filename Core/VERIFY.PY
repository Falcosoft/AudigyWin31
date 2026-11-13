"""Execute the shipped Win16 core on the exact packaged score (Unicorn)."""
from pathlib import Path
import struct as s
import sys
import zlib

from unicorn import Uc, UC_ARCH_X86, UC_MODE_16, UC_HOOK_CODE, UC_HOOK_MEM_INVALID
from unicorn import UC_HOOK_BLOCK
from unicorn.x86_const import *

data = Path(sys.argv[1]).read_bytes()
score = Path(sys.argv[2]).read_bytes()
u = Uc(UC_ARCH_X86, UC_MODE_16)
u.mem_map(0, 0x100000)
sel = (0, 0x1000, 0x2000, 0x3000, 0x4000, 0x5000)
stub, stack, caller = 0x6000, 0x7000, 0x8000
caller_ds = 0x9000  # neither the caller's stack nor its far PCM buffer


def rd(a, fmt='<H'):
    return s.unpack(fmt, u.mem_read(a, s.calcsize(fmt)))[0]


def wr(a, x, fmt='<H'):
    u.mem_write(a, s.pack(fmt, x))


def w(at):
    return s.unpack_from('<H', data, at)[0]


ne = s.unpack_from('<I', data, 0x3c)[0]
assert data[ne:ne+2] == b'NE'
dgroup = w(ne+0x0e)
segments = w(ne+0x1c)
assert 1 <= dgroup <= segments <= 5
ent = ne+w(ne+4)
assert data[ent:ent+2] == b'\x01\x01' and data[ent+2] & 1
start = w(ent+3)
tab, mt, it = (ne+w(ne+offset) for offset in (0x22, 0x28, 0x2a))
shift = w(ne+0x32)
mod = ['']
for i in range(w(ne+0x1e)):
    p = it+w(mt+i*2)
    mod.append(data[p+1:p+1+data[p]].decode())
apis = {}
u.mem_write(stub << 4, b'\x90' * 4096)
for i in range(1, segments+1):
    sector, length, flags, alloc = s.unpack_from('<4H', data, tab+(i-1)*8)
    offset, base = sector << shift, sel[i] << 4
    u.mem_write(base, data[offset:offset+length])
    if not flags & 256:
        continue
    fix = offset+length
    for j in range(w(fix)):
        kind, flags, src, a, b = s.unpack_from('<BBHHH', data, fix+2+j*8)
        t = flags & 3
        if t == 3:
            continue  # host emulates x87 directly
        if t == 0:
            segment, addr = sel[a], b
        else:
            assert t == 1
            name = mod[a], b
            segment = stub
            addr = next((k for k,v in apis.items() if v == name), 16+len(apis)*16)
            apis[addr] = name
        while True:
            old = rd(base+src)
            add = old if flags & 4 else 0
            if kind == 2:
                wr(base+src, segment+add)
            elif kind == 5:
                wr(base+src, addr+add)
            else:
                assert kind == 3
                wr(base+src, (segment<<16) | ((addr+add)&65535), '<I')
            if flags & 4 or old == 65535:
                break
            assert old < length and old != src
            src = old


def push(x):
    sp = u.reg_read(UC_X86_REG_SP)-2
    wr((stack << 4)+sp,x)
    u.reg_write(UC_X86_REG_SP,sp)


done = False
irq_active = False
irq_blocks = set()
irq_min_sp = 65535
alloc = {}
def hook(_, address, size, obj):
    global done
    off = address-(stub << 4)
    if off == 0:
        done = True
        u.emu_stop()
        return
    assert not irq_active, ('Windows API called at interrupt time', apis.get(off))
    api = apis[off]
    sp = u.reg_read(UC_X86_REG_SP)
    at = (stack << 4)+sp
    if api == ('KERNEL', 3):  # GetVersion
        args, ret = 0, 0x0a03
    elif api == ('KERNEL', 4):  # LocalInit
        args, ret = 3, 1
    elif api == ('KERNEL', 5):  # optional CRT near-heap expansion
        args, ret = 2, 0
    elif api == ('KERNEL', 132):  # GetWinFlags; 386 + x87
        args, ret = 0, 0x420
    elif api == ('KERNEL', 15):
        ret = next(x for x in range(0xa000,0xf000,0x1000) if x not in alloc)
        args = 3
        alloc[ret] = rd(at+4,'<I')
        assert 0 < alloc[ret] <= 65536
    elif api == ('KERNEL', 18):
        h = rd(at+4)
        assert h in alloc
        args, ret = 1, h<<16
    elif api == ('KERNEL', 17):
        del alloc[rd(at+4)]
        args, ret = 1, 0
    elif api == ('KERNEL', 19):
        args, ret = 1, 0
    else:
        raise AssertionError(api)
    u.reg_write(UC_X86_REG_AX, ret & 65535)
    u.reg_write(UC_X86_REG_DX, ret >> 16)
    u.reg_write(UC_X86_REG_SP, sp+4+args*2)
    u.reg_write(UC_X86_REG_CS, rd(at+2))
    u.reg_write(UC_X86_REG_IP, rd(at))


u.hook_add(UC_HOOK_CODE, hook, begin=stub<<4, end=(stub<<4)+4095)
def invalid_memory(uc, access, address, size, value, _):
    print('Invalid guest memory access', hex(address), 'CS:IP, SS:SP, DS, ES:',
          [hex(uc.reg_read(reg)) for reg in (UC_X86_REG_CS, UC_X86_REG_IP,
           UC_X86_REG_SS, UC_X86_REG_SP, UC_X86_REG_DS, UC_X86_REG_ES)],
          file=sys.stderr)
    return False
u.hook_add(UC_HOOK_MEM_INVALID, invalid_memory)
u.reg_write(UC_X86_REG_FPCW, 0x037f)
u.reg_write(UC_X86_REG_FPTAG, 0xffff)


def invoke(ip, args, ds, cx=0):
    global done
    u.reg_write(UC_X86_REG_EFLAGS, 0x202)
    u.reg_write(UC_X86_REG_SS, stack)
    u.reg_write(UC_X86_REG_SP, 0xfff0)
    u.reg_write(UC_X86_REG_DS, ds)
    u.reg_write(UC_X86_REG_ES, stub)
    u.reg_write(UC_X86_REG_CX, cx)
    u.reg_write(UC_X86_REG_BP, 0x2390)
    for arg in args:
        push(arg)
    push(stub)
    push(0)
    u.reg_write(UC_X86_REG_CS, sel[1])
    done = False
    # DBOPL's rate-table search can exceed 100 million guest instructions.
    limit = 1000000000 if '--bounded' in sys.argv else 0
    u.emu_start((sel[1]<<4)+ip, 0, count=limit)
    assert done and u.reg_read(UC_X86_REG_SP) == 0xfff0, (
        globals().get('frame'), globals().get('index'), args, done,
        [hex(u.reg_read(reg)) for reg in (UC_X86_REG_CS, UC_X86_REG_IP,
         UC_X86_REG_SP, UC_X86_REG_BP, UC_X86_REG_DS, UC_X86_REG_ES)])
    assert u.reg_read(UC_X86_REG_BP) == 0x2390
    assert u.reg_read(UC_X86_REG_DS) == ds
    return u.reg_read(UC_X86_REG_AX)


assert invoke(w(ne+0x14), (), sel[dgroup], w(ne+0x10)) == 1
print('NE startup passed', flush=True)
def core(cmd, count=0, ptr=0):
    global irq_active
    if '--irq' in sys.argv and cmd in (2,3,4,5): cmd |= 0x8000
    irq_active = bool(cmd & 0x8000)
    try:
        ss_before = stack
        si_before = u.reg_read(UC_X86_REG_SI)
        di_before = u.reg_read(UC_X86_REG_DI)
        result = invoke(start, (cmd,count,ptr>>16,ptr&65535), caller_ds)
        assert u.reg_read(UC_X86_REG_SS) == ss_before
        assert u.reg_read(UC_X86_REG_SI) == si_before
        assert u.reg_read(UC_X86_REG_DI) == di_before
        return result
    finally:
        irq_active = False

if '--irq' in sys.argv:
    from capstone import Cs, CS_ARCH_X86, CS_MODE_16
    from capstone.x86_const import X86_GRP_FPU
    decoder = Cs(CS_ARCH_X86, CS_MODE_16)
    decoder.detail = True

    def inspect_irq_block(uc, address, size, _):
        global irq_min_sp
        if not irq_active: return
        if uc.reg_read(UC_X86_REG_SS) == sel[dgroup]:
            irq_min_sp = min(irq_min_sp, uc.reg_read(UC_X86_REG_SP))
        if address in irq_blocks: return
        irq_blocks.add(address)
        for ins in decoder.disasm(bytes(uc.mem_read(address, size)), address):
            assert X86_GRP_FPU not in ins.groups, (hex(address), ins.mnemonic, ins.op_str)

    u.hook_add(UC_HOOK_BLOCK, inspect_irq_block)
assert core(1) == 1
assert core(7) == sel[dgroup]
print('44.1 kHz reset passed', flush=True)
assert core(0) == 0xa302
assert core(4, 513, caller<<16) == core(4, 2, (caller<<16)|65532) == 0
pcm_at = (caller << 4) + 0x100
u.mem_write(pcm_at-16, b'\xa5'*(16+512*4+32))
assert core(2, 0, 0x00644590) == 1
assert core(4, 512, (caller<<16)+0x100) == 1
assert u.mem_read(pcm_at-16, 16) == b'\xa5'*16
assert u.mem_read(pcm_at+512*4, 32) == b'\xa5'*32
first_note = bytes(u.mem_read(pcm_at, 512*4))
assert max(abs(v[0]) for v in s.iter_unpack('<h',first_note)) > 128
assert core(1) == 1
assert core(2, 0, 0x00644590) == 1
assert core(4, 512, (caller<<16)+0x100) == 1
assert u.mem_read(pcm_at, 512*4) == first_note
assert core(1) == 1
assert core(2, 0, 0x00644590) == 1
assert core(4, 512, (caller<<16)+0xf800) == 1
assert u.mem_read((caller<<4)+0xf800, 512*4) == first_note
assert core(1) == 1
assert core(0x8005) == 1
assert core(0x8002, 0, 0x00644590) == 1
assert core(0x8004, 512, (caller<<16)+0x100) == 1
assert u.mem_read(pcm_at, 512*4) == first_note
print('MIDI note, PCM bounds, replay and private-stack gateway passed', flush=True)
magic, rate, end, count = s.unpack_from('<4sIII', score)
assert magic == b'OPE1' and rate == 44100 and len(score) == 16+18*count
if '--short' in sys.argv:
    end = rate*12
if '--first-minute' in sys.argv:
    end = rate*60
else:
    assert '--short' in sys.argv or end == 8079143
frame = index = checksum = audible = 0
probe_begin, probe_end = 397312, 397824  # one busy 512-frame block near 9 s
probe_hook = None
probe_count = 0

def count_instruction(*_):
    global probe_count
    probe_count += 1

while frame < end:
    if '--probe' in sys.argv and frame == probe_begin:
        probe_hook = u.hook_add(UC_HOOK_CODE, count_instruction)
        u.ctl_flush_tb()
    if probe_hook is not None and frame == probe_end:
        u.hook_del(probe_hook)
        u.ctl_flush_tb()
        probe_hook = None
    goal = min(frame+512, end)
    while frame < goal:
        nxt = goal
        while index < count:
            f, n, msg = s.unpack_from('<IH12s', score, 16+index*18)
            if f > frame:
                nxt = min(nxt,f)
                break
            if not n:
                assert core(2, 0, int.from_bytes(msg[:3], 'little')) == 1
            else:
                u.mem_write((caller<<4)+0x900,msg)
                assert core(3,n,(caller<<16)+0x900) == 1
            index += 1
        assert core(4,nxt-frame,(caller<<16)+0x100) == 1
        pcm = u.mem_read((caller<<4)+0x100,(nxt-frame)*4)
        audible += bool(any(pcm))
        checksum = zlib.crc32(pcm,checksum)
        frame = nxt
assert audible > 50 and checksum != 0
assert '--short' in sys.argv or '--first-minute' in sys.argv or index == count
print(f'{frame} stereo frames, {index} MIDI events, {audible} audible chunks, CRC {checksum:08X}')
if '--probe' in sys.argv:
    assert probe_count > 0 and probe_hook is None
    print(f'Frame {probe_begin}: {probe_count} guest instructions per 512 frames')
if '--irq' in sys.argv:
    print(f'{len(irq_blocks)} runtime code blocks: no x87 or Windows API calls; '
          f'private-stack low-water offset {irq_min_sp:04X}')
