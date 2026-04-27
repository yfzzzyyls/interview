# Computer Architecture Interview Cheatsheet

Key concepts for firmware/embedded engineer interviews.

---

## 1. Memory Hierarchy

```
Fastest                                              Slowest
+----------+    +------+    +------+    +-----+    +------+
| Registers| -> |  L1  | -> |  L2  | -> | L3  | -> | DRAM |  -> Disk/SSD
|  <1 ns   |    | 1 ns |    | 4 ns |    |10 ns|    |100 ns|     ms
|  ~1 KB   |    | 32KB |    | 256KB|    | 8MB |    | GBs  |     TBs
+----------+    +------+    +------+    +-----+    +------+
```

**Key principle**: Smaller = faster = more expensive. Programs exploit **locality**:
- **Temporal locality**: Recently accessed data is likely accessed again soon
- **Spatial locality**: Nearby data is likely accessed soon (why cache lines are 64 bytes, not 1 byte)

**Interview question**: "Why do we need a memory hierarchy?"
- Because we can't build memory that is simultaneously fast, large, and cheap. The hierarchy gives the illusion of fast + large by caching frequently used data.

---

## 2. Cache

### Cache Organization

```
Direct-Mapped (1-way):
Each memory address maps to exactly ONE cache line.
  Address: [Tag | Index | Offset]
  Fast lookup, but conflicts when two addresses map to same line.

Set-Associative (N-way):
Each address maps to a SET of N lines. Can be placed in any of N ways.
  Address: [Tag | Set Index | Offset]
  Reduces conflict misses. Most common: 4-way, 8-way.

Fully Associative:
Can be placed in ANY cache line. No conflict misses.
  Address: [Tag | Offset]
  Expensive — needs to compare all tags. Used for TLB, small caches.
```

### Address Breakdown (example: 32-bit address, 256B cache, 4-way, 16B lines)

```
Total cache = 256 bytes
Line size   = 16 bytes  → Offset bits = log2(16) = 4
Num sets    = 256 / (4 ways * 16 bytes) = 4  → Index bits = log2(4) = 2
Tag bits    = 32 - 4 - 2 = 26

Address: [ 26-bit Tag | 2-bit Set Index | 4-bit Offset ]
```

### Cache Miss Types (the 3 C's)

| Type | Cause | Fix |
|------|-------|-----|
| **Compulsory** (Cold) | First access to a block — never been in cache | Prefetching |
| **Conflict** | Two addresses map to same set, evicting each other | Increase associativity |
| **Capacity** | Cache too small to hold all active data | Bigger cache |

### Write Policies

| Policy | Description | Pros | Cons |
|--------|-------------|------|------|
| **Write-through** | Write to cache AND memory simultaneously | Memory always up-to-date, simple | Slow writes, high bus traffic |
| **Write-back** | Write to cache only, write to memory on eviction | Fast writes | Complexity, dirty bit needed |
| **Write-allocate** | On write miss, load block into cache then write | Good for repeated writes | Wastes time if no reuse |
| **No-write-allocate** | On write miss, write directly to memory | Simpler | Misses future reads to same block |

Common combo: **write-back + write-allocate** (most modern processors)

### Cache Coherence (Multi-core)

**Problem**: Core A writes to address X in its L1 cache. Core B still has the old value of X in its L1.

**Solution**: MESI protocol (4 states per cache line):
- **M**odified: Only this cache has it, it's dirty
- **E**xclusive: Only this cache has it, it's clean
- **S**hared: Multiple caches have it, clean
- **I**nvalid: Not valid

**Interview question**: "What happens when Core A writes to a Shared line?"
- Core A invalidates all other copies (Shared → Invalid in other caches), then transitions to Modified.

### VIPT Caches

VIPT = **Virtually Indexed, Physically Tagged**.

Idea:
- Use virtual address index bits to start L1 tag/data SRAM access immediately.
- In parallel, the TLB translates virtual address to physical address.
- After translation, compare the physical tag against the cache tag.

Why VIPT:
- PIPT is clean but slower because translation must finish before cache indexing.
- VIVT is fast but has synonym/coherence problems.
- VIPT overlaps TLB lookup with cache access while still using physical tags.

Aliasing condition:
```text
num_sets * line_size <= page_size
cache_size / associativity <= page_size
```

Reason:
- Page offset bits are identical in VA and PA.
- VIPT is safe when all `index + offset` bits fit inside the page offset.
- If index bits extend into the virtual page number, two virtual aliases of the same physical page can index different L1 sets.

Examples:
```text
32KB L1, 64B line, 8-way, 4KB page:
32KB / 8 = 4KB <= 4KB -> no VIPT synonym aliasing

64KB L1, 64B line, 4-way, 4KB page:
64KB / 4 = 16KB > 4KB -> aliasing possible
```

Interview one-liner:
> VIPT indexes the L1 with virtual address bits while the TLB translates in parallel, then compares a physical tag. Aliasing depends on `num_sets * line_size`, equivalently `cache_size / associativity`, because index+offset must fit within the page offset.

### Cache Banking

Cache banking splits the physical cache arrays into multiple independently accessible banks. Main purpose: increase access bandwidth without building expensive multiported SRAMs.

Ways vs banks:
- **Ways** = associativity; placement choices within a set.
- **Banks** = physical array partitioning for bandwidth, layout, or timing.
- A 4-way cache can be implemented as 4 way SRAM arrays, and each way SRAM can also be split into 2 or more banks.

For banking by set/line, the old index bits are split into bank-select bits and set-within-bank bits.

Example:
```text
32KB cache, 64B line, 4-way, 2 banks, 32-bit address

num_lines = 32KB / 64B = 512
num_sets  = 512 / 4 = 128 sets

Without banking:
offset = log2(64)  = 6 bits
index  = log2(128) = 7 bits
tag    = 32 - 6 - 7 = 19 bits

Address:
[ tag 31:13 | set index 12:6 | offset 5:0 ]
```

If the 128 sets are split across 2 banks:
```text
sets_per_bank = 128 / 2 = 64
bank bits = log2(2) = 1
set_in_bank bits = log2(64) = 6
```

One possible physical split:
```text
[ tag 31:13 | set_in_bank 12:7 | bank 6 | offset 5:0 ]

old set_index[6:0] = {set_in_bank[5:0], bank[0]}
```

Another design could choose a different index bit as the bank bit:
```text
[ tag 31:13 | bank 12 | set_in_bank 11:6 | offset 5:0 ]
```

Bank conflicts:
- Accesses to different banks can proceed in parallel.
- Accesses to the same bank need arbitration, stall, or replay.

Caveat:
- If banking is inside a cache line, bank bits may come from the offset instead:
```text
[ tag | index | bank | byte_offset ]
```

Interview one-liner:
> Cache banking is physical partitioning for bandwidth. For set/line banking, the original index field is split into bank bits and set-within-bank bits. Ways and banks are orthogonal: ways define associativity; banks define which physical SRAM partition is accessed.

### Memory Consistency

Memory consistency defines what order memory operations appear to happen in across multiple cores/threads. It is different from cache coherence:
- **Coherence**: all cores agree on ordering of writes to the same address.
- **Consistency**: rules for ordering memory operations across different addresses.

Why ordering matters:
```c
// Core 0
data = 42;
ready = 1;

// Core 1
while (ready == 0) {}
print(data);
```

Programmer expects that seeing `ready == 1` means `data == 42` is visible. On a weak memory model, `ready` may become visible before `data` unless software uses fences or acquire/release synchronization.

#### TSO vs RVWMO

TSO = **Total Store Order**. Used by x86-like memory models.

Key TSO relaxation:
```text
Store -> Load reordering is allowed for different addresses.
```

Meaning:
```text
store X
load Y
```

The younger load can execute before the older store becomes globally visible, because the store may sit in the local store buffer while the load reads from cache/memory.

Important TSO rules:
- A load after a store to the **same address** must see the older store through store forwarding.
- Stores become globally visible in program order.
- TSO mainly relaxes store-to-load ordering; it is stronger than weak models like RVWMO.

Classic store-buffering example:
```c
// Core 0
x = 1;
r1 = y;

// Core 1
y = 1;
r2 = x;
```

Under TSO, this result is allowed:
```text
r1 = 0
r2 = 0
```

Each core's load can bypass its own older store while that store is still buffered.

RVWMO = **RISC-V Weak Memory Ordering**.

RVWMO is weaker than TSO. It gives hardware more freedom to reorder independent memory operations unless ordering is created by:
- `fence`
- acquire/release operations
- atomics
- dependencies
- same-address ordering rules

Interview one-liner:
> TSO mostly preserves program order except that a younger load may bypass an older store to a different address through the store buffer. RVWMO is weaker and allows more reorderings unless constrained by fences, acquire/release, atomics, dependencies, or same-address rules.

---

## 3. Pipeline

### Classic 5-Stage Pipeline

```
Stage 1    Stage 2    Stage 3    Stage 4     Stage 5
+------+   +------+   +------+   +-------+   +------+
|  IF  | → |  ID  | → |  EX  | → |  MEM  | → |  WB  |
| Fetch|   |Decode|   |Execute|  |Memory |   |Write |
| Instr|   |& Reg |   | ALU  |  |Access |   | Back |
+------+   +------+   +------+   +-------+   +------+
```

**Ideal**: One instruction completes every cycle (throughput = 1 IPC).

### Pipeline Hazards

#### Data Hazard
**Problem**: Instruction needs a result that isn't computed yet.
```
ADD R1, R2, R3    // writes R1 in WB stage (cycle 5)
SUB R4, R1, R5    // needs R1 in ID stage (cycle 3) — R1 not ready!
```

**Solutions**:
- **Forwarding/Bypassing**: Route result from EX output back to EX input — avoids stall
- **Stalling**: Insert bubble (NOP) and wait — simple but wastes cycles
- **Load-use hazard**: Load from memory (available after MEM stage) can't be fully forwarded — needs 1 stall cycle

#### Control Hazard
**Problem**: Branch instruction — don't know which instruction to fetch next.
```
BEQ R1, R2, LABEL    // branch decided in EX stage
???                    // what to fetch in the meantime?
```

**Solutions**:
- **Stall**: Wait until branch is resolved — wastes 2 cycles
- **Branch prediction**: Guess which way the branch goes, flush if wrong
  - Static: always predict not-taken, or backward-taken (loops)
  - Dynamic: Branch History Table (BHT), 2-bit saturating counter
- **Branch delay slot**: Execute the instruction after branch regardless (MIPS)

#### Structural Hazard
**Problem**: Two instructions need the same hardware resource simultaneously.
```
Example: Single memory port — IF and MEM both need memory in the same cycle.
```
**Solution**: Separate instruction and data memory/cache (Harvard architecture).

---

## 4. Virtual Memory

### Address Translation

```
CPU generates:  Virtual Address (VA)
                     |
                     v
               +----------+
               |   TLB    |  ← fast lookup (fully associative cache of page table entries)
               +----------+
              /            \
         TLB Hit         TLB Miss
            |               |
            v               v
    Physical Addr     Page Table Walk
    (access cache)    (in memory, slow)
                           |
                       +---+---+
                       |       |
                   Page in   Page NOT
                   memory    in memory
                      |         |
                      v         v
                 Update TLB   PAGE FAULT
                              (OS loads from disk)
```

### Virtual Address Breakdown (example: 32-bit VA, 4KB pages)

```
Page size = 4KB = 2^12 → Offset = 12 bits
VPN (Virtual Page Number) = 32 - 12 = 20 bits

VA: [ 20-bit VPN | 12-bit Page Offset ]
                       ↓ (translation)
PA: [ PPN (Physical Page Number) | 12-bit Page Offset ]
```

**Page offset stays the same** — only the page number gets translated.

### Page Table

```
Page Table (one per process):

VPN  →  PPN  | Valid | Dirty | Permission
  0  →  5    |   1   |   0   | R/W
  1  →  --   |   0   |   --  | --    ← not in memory (page fault if accessed)
  2  →  12   |   1   |   1   | R/W   ← dirty = modified, must write back
  3  →  7    |   1   |   0   | R-only
```

**Interview question**: "What happens on a page fault?"
1. CPU raises exception → trap to OS
2. OS finds a free physical frame (or evicts one)
3. OS loads the page from disk into the frame
4. OS updates the page table entry (PPN, valid=1)
5. OS restarts the instruction that caused the fault

**TLB**: Small, fast cache of recent VA→PA translations. Typically 64-256 entries, fully associative.

---

## 5. Interrupts

### Interrupt Handling Flow

```
1. Hardware asserts interrupt line
2. CPU finishes current instruction
3. CPU saves context:
   - Push PC (return address) to stack
   - Push status register (flags) to stack
   - Disable further interrupts (or mask lower priority)
4. CPU looks up ISR address from Interrupt Vector Table (IVT)
5. Jump to ISR (Interrupt Service Routine)
6. ISR executes — handles the event
7. ISR ends with return-from-interrupt instruction
8. CPU restores context (pop status, pop PC)
9. Resume normal execution
```

### Key Concepts

| Concept | Description |
|---------|-------------|
| **ISR** | Interrupt Service Routine — the handler function. Keep it SHORT. |
| **IVT** | Interrupt Vector Table — array of ISR addresses, indexed by interrupt number |
| **Priority** | Higher priority interrupts can preempt lower ones (nested interrupts) |
| **Latency** | Time from interrupt assertion to first ISR instruction — critical for real-time |
| **Polling vs Interrupt** | Polling: CPU checks status in a loop (wastes cycles). Interrupt: hardware notifies CPU (efficient) |
| **Edge vs Level triggered** | Edge: fires on transition (0→1). Level: fires as long as signal is high |

**Interview question**: "Why should ISRs be short?"
- Long ISRs block other interrupts, increase latency, and can cause missed events. Do minimal work in ISR (set a flag, copy data), process in main loop.

**Interview question**: "Edge vs level triggered — when to use which?"
- Edge: good for events (button press). Can miss if signal pulses while masked.
- Level: good for status (FIFO not empty). Won't miss, but must clear the source before returning or it fires again.

---

## 6. Bus Protocols (ARM AMBA)

### AXI / AHB / APB Comparison

```
                AXI                 AHB                 APB
              (Advanced)          (High-perf)         (Peripheral)
Speed:        Highest             Medium              Lowest
Complexity:   Most complex        Moderate            Simplest
Use for:      High-bandwidth      On-chip backbone    Low-speed peripherals
              (DDR, DMA)          (CPU, SRAM)         (UART, GPIO, Timer)
Channels:     5 separate          1 shared            1 shared
              (AR,R,AW,W,B)       bus                 bus
Burst:        Yes                 Yes                 No
Pipeline:     Yes (outstanding    No                  No
              transactions)
```

### AXI Key Concepts
- **5 channels**: Read Address (AR), Read Data (R), Write Address (AW), Write Data (W), Write Response (B)
- **Handshake**: Every channel uses `VALID`/`READY` handshake — transfer happens when both are high
- **Outstanding transactions**: Can issue multiple requests before getting responses (pipelined)
- **Burst types**: FIXED (same address), INCR (incrementing), WRAP (wrapping)

### AXI Handshake (most important concept)

```
         ____          ________
VALID: __|    |________|        |____
              ____          ____
READY: ______|    |________|    |____
              ^                 ^
          Transfer!         Transfer!
          (both high)       (both high)

Rule: VALID must not depend on READY (no deadlock)
      VALID asserts when data is available
      READY asserts when receiver can accept
```

**Interview question**: "Can VALID wait for READY before asserting?"
- No! VALID must not depend on READY. If both wait for each other, deadlock. VALID asserts when the sender has data, regardless of READY.

---

## 7. Endianness

```
Storing 0x12345678 at address 0x00:

Big-Endian (MSB first):          Little-Endian (LSB first):
Addr:  0x00  0x01  0x02  0x03   Addr:  0x00  0x01  0x02  0x03
Data:  0x12  0x34  0x56  0x78   Data:  0x78  0x56  0x34  0x12
       MSB →→→→→→→→→→→→ LSB           LSB →→→→→→→→→→→→ MSB
```

| | Big-Endian | Little-Endian |
|---|-----------|---------------|
| MSB stored at | Lowest address | Highest address |
| Used by | Network protocols (TCP/IP), Motorola | x86, ARM (default), RISC-V |
| Advantage | Human-readable in memory dump | Casting between types is free (char* to int*) |

**Interview question**: "How do you convert between endianness?"
- Byte-swap: `__builtin_bswap32()` in GCC, or manually:
```c
uint32_t swap(uint32_t x) {
    return ((x >> 24) & 0xFF)       |
           ((x >>  8) & 0xFF00)     |
           ((x <<  8) & 0xFF0000)   |
           ((x << 24) & 0xFF000000);
}
```

**ARM is bi-endian** — can be configured for either, but little-endian is default and most common.

---

## 8. DMA (Direct Memory Access)

### What is DMA?

```
Without DMA (CPU copies data):          With DMA:
CPU reads byte from peripheral          CPU programs DMA: src, dst, length
CPU writes byte to memory               DMA transfers data independently
CPU reads next byte...                   CPU is free to do other work
(CPU is 100% busy copying!)             DMA interrupts CPU when done
```

**Purpose**: Transfer data between memory and peripherals (or memory-to-memory) without CPU involvement.

### How DMA Works

```
1. CPU programs DMA controller:
   - Source address
   - Destination address
   - Transfer length
   - Direction (mem→peripheral, peripheral→mem, mem→mem)
   - Transfer mode
2. CPU starts DMA transfer
3. DMA controller takes over the bus and transfers data
4. DMA controller signals completion via interrupt
5. CPU handles the completion interrupt
```

### DMA Transfer Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Burst** | DMA takes bus, transfers entire block, releases bus | Large block transfers (disk read) |
| **Cycle-stealing** | DMA transfers one word, gives bus back to CPU, repeats | CPU needs bus access too |
| **Transparent** | DMA only uses bus when CPU isn't using it | No CPU impact, but slower |

**Interview question**: "When would you use DMA vs CPU copy?"
- DMA: large data transfers (audio buffers, display framebuffer, disk I/O). Frees CPU for computation.
- CPU: small transfers (a few bytes), or when data needs processing during transfer.

**Interview question**: "What is cache coherence problem with DMA?"
- DMA writes to memory, but CPU cache still has old data. Solutions:
  - Flush/invalidate cache before DMA read
  - Use non-cacheable memory regions for DMA buffers
  - Hardware cache coherence (snoop bus)

---

## Quick Reference Table

| Topic | Key Concept | Common Question |
|-------|-------------|-----------------|
| Memory hierarchy | Smaller=faster, locality principle | "Why do we need caches?" |
| Cache | 3 C's: compulsory, conflict, capacity | "Direct-mapped vs set-associative?" |
| Cache write | Write-back + write-allocate (common) | "Write-through vs write-back?" |
| Pipeline | 5 stages: IF/ID/EX/MEM/WB | "What are the 3 types of hazards?" |
| Forwarding | EX→EX or MEM→EX bypass | "How do you resolve data hazards?" |
| Virtual memory | VA → TLB → PA (or page fault) | "What happens on a page fault?" |
| TLB | Cache of page table entries | "What happens on a TLB miss?" |
| Interrupts | Save context → IVT → ISR → restore | "Why should ISRs be short?" |
| AXI handshake | VALID + READY both high = transfer | "Can VALID wait for READY?" (No!) |
| Endianness | Big=MSB first, Little=LSB first | "How do you byte-swap?" |
| DMA | Hardware data transfer, frees CPU | "DMA vs CPU copy — when to use?" |
| Cache coherence | MESI protocol (multi-core) | "What happens on a write to Shared?" |

---

## Embedded-Specific Concepts

### Volatile Keyword
```c
volatile int* reg = (volatile int*)0x40021000;
```
- Tells compiler: don't optimize away reads/writes to this address
- Use for: memory-mapped registers, shared variables with ISR, hardware status registers
- Without `volatile`: compiler might cache the value in a register and never re-read

### Memory-Mapped I/O vs Port-Mapped I/O
- **Memory-mapped**: Peripherals share address space with memory. Access with normal load/store. (ARM uses this)
- **Port-mapped**: Separate address space, special instructions (`IN`/`OUT`). (x86 uses this for legacy I/O)

### Watchdog Timer
- Hardware timer that resets the system if not periodically "kicked" (written to)
- Purpose: recover from firmware crashes or infinite loops
- Firmware must periodically reset the watchdog — if it hangs, watchdog expires and resets the chip
