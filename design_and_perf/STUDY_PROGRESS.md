# Study Progress & Review Q&A

## Day 1: CDC Fundamentals (2026-03-31)

### Modules Completed
- `sync_2ff.sv` + testbench — compiled, simulated
- `pulse_sync.sv` + testbench — compiled, simulated
- `async_fifo.sv` + testbench — compiled, simulated (ahead of schedule, Day 2-3 material)

### Quiz Q&A (Review Before Interview)

**Q1. Why does crossing clock domains cause metastability?**
The input signal transitions during the receiver FF's setup/hold window. The FF can't resolve to 0 or 1, so the output floats at an intermediate voltage for an unpredictable time. It's a timing violation at the receiver FF — the two clocks have no phase relationship, so eventually the input will change right at the receiver's clock edge.

**Q2. 2-FF synchronizer: latency? Why not multi-bit?**
- Latency: **2 receiver clock cycles** (one FF to absorb metastability, second FF to produce a clean output).
- Multi-bit fails because each bit resolves through its own synchronizer independently. Going from `01 -> 10`, the receiver might see `00` or `11` for one cycle — bits arrive **incoherently**. Use async FIFO for multi-bit CDC.

**Q3. clk_a = 500MHz, clk_b = 50MHz, 1-cycle pulse on clk_a. Can 2-FF on clk_b catch it?**
No. The pulse is 2ns (one clk_a cycle), but clk_b's period is 20ns. The pulse is gone before clk_b even gets one rising edge. Need a **pulse synchronizer** — convert pulse to toggle (persistent level change), synchronize the level, then regenerate pulse via XOR edge detect.

**Q4. Why does the pulse synchronizer use a toggle FF?**
A short pulse might vanish before the slow receiver clock can sample it. The toggle FF converts each pulse into a **persistent level change** — the level stays flipped indefinitely until the next pulse. This gives the slow receiver's 2-FF chain all the time it needs to capture it. On the receiver side, XOR of current vs previous synchronized value detects the level transition and regenerates a 1-cycle pulse.

**Q5. Async FIFO: why is gray code full detection "top 2 bits inverted, rest same" instead of just MSB like binary?**
In binary full detection: MSB different + rest same (simple — write pointer wrapped once past read pointer).
In gray code, the wrap-around pattern affects 2 bits. Consider 4-bit gray code (3-bit address, depth=8):

| Binary | Gray |
|--------|------|
| 0000   | 0000 |
| 0001   | 0001 |
| ...    | ...  |
| 0111   | 0100 |
| 1000   | 1100 |  <-- binary flips 1 bit (MSB), gray flips **2 bits** (bits 3 and 2)
| 1001   | 1101 |
| ...    | ...  |
| 1111   | 1000 |

At the binary midpoint (0111 -> 1000), binary changes only the MSB. But gray code changes from `0100` to `1100` — **both bit 3 and bit 2 flip**. So to detect that the write pointer has wrapped exactly once past the read pointer, you must check: top 2 bits inverted + remaining bits equal.

**Q6. When to use 2-FF vs pulse synchronizer vs async FIFO?**
- **2-FF synchronizer**: single-bit signal that stays stable for >= 2 receiver clock cycles (e.g., slow-to-fast, or level signals like status flags).
- **Pulse synchronizer**: single-bit pulse that might be too short for the receiver to catch (e.g., fast-to-slow, or any pulse shorter than 2 receiver cycles).
- **Async FIFO**: multi-bit data transfer across clock domains. Gray-coded pointers ensure only 1 bit changes at a time for safe synchronization.

**Q7. What is the minimum hold time for a 2-FF synchronizer input?**
The input must be stable for at least **2 receiver clock cycles**. This ensures both FFs in the chain get a chance to sample the stable value. If the signal changes faster than this, transitions can be missed entirely.

---

### PM Topics: Setup/Hold, Reset, Latch vs FF

#### Setup & Hold Violations

**Q8. Setup violation: you increase the clock period. Fixed? What about hold violation — does increasing clock period fix that?**
- Setup: **Yes.** Setup slack = clock_period - Tclk-to-q - Tcomb - Tsu. More period → more slack.
- Hold: **No.** Hold slack = Tclk-to-q + Tcomb - Th. No clock period term — frequency-independent.

**Q9. A path FF_A → 3 levels of AND gates → FF_B has a setup violation. Two fixes without changing the clock?**
1. **Pipeline it**: insert a FF in the middle, splitting 3 levels into 2 stages (trades 1 cycle latency).
2. **Restructure logic**: tree of 2-input ANDs reduces depth from 3 to 2 levels.
3. (Bonus) **Use faster cells**: swap HVT → LVT (more leakage, but faster).

**Q10. Why can't you fix a hold violation by changing clock frequency?**
Hold slack = Tclk-to-q + Tcomb - Th. There is no clock period term in this equation. Hold is a race condition between two edges of the **same clock** — it depends only on the data path delay vs hold requirement, not the clock frequency.

#### Sync vs Async Reset

**Q11. Clock might not be stable during power-on. Which reset type and why?**
**Async reset.** It takes effect immediately when rst_n goes low — no clock edge needed. Sync reset only triggers at a clock edge, so if the clock is dead or unstable at power-on, the chip never enters a known state.

**Q12. What is the danger of async reset *release*, and how do you fix it?**
When rst_n goes 0→1 (release), it's asynchronous to the clock. If release happens inside a FF's **recovery/removal window** (analogous to setup/hold for the reset pin) → metastability.
**Fix:** 2-FF reset synchronizer — assertion stays instant (async), release is synchronized to the clock:
```
rst_n (async) --> [FF1] --> [FF2] --> rst_n_sync (to all FFs)
                   ^clk      ^clk
```

**Q13. Synthesis report shows unexpected latches. Most likely coding mistake?**
Incomplete `if/else` or `case` without `default` in a combinational `always_comb` block. If any code path doesn't assign a value, synthesis must "remember" the old value → latch inferred.
```systemverilog
always_comb begin
    if (sel) out = a;
    // missing else → latch on 'out'
end
```
Fix: always assign a default at the top of the block, or ensure every branch assigns every signal.

#### Latch vs FF

**Q14. What is "time borrowing" and why does it require latches?**
With FFs, each pipeline stage gets exactly 1 clock period — hard boundary at the edge. With latches, the boundary is **transparent** during one clock phase. If stage A is slow (60% of period) and stage B is fast (40%), stage A's late signal can flow through the latch into stage B's time budget. A "borrows" slack from B.
FFs can't do this — they block data at the edge regardless of downstream slack.

**Q15. In a clock gating cell (ICG), why is there a latch on the enable signal?**
`gated_clk = clk & enable`. If `enable` toggles while `clk` is high → **glitch** on gated_clk (false clock edge → all downstream FFs fire incorrectly).
The latch is negative-level sensitive (transparent when clk=0). Enable can only update while clk is low. By the time clk goes high, the latched enable is locked and stable → no glitch.
```
enable --> [NEG LATCH] --> latched_en --> [AND] --> gated_clk
              ^clk                         ^clk
```

---

## Day 4: Arbiters (2026-03-31)

### Modules Completed
- `arbiter_fixed_priority.sv` + testbench — compiled, simulated
- `arbiter_round_robin.sv` + testbench — compiled, simulated

### Quiz Q&A (Review Before Interview)

#### Arbiter Fundamentals

**Q16. What is an arbiter? When do you need one?**
An arbiter decides who gets access when multiple requestors want the same shared resource simultaneously (e.g., multiple CPU cores accessing a memory bus). Input `req[N-1:0]` has multiple bits high; output `grant[N-1:0]` is one-hot — exactly one winner per cycle.

**Q17. Fixed-priority arbiter — how does it work in one line of code?**
`grant = req & (~req + 1)` — isolates the lowest set bit using the two's complement trick. `req[0]` has highest priority. LSB = highest priority because the two's complement trick naturally isolates the LSB — the convention follows the cheapest hardware implementation.

**Q18. Round-robin arbiter — what state does it need and why does it require a clock?**
It needs a **mask register** to remember who was last served. After granting bit `i`, the mask disables bits `[i:0]` so priority rotates. New mask: `~(grant | (grant - 1))`. The mask is a flip-flop → requires a clock. Fixed-priority has no state → no clock (pure combinational).

**Q19. Round-robin: what happens when all masked requests are zero?**
The mask has filtered out all active requestors (everyone in this round has been served). Fall back to unmasked fixed-priority on the raw `req` — this starts a new round. `grant = (masked_req != 0) ? masked_grant : unmasked_grant`.

**Q20. Two key bit tricks for arbiter design?**
- **Isolate lowest set bit:** `x & (~x + 1)` — used for fixed-priority grant.
- **Mask everything at and below a one-hot bit:** `~(x | (x - 1))` — used to generate the round-robin mask after a grant.

**Q21. Fixed-priority arbiter: what is the biggest problem?**
**Starvation.** Low-priority requestors may never get access if higher-priority requestors keep requesting. Round-robin solves this by rotating priority after each grant.

---

## Day 4 PM: Cache Hierarchy (2026-03-31)

### Quiz Q&A (Review Before Interview)

#### VIPT Aliasing

**Q22. VIPT aliasing check formula and example.**
Formula: `cache_size / associativity ≤ page_size`. You do NOT need cache line size for this check.
Example: 64KB L1, 4-way, 4KB pages → 64KB / 4 = 16KB > 4KB → **aliases!**
Index+offset = log2(16KB) = 14 bits, but page offset = 12 bits. The 2 extra index bits come from virtual page number → different virtual addresses can map to different sets for the same physical line.
Fixes: increase associativity to 16-way (64KB/16=4KB), use 16KB pages, or OS page coloring.

**Q23. Why VIPT instead of VIVT or PIPT?**
- VIVT: fast but aliasing — two virtual addresses can map to same physical address → incoherent copies in cache.
- PIPT: no aliasing but TLB is on critical path — must translate before indexing → slow.
- VIPT: index with virtual bits (parallel with TLB), tag with physical bits (after TLB). Fast + no aliasing (if formula is met).

**Q24. Why can snoops skip L1 in an inclusive hierarchy?**
L2 is a superset of L1. If a snooped line is not in L2, it's guaranteed not in L1. Saves power and avoids extra port on L1 tag array.

**Q25. L2 evicts a line in an inclusive hierarchy. What happens to L1?**
L1 must be **back-invalidated**. If L1 holds that line in Modified state, it must **write back dirty data first**, then invalidate. Otherwise the most recent data is lost.

**Q26. Why does Intel Skylake+ use NINE (non-inclusive non-exclusive) for L3?**
With many cores (6-16+), inclusive L3 wastes too much capacity — every line in every core's L1+L2 must also live in L3, filling it with duplicates. NINE lets L3 hold unique data not in any private cache, giving much better effective capacity. Requires a snoop filter/directory to track which cores hold which lines.

**Q27. Inclusive vs exclusive: effective capacity?**
- 32KB L1 + 256KB L2 **exclusive**: 32 + 256 = 288KB (no overlap, a line lives in one or the other).
- 32KB L1 + 256KB L2 **inclusive**: 256KB (L1's 32KB is duplicated in L2).

#### Inclusion Policy Summary

| | Inclusive | Exclusive | NINE |
|--|----------|-----------|------|
| Duplicate data? | Yes | No | Maybe |
| L2 evict → L1? | Back-invalidate | No | No |
| Snoop check | L2 only | Both L1+L2 | Snoop filter |
| Capacity | Wasted | Optimal | Good |
| Used by | Intel (older), ARM | AMD | Intel Skylake+ |

#### Cache Internals

**Q28. VIPT aliasing formula — why is it `cache_size / associativity`?**
`cache_size / associativity` = one way's worth of cache = the total address space covered by index + offset bits. Associativity doesn't consume address bits — all N ways share the same index. So address bits needed = `log2(cache_size / associativity)`. If this exceeds `log2(page_size)`, extra index bits come from virtual page number → aliasing.

**Q29. What is OS page coloring?**
When VIPT aliases (extra index bits above page offset), the OS constrains physical page allocation so that those extra bits always match between virtual and physical addresses. Pages are grouped by "color" (the value of those bits). Aliases must use the same color. Downside: constrains memory allocation, can cause fragmentation. Hardware fix (more associativity) preferred.

**Q30. Cache lookup structure: how does index + tag comparison work?**
Index selects a set in the tag SRAM and data SRAM (both read in parallel). N tag comparators fire in parallel comparing address tag against all N ways. The matching way's data is muxed to output. This is NOT a full CAM — index narrows to one set first, then only N comparisons (cheap). Full CAM (like TLB) compares against every entry (expensive, doesn't scale).

**Q31. Inclusive means L2 has a copy — does that mean write-through?**
No. Inclusive only means L2 has an **entry** (tag) for every line in L1. The data can be stale — L1 may hold a Modified (dirty) copy with newer data. On L2 eviction, L1 must write back dirty data before invalidating. Write-through is a separate policy (every write goes to L2 immediately) — most modern caches use write-back instead.

**Q32. Exact definitions: Inclusive vs Exclusive vs NINE.**
- **Inclusive:** L2 ⊇ L1 (always). Enforced by back-invalidation on L2 eviction.
- **Exclusive:** L2 ∩ L1 = ∅ (always). Lines swap between levels — L1 eviction sends line to L2, L2 hit moves line up to L1 and removes from L2.
- **NINE:** No guarantee. A line can be in both, either, or neither. No enforcement. Needs snoop filter to track what's where.

#### MSHRs, Replacement, Prefetch

**Q33. What are MSHRs and what is a non-blocking cache?**
MSHRs (Miss Status Holding Registers) track outstanding cache misses (4-16 entries). On a miss: check if an MSHR already tracks that address. If yes (secondary miss) → merge the requestor into the existing entry, no new memory request. If no (primary miss) → allocate new MSHR, send request to next level. When data returns, wake all waiting requestors. A **non-blocking cache** = cache with MSHRs that can keep servicing hits while misses are pending.

**Q34. What happens when all MSHRs are full?**
New misses must **stall** until an MSHR frees up. MSHR count limits memory-level parallelism — too few MSHRs bottleneck performance on memory-intensive workloads.

**Q35. Replacement policies: LRU vs Tree-PLRU vs RRIP.**
- **True LRU:** Track full access ordering. Needs `log2(N!)` bits per set. 16-way → 45 bits. Perfect eviction choice but expensive in hardware.
- **Tree-PLRU:** Binary tree of bits (N-1 per set). 16-way → 15 bits. Each access flips bits on the path. To evict, follow the tree to find approximate LRU victim. Not perfect but close, far cheaper.
- **RRIP:** 2-3 bit counter per line predicting re-reference interval. New lines inserted as "far reuse" (not MRU — prevents scan pollution). Hits set to "near reuse." Evict max-counter lines. Better than LRU for LLC with large/streaming worksets.

**Q36. Why is pure LRU bad for LLC with large working sets?**
When the working set exceeds cache capacity, LRU thrashes — every access evicts a line that will be needed again soon, cycling through the entire set with zero hits. RRIP fixes this by inserting new lines at low priority ("far reuse"), so a streaming scan doesn't evict hot data. Only lines that get re-accessed are promoted to high priority.

**Q37. Prefetcher types.**
- **Next-line:** Miss on line N → prefetch N+1. Catches sequential access. Simple.
- **Stride:** Track miss addresses per PC, detect constant stride. Catches `arr[0], arr[256], arr[512]...`
- **Stream:** Detect sequential streams, run ahead aggressively. Multiple stream trackers (8-32).

---

## Day 5: Pipeline Design (2026-04-01)

### Modules Completed
- `pipeline_5stage.sv` + testbench — compiled, simulated (7/7 tests pass)
- `pipeline_5stage_2wide.sv` + testbench — compiled, simulated (6/6 tests pass)

### Quiz Q&A (Review Before Interview)

#### Pipeline Fundamentals

**Q38. What are the 5 classic pipeline stages and what does each do?**
- **IF (Instruction Fetch):** Latch instruction from input into IF/ID pipeline register.
- **ID (Instruction Decode):** Read register file (with forwarding), decode control signals, detect hazards.
- **EX (Execute):** ALU computes result (arithmetic) or address (load/store). Result goes to EX/MEM register.
- **MEM (Memory):** Load reads data memory; store writes data memory. Result goes to MEM/WB register.
- **WB (Write Back):** Write result back to register file.

**Q39. What is a RAW (Read-After-Write) hazard and how does forwarding solve it?**
RAW: instruction B reads a register that instruction A writes, but A hasn't reached WB yet. Without forwarding, B reads stale data.
**Forwarding** (bypass): tap the result from a later pipeline stage (EX/MEM or MEM/WB) and feed it directly to the ID stage's operand mux, bypassing the register file. Priority: EX/MEM > MEM/WB > regfile (newest value wins).

**Q40. Why does a LOAD instruction cause a 1-cycle stall even with forwarding?**
A LOAD's data isn't available until the **end of the MEM stage** (it must read data memory). If the next instruction needs that value in its EX stage, there's no forwarding path — the data doesn't exist yet. Solution: insert a 1-cycle **bubble** (stall IF/ID, flush ID/EX to NOP). After the stall, the loaded value is in MEM/WB and can be forwarded.

**Q41. Load-use stall detection logic?**
```systemverilog
stall = id_ex.mem_read && (id_ex.rd != 0) &&
        (id_ex.rd == if_id.rs1 || id_ex.rd == if_id.rs2);
```
Check: is the instruction in EX a LOAD (`mem_read=1`)? Does it write to a non-zero register? Does the instruction in ID read that register?

**Q42. Why use `typedef struct packed` for pipeline registers?**
Industry standard. Each pipeline boundary has different fields (IF/ID needs rs1/rs2 addresses, ID/EX needs operand data, EX/MEM needs ALU result, etc.). Structs make it clear what data each stage passes to the next. `packed` ensures the struct maps to a flat bit vector — synthesizable and compatible with `<= '0` for reset.

**Q43. What are control signals and why do they travel through the pipeline?**
Control signals (e.g., `reg_write`, `mem_read`) are decoded **once** in the ID stage from the opcode, then propagated through pipeline registers alongside the data. Each stage uses the control signals to decide what to do (EX: which ALU op; MEM: read or write memory; WB: write register file or not). This avoids re-decoding the opcode at every stage.

#### Forwarding Bug: LOAD vs ALU

**Q44. Why must the forwarding path use `mem_result` instead of `ex_mem.alu_result`?**
For ALU instructions, `ex_mem.alu_result` is the correct result. But for LOADs, `ex_mem.alu_result` is the **memory address**, not the loaded data. The actual loaded data comes from the MEM stage's combinational read: `mem_result = dmem[ex_mem.alu_result]`. Using `mem_result` works for both: it equals `alu_result` for non-loads and `dmem[addr]` for loads.

#### 2-Wide Superscalar

**Q45. What is intra-group dependency and how does a 2-wide pipeline handle it?**
Intra-group dependency: pipe 1's source register matches pipe 0's destination register **in the same fetch group**. Since pipe 0 hasn't even started executing, there's no forwarding path. Solution: squash pipe 1 to NOP, issue only pipe 0. Pipe 1's instruction will be re-fetched next cycle.
```systemverilog
intra_dep = inst_reg_write[0] && (inst_rd[0] != 0) &&
            (inst_rd[0] == inst_rs1[1] || inst_rd[0] == inst_rs2[1]);
dual_issue = !intra_dep && !stall;
```

**Q46. How does the forwarding network scale in a 2-wide pipeline?**
- **1-wide:** 2 operands × 2 forward sources (EX/MEM, MEM/WB) = **4 comparators**
- **2-wide:** 4 operands × 4 forward sources (EX/MEM[0], EX/MEM[1], MEM/WB[0], MEM/WB[1]) = **16 comparators**
Forwarding priority: EX/MEM[0] > EX/MEM[1] > MEM/WB[0] > MEM/WB[1] > regfile. Pipe 0 has higher priority within the same stage because it's the older instruction in program order.

**Q47. What happens when both pipes write to the same register in WB?**
Pipe 0 writes first, pipe 1 writes second. Since pipe 1 is the **newer** instruction in program order, its value wins — which is correct (last-writer-wins semantics). In SystemVerilog, the two `if` blocks in the same `always_ff` execute sequentially, so pipe 1's write naturally overwrites pipe 0's.

**Q48. 2-wide load-use stall — how many comparisons?**
Must check both EX pipes against both ID instructions: 2 EX loads × 4 ID operands = **8 comparisons**. If either EX pipe has a LOAD whose rd matches any ID operand, stall both pipes.

**Q49. What extra hardware does 2-wide superscalar need vs 1-wide?**
| Resource | 1-wide | 2-wide |
|----------|--------|--------|
| Pipeline registers | 1 set | 2 sets |
| Register file read ports | 2 | 4 |
| Register file write ports | 1 | 2 |
| ALUs | 1 | 2 |
| Memory ports | 1R+1W | 2R+2W |
| Forwarding comparators | 4 | 16 |
| Dependency check | None | Intra-group (2 comparisons) |

The forwarding network and multi-port register file are the main area/timing costs. This is why most designs cap at 4-6 wide — the forwarding network grows as O(width²).

### Pipeline Deep-Dive Quiz (2026-04-02)

**Q50. What is `rs1_data` in the pipeline — register or wire? What drives it?**
Wire (combinational signal). Driven by the forwarding mux output. The mux selects between `mem_result` (from EX/MEM stage), `mem_wb.result` (from MEM/WB stage), or `regfile[rs1]` (default). The wire connects the forwarding mux output to the `id_ex.rs1_data` pipeline register input.

**Q51. Why does the forwarding mux use `mem_result` instead of `ex_mem.alu_result`?**
For ALU instructions, `ex_mem.alu_result` is the correct result. But for LOADs, `ex_mem.alu_result` holds the **memory address**, not the loaded data. `mem_result` is the output of the MEM-stage mux: it reads `dmem[addr]` for LOADs and passes through `alu_result` for ALU ops. So `mem_result` always has the correct value regardless of instruction type.

**Q52. What is the critical path in a 5-stage pipeline with forwarding? Trace the full chain.**
The MEM-to-ID forwarding path for LOADs:
`ex_mem (Q output)` → load/ALU mux (`mem_read` select) → SRAM read (`dmem[addr]`) → forwarding mux (comparator + select) → `id_ex (D input)`
This is two muxes plus an SRAM access in one cycle. The SRAM access dominates. Fix: split MEM into 2 stages, or accept a 2-cycle load-use penalty.

**Q53. During a load-use stall, what happens to `if_id` and `id_ex` on the same clock edge?**
- `if_id` **holds** its current value (keeps the instruction for retry next cycle)
- `id_ex` is **flushed to zero** (bubble inserted to prevent the held instruction from executing twice)
Rule: upstream holds, downstream flushes. This happens on a single clock edge.

**Q54. Why don't EX and MEM stages need stall logic?**
The bubble (`'0`) inserted into `id_ex` during the stall naturally flows downstream through EX → MEM → WB. Those stages always advance unconditionally — they just see a NOP pass through and do nothing. No special logic needed.

**Q55. Why does `if_id <= '0` work as a bubble for a packed struct?**
`'0` sets all bits to zero. The critical fields: `reg_write=0` (no register write), `mem_read=0` (no memory access), `op=000=OP_NOP`. These ensure the bubble does nothing as it flows through the pipeline. This works because we designed `OP_NOP=0` and all control signals default to inactive at zero.

**Q56. How does the synthesis tool implement the stall (clock enable) on `if_id`?**
As an ICG (Integrated Clock Gating) cell: a negative-level-sensitive latch + AND gate. When `stall=1`, the ICG blocks the clock — the flip-flop never sees a clock edge, so it holds its value naturally. The latch prevents glitches on the enable signal from creating false clock edges. This saves power vs. the feedback-mux alternative.

**Q57. The forwarding priority is EX/MEM > MEM/WB > regfile. Why does EX/MEM win?**
EX/MEM holds the **newer** (younger) instruction's result. If two in-flight instructions both write to the same `rd`, the most recent one must win — that's program-order correctness. EX/MEM is closer to ID than MEM/WB, meaning it contains a younger instruction. Forwarding the older value would give the wrong result.

**Q58. With 2 FUs in a 1-wide pipeline, what new forwarding source is needed?**
`id_ex` — forwarding the **combinational ALU result** from the EX stage. With alternating dispatch to 2 FUs, back-to-back dependent instructions land in different FUs. When the consumer is in ID, the producer is still in `id_ex` (not yet in `ex_mem`). So we must forward from `id_ex` using the combinational ALU output. This doesn't work for LOADs (only have the address), which is why the load-use stall still applies.

**Q59. In OoO designs, why can't we use a single global stall wire?**
Different structures (issue queue, ROB, load queue, store queue) stall independently. A cache miss stalls only that memory instruction while ALU instructions keep issuing. Queues between stages absorb timing mismatches. Each structure uses its own valid/ready handshake or credit-based flow control instead of a global stall.

### Skid Buffer + Valid/Ready Handshake (2026-04-02)

#### Module Completed
- `skid_buffer.sv` + testbench — compiled, simulated (5/5 tests pass)

#### Concept Q&A

**Q60. What problem does a skid buffer solve?**
It breaks the combinational `ready` path between modules. Without it, each module's `ready` depends on the next module's `ready`, creating a long combinational chain across every hop. The skid buffer replaces this with `up_ready = !buf_valid` — a local register output with no dependency on downstream.

**Q61. How does a skid buffer achieve zero latency?**
When the buffer is empty, `dn_data = up_data` is a combinational wire through a mux (selected by `buf_valid=0`). No register in the data path — data passes straight through in the same cycle. The register only activates during backpressure.

**Q62. What are the 4 operating cases of a skid buffer?**
| `buf_valid` | `up_valid` | `dn_ready` | Action |
|---|---|---|---|
| 0 | 1 | 1 | **Pass-through** — wire, no buffering |
| 0 | 1 | 0 | **Catch** — save `up_data` into buffer |
| 1 | X | 1 | **Drain** — downstream takes buffered data |
| 1 | X | 0 | **Hold** — nothing moves, wait |
When `buf_valid=1`, `up_valid` doesn't matter because `up_ready=0` — upstream is blocked.

**Q63. How does upstream get stalled when the buffer is full?**
`up_ready = !buf_valid`. When buffer is full, `up_ready=0`. The valid/ready protocol requires the sender to hold `valid` and `data` stable when `ready=0`. No special stall logic needed — the protocol enforces it.

**Q64. Why can't we do "drain + catch" (swap) on the same cycle?**
To swap, `up_ready` must be `!buf_valid | (buf_valid & dn_ready)` — now `dn_ready` appears combinationally in `up_ready`, which is exactly the timing path the skid buffer was designed to break. The swap gives full throughput but re-introduces the problem.

**Q65. What is the throughput under sustained backpressure? How to fix?**
1 transfer per 2 cycles — one cycle to drain, one cycle to accept. Fix: use a 2-entry FIFO, which can accept and drain simultaneously (writing to different entries). `up_ready = (count != 2)` is purely registered, no combinational ready path, full throughput.

**Q66. How does the `ready` signal propagate without a skid buffer?**
Each module has its own combinational logic to generate `ready` (AND, OR, etc.), and each module's `ready` depends on the next module's `ready`. Across 5-10 hops, this creates one long combinational chain. It's not specifically muxes — it's whatever logic each module uses to decide "can I accept?" A skid buffer cuts this chain entirely.

**Q67. When do you need more than 2 entries (i.e., a real FIFO)?**
Deeper FIFOs solve a different problem — **rate mismatch** or **burst absorption**, not timing decoupling. Examples: async FIFO for clock domain crossing, depth >= burst length for AXI burst absorption, buffering when producer is faster than consumer. For pure timing decoupling (breaking the ready path), 1-2 entries is sufficient.

**Q68. Pipeline stall vs valid/ready handshake — when to use which?**
| | CPU Pipeline | AXI / Bus |
|---|---|---|
| Mechanism | Stall + bubble | Valid/ready handshake |
| Control | Global stall wire | Per-link, independent |
| Data loss prevention | Hold upstream register | Sender holds data until ready |
| Gap insertion | Bubble (flush to zero) | Sender deasserts valid |
| Coupling | Tight — stages move in lockstep | Loose — each link independent |
| Why | Stages need to see each other's data (forwarding) | Modules are independent, just moving data |

### AXI-Lite Slave + Interconnect (2026-04-02)

#### Modules Completed
- `axi_lite_slave.sv` + testbench — 5/5 tests pass (write/read REG0, all 4 regs, byte strobe byte 0, byte strobe byte 2, reset clears)
- `axi_lite_interconnect.sv` + testbench — 5/5 tests pass (slave 0 w/r, slave 1 w/r, slaves 2+3, slave isolation, byte strobe through IC)

#### Quiz Q&A (Review Before Interview) — Score: 5.5/8

**Q69. Name the 5 AXI-Lite channels and their direction (master→slave or slave→master).**
- **AW** (Write Address): master→slave — carries write address
- **W** (Write Data): master→slave — carries write data + byte strobes (wstrb)
- **B** (Write Response): slave→master — carries write response (bresp)
- **AR** (Read Address): master→slave — carries read address
- **R** (Read Data): slave→master — carries read data + response (rresp)

**Q70. What is `wstrb` and why is it needed?**
Byte-enable mask (4 bits for 32-bit data). Each bit enables writing one byte lane. Allows partial writes — e.g., `wstrb = 4'h1` writes only byte 0. Uses indexed part-select `regs[idx][b*8 +: 8]` because SystemVerilog forbids variable indices on both sides of `:`.

**Q71. What does `s_awready = !s_bvalid | s_bready` mean?**
The slave can accept a new write address when either: (1) no pending B response (`!s_bvalid`), or (2) the pending B response is being consumed this cycle (`s_bvalid & s_bready`). Same pattern as skid buffer — "I'm free, or I'm about to be free."

**Q72. In AXI-Lite, why is the slave's perspective "output ready, input valid" — opposite of what you'd expect?**
The slave is the *responder*. On AW/W/AR channels, the master drives valid (it has a request) and the slave drives ready (it can accept). On B/R channels, the slave drives valid (it has a response) and the master drives ready (it can accept). Valid = "I have data for you", ready = "I can take data."

**Q73. What is the address decoding in an AXI-Lite interconnect?**
Top bits of the address select which slave, lower bits are the offset within that slave's register space. For 4 slaves with 8-bit address: `wr_sel = m_awaddr[7:6]` (top 2 bits select slave 0-3), `s_awaddr = m_awaddr[3:0]` (lower 4 bits = register offset).

**Q74. Is the interconnect combinational or sequential?**
Purely combinational — just muxes. It routes valid/data from master to selected slave, and routes ready/response from selected slave back to master. No registers, no state. Skid buffers are placed at interconnect boundaries (not inside) when timing requires it.

**Q75. What is the difference between AXI-Lite and AXI4 full?**
AXI4 adds: burst transfers (AWLEN/ARLEN — up to 256 beats), transaction IDs (AWID/BID/ARID/RID for out-of-order responses and multiple outstanding), cache/lock/QoS signals, and wider address/data. AXI-Lite is one transaction at a time, no bursts, no IDs — for simple register-mapped peripherals.

**Q76. Why does AXI separate write address and write data into different channels?**
So they can be accepted independently — the slave might accept the address before the data or vice versa. In AXI4 full, this enables pipelining: the address can arrive before data, and data can stream in bursts. In AXI-Lite, the practical benefit is simpler handshaking (each channel has its own valid/ready).

---

## Day 6: RSD DCache 1R1W Redesign (2026-04-02)

### Milestone Completed
- Reworked RSD `DCache` from the original generic 2-port read/write array model to a true `1R1W` cache-array contract
- Verified the redesign with the repo's Verilator `test-1` regression: full level-1 suite passes
- `test-2` is still blocked by missing external `RSD_ENV` software/compliance assets, not by RTL failure

### Main RTL Changes
- Split the DCache array interface into one read-side slot and one write-side slot
- Added write-slot reservation for read-hit updates so the cache still supports store-hit and flush behavior under `1R1W`
- Replaced `BlockTrueDualPortRAM` usage in `DCache` with `BlockDualPortRAM`
- Fixed follow-up correctness issues:
  - replayed loads may complete from either the live MSHR or the newly filled cache line
  - store commit must stop waiting once the related MSHR has already been invalidated
  - MSHR fill / store reservation arbitration needed fairness to avoid deadlock

### Quiz Q&A (Review Before Interview)

**Q50. Why is converting a cache from 2RW to 1R1W not just a memory-wrapper change?**
Because the original RTL may assume two fully capable array ports in the same cycle. If the new memory only supports one read port and one write port, the arbitration and update timing must be redesigned. That changes the cache control logic, not just the storage primitive.

**Q51. What is the key control idea in a 1R1W DCache?**
Treat the array as one read-side slot plus one write-side slot. A read request can reserve the next-cycle write slot if it may need to update the line after tag compare. This preserves store-hit and flush behavior without violating the `1R1W` contract.

**Q52. What bug can happen if refill writes always beat store-hit reservations?**
The store queue can stop draining. A committed store needs a read now and a write on the following cycle. If MSHR refill traffic keeps taking the write side forever, the store never completes and the core can deadlock.

**Q53. After a cache fill, why can a replayed load complete from either MSHR or cache?**
Under the old model, the replay path could rely on the live MSHR entry. Under the new `1R1W` model, once the fill is accepted and written into the cache, the line may be visible from the cache before the old replay assumptions clear. The replay logic must accept both sources.

**Q54. If the redesign is functionally correct but slower, what should regression do?**
Do not call it a logic bug. First check whether the program eventually reaches the correct final PC/register state with a larger cycle budget. If it does, update the regression's `MaxTestCycles` to match the new microarchitectural latency.

### Follow-On: DCache SRAM Wrapper Bring-Up
- Added a new `DCacheSRAM.sv` wrapper file for the `1R1W` DCache arrays
- Data array plan:
  - `256 x 64` line storage per way
  - implemented as `2 x 128 x 64` depth banks
  - uses macro bit-write masking to preserve byte writes
- Tag array plan:
  - `256 x 22` tag+valid storage per way
  - implemented as `2 x 128 x 32` depth banks with width padding
- Dirty and replacement arrays are still left on generic inferred RAM for now because they are tiny
- Verilator now uses dedicated functional models of the same TSMC16 SRAM macro interfaces, so cache simulation stays on the SRAM-macro path without reverting to the original `BlockDualPortRAM`

### Current Validation Status
- Added a local Verilator-only SRAM model file that implements the exact cache macro interfaces used by RSD:
  - `TS6N16ADFPCLLLVTA128X64M4FWSHOD`
  - `TS6N16ADFPCLLLVTA128X32M4FWSHOD`
- Updated the Verilator build flow to use the SRAM-macro path directly and fixed the host-side PCH build quirk in the generated make flow
- Full `test-1` now passes with the SRAM-backed cache path enabled in simulation
- Focused macro-path checks also pass:
  - `DCache`
  - `MemoryDependencyPrediction`
  - `ReplayQueueTest`
- The next ASIC-facing step is to resume the physical-design flow knowing that the cache macro path is now verified on both:
  - DC macro mapping
  - functional regression

### Real TSMC16 Cache Macro Integration
- Enabled the real cache macro path in the dedicated DC flow with:
  - TSMC16 stdcell `.db`
  - TSMC16 SRAM `.db`
  - synthesis defines `RSD_SYNTHESIS_DESIGN_COMPILER` and `RSD_USE_TSMC_CACHE_SRAM`
- Proved real macro mapping directly in Design Compiler by synthesizing the wrappers themselves:
  - `ICacheWaySRAM_TSMC16`
  - `DCacheLineSRAM_TSMC16`
  - `DCacheTagSRAM_TSMC16`
- The mapped netlists now contain real TSMC SRAM macro cells:
  - `TS6N16ADFPCLLLVTA128X64M4FWSHOD`
  - `TS6N16ADFPCLLLVTA128X32M4FWSHOD`
- Wrapper-level DC proof summary:
  - `ICacheWaySRAM_TSMC16`: 2 x `128x64` + 2 x `128x32`
  - `DCacheLineSRAM_TSMC16`: 2 x `128x64`
  - `DCacheTagSRAM_TSMC16`: 2 x `128x32`
- Ran top-level `Core` elaboration under the same real DC flow and confirmed the cache wrapper blocks are linked into the full design hierarchy:
  - `ICacheWaySRAM_TSMC16`
  - `DCacheLineSRAM_TSMC16`
  - `DCacheTagSRAM_TSMC16`

### Honest Status After Integration
- `ICache` main storage is now truly integrated to real TSMC16 SRAM macros in the DC flow
- `DCache` main line and tag storage are now truly integrated to real TSMC16 SRAM macros in the DC flow
- Small cache-side arrays such as dirty/replacement state are still generic inferred RAM/logic, which is reasonable because they are tiny
- The remaining runtime bottleneck in full-core synthesis is no longer cache storage. It is the large inferred OoO memories such as issue queues, rename tables, and register-file-related structures

### Follow-On: BTB / Gshare / MDP SRAM Integration
- Continued the ASIC-minded storage cleanup after finishing `L1I` and `L1D`
- Chose the next blocks using the rule:
  - map each structure to the implementation style that makes sense in a real OoO ASIC
- Result:
  - `BTB`: moved to real SRAM-backed storage
  - `Gshare` PHT: moved to real SRAM-backed storage
  - `MemoryDependencyPredictor`: moved to real SRAM-backed storage
  - `ReplayQueue`: intentionally left as logic for now

### Why ReplayQueue Was Deferred
- I tried a `ReplayQueue` SRAM conversion first, but it was not a clean fit
- The synchronous `1R1W` version passed elaboration but caused real functional regressions in `ReplayQueueTest`
- That is a sign the queue behavior is more timing-sensitive than the regular predictor/storage tables
- For this project, it is more realistic to keep `ReplayQueue` as logic for now instead of forcing a bad SRAM mapping

### What Changed In RTL
- Added [BTBSRAM.sv](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Src/FetchUnit/BTBSRAM.sv)
  - replaces the old inferred `BTB` table with banked `128x32` TSMC16 macros
  - current mapping is `1024 x 19`, implemented as `2` read banks and `4` depth slices per bank
- Added [GshareSRAM.sv](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Src/FetchUnit/GshareSRAM.sv)
  - packs the `2048 x 2` PHT counters into `32-bit` macro words
  - current mapping is `2` read banks backed by `2` total `128x32` macros
- Added [MDTSRAM.sv](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Src/Scheduler/MDTSRAM.sv)
  - packs the `1024 x 1` memory-dependency bits into `32-bit` macro words
  - current mapping is `2` read banks backed by `2` total `128x32` macros
- Rewired:
  - [BTB.sv](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Src/FetchUnit/BTB.sv)
  - [Gshare.sv](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Src/FetchUnit/Gshare.sv)
  - [MemoryDependencyPredictor.sv](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Src/Scheduler/MemoryDependencyPredictor.sv)
- Updated [CoreSources.inc.mk](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Src/Makefiles/CoreSources.inc.mk) to compile the new wrappers

### Verification
- Design Compiler elaboration accepted the new wrappers in the full `Core` hierarchy
- Rebuilt the Verilator simulator on the SRAM-macro path
- Focused checks passed:
  - `ControlTransfer`
  - `ControlTransferZynq`
  - `MemoryDependencyPrediction`
  - standalone `Gshare`
- Full `test-1` passed again after the BTB/Gshare/MDP integration

### Small Tooling Improvement
- Updated [Makefile.verilator.mk](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Src/Makefile.verilator.mk) to build the generated Verilator C++ model with:
  - `-j16`
  - `-fuse-ld=gold`
- This keeps the regression rebuild practical on the current server

### Honest Status Now
- `ICache`: SRAM-backed and verified
- `DCache`: SRAM-backed and verified
- `BTB`: SRAM-backed and verified
- `Gshare`: SRAM-backed and verified
- `MemoryDependencyPredictor`: SRAM-backed and verified
- `ReplayQueue`: still logic, by design for now
- Remaining major non-cache/non-predictor blocks are still things like:
  - issue queue
  - register file
  - rename / active-list structures

### Full DC Rerun After Cache + Predictor SRAM Work
- Reran full `Core` synthesis in TSMC16nm after integrating SRAM-backed `ICache`, `DCache`, `BTB`, `Gshare`, and `MemoryDependencyPredictor`
- Used the updated DC flow with `set_host_options -max_cores 16`
- Run directory:
  - `/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/DesignCompiler/runtime_full_sram_16c`

### Final Synthesis Results
- Wall-clock runtime:
  - `real 3064.62s` which is about `51m 05s`
- QoR summary from [qor.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/DesignCompiler/runtime_full_sram_16c/reports/qor.rpt):
  - `Macro Count`: `28`
  - `Leaf Cell Count`: `500140`
  - `Combinational Cell Count`: `341451`
  - `Sequential Cell Count`: `158689`
  - `Design Area`: `386213.269227`
  - `Critical Path Length`: `2.20`
  - `Critical Path Slack`: `7.68`
  - `Total Negative Slack`: `0.00`
  - `No. of Violating Paths`: `0`
  - `Worst Hold Violation`: `-0.26`
  - `Total Hold Violation`: `-8109.75`
  - `No. of Hold Violations`: `160755`
- Generated outputs:
  - [Core.ddc](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/DesignCompiler/runtime_full_sram_16c/mapped/Core.ddc)
  - [Core.v](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/DesignCompiler/runtime_full_sram_16c/mapped/Core.v)
  - [area.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/DesignCompiler/runtime_full_sram_16c/reports/area.rpt)
  - [timing.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/DesignCompiler/runtime_full_sram_16c/reports/timing.rpt)

### What The Numbers Mean
- Setup is clean at the current `10ns` synthesis target
- Hold is still very noisy, which is expected before CTS and physical implementation
- The macro count increased from the earlier cache-only baseline because `BTB`, `Gshare`, and `MDP` are now also using real SRAM-backed storage
- The mapped netlist contains:
  - `8` instances of `TS6N16ADFPCLLLVTA128X64M4FWSHOD`
  - `20` instances of `TS6N16ADFPCLLLVTA128X32M4FWSHOD`

### Main Remaining Bottlenecks
- From [area.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/DesignCompiler/runtime_full_sram_16c/reports/area.rpt), the next dominant structures are now:
  - `registerFile`: `151451.2884` area, about `39.2%`
  - `dCache`: `38894.0077` area, about `10.1%`
  - `iCache`: `37285.4124` area, about `9.7%`
  - `issueQueue`: `31024.5817` area, about `8.0%`
  - `btb`: `27340.2134` area, about `7.1%`
  - `activeList`: `25732.8062` area, about `6.7%`
  - `brPred`: `7349.4098` area, about `1.9%`
- This confirms that the remaining heavy problem is not the cache/predictor tables anymore. It is the OoO core state structures, especially:
  - register file
  - issue queue
  - active list / rename-related multiported state

## Day 8: First Innovus Bring-Up On RSD Core

### Goal
- Start the real physical-design flow on the SRAM-backed `Core` netlist from:
  - [Core.v](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/DesignCompiler/runtime_full_sram_16c/mapped/Core.v)
  - [Core.sdc](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/DesignCompiler/runtime_full_sram_16c/mapped/Core.sdc)
- Use a loose first target:
  - `10ns` clock period
  - equivalent to `100 MHz`

### New Innovus Flow
- Added a dedicated Innovus project under:
  - `/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus`
- Added:
  - [Makefile](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/Makefile)
  - [innovus_mmmc_qrc.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_mmmc_qrc.tcl)
  - [innovus_flow.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_flow.tcl)
  - [rsd_core_apr.sdc](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/rsd_core_apr.sdc)
- Used:
  - TSMC16nm tech LEF
  - stdcell LEF/lib
  - SRAM LEF/lib
  - QRC tech file

### What Worked
- `init` completed cleanly and saved:
  - `/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/db/init.enc`
- `place` completed cleanly and saved:
  - `/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/db/place.enc`
- `cts` completed cleanly and saved:
  - `/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/db/cts.enc`

### Placement Snapshot
- Early global-route congestion after placement was effectively clean:
  - `0.00%` horizontal overflow
  - `0.00%` vertical overflow
- The main pre-CTS setup problem was concentrated in `ReplayQueue`
- Placement reports:
  - [place_area.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/place_area.rpt)
  - [place_timing.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/place_timing.rpt)

### CTS Snapshot
- CTS runtime:
  - about `19m 15s` real time
- Clock-tree summary:
  - `2325` clock buffers
  - `158717` sinks
  - insertion delay about `0.212ns` average
  - skew about `0.019ns` vs `0.013ns` target
- CTS completed with no tool errors and saved:
  - [cts_timing.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/cts_timing.rpt)
- Main remaining CTS setup issue:
  - `ReplayQueue` paths around `-0.50ns`

### First Route Attempt: Important Findings
- Clock-only / early route portion looked healthy:
  - only `4` route DRCs at one stage
  - antenna `0` at that point
- Full signal routing showed two important issues:
  1. The flow had not globally connected standard-cell body-bias pins
     - `VPP`
     - `VBB`
     - This caused repeated `NRIG-34` warnings for CTS-created cells in the route log
  2. The long timing-driven route cleanup became expensive and did not converge cleanly in the first pass before I stopped it
     - one stage reached `6675` DRC violations
     - first optimization iteration reduced that to `2504`
     - antenna also rose into the `~1900-2100` range during that route optimization

### Flow Fix Already Applied
- Patched [innovus_flow.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_flow.tcl) to globally connect:
  - `VPP -> VDD`
  - `VBB -> VSS`
- Also made the PG connection helper run after checkpoint restore, not just during initial import
- Verified with a short rerun:
  - the old `NRIG-34` body-bias warnings no longer appeared at the same route stage

### Current Physical-Design Status
- Real APR flow is alive and usable
- Clean milestones achieved:
  - import
  - floorplan
  - placement
  - CTS
- Route is not closed yet
- The next work is route-strategy cleanup, not more front-end/RTL change

### Immediate Next Steps
- Rerun route with the fixed `VPP/VBB` global-net connection
- Let the full signal-route optimization finish once with the corrected PG setup
- Examine:
  - final route DRC count
  - antenna count
  - connectivity/LVS-style report
  - post-route timing
- If route is still unstable, adjust route strategy before pushing toward the final target of:
  - `0 DRC`
  - `0 LVS/connectivity`

## Day 11: RSD Innovus Route Debugging and Floorplan Iteration

### What We Learned From The Full Route Flow
- The PG/body-bias fixes were real and necessary:
  - `VPP/VBB/VDDM` connection warnings are gone
- Restricting signal routing to `M1..M10` and turning off aggressive SI/timing routing cleaned up the first major route phase:
  - no AP-layer routing
  - antenna reached `0`
  - one routed phase dropped to only `4` remaining M2 DRCs
- But the full `routeDesign` still has a second major signal-routing phase, and that phase is still the real blocker
  - it climbed to thousands of DRCs again
  - it was worse than the earlier `~1150` plateau in the interrupted experiments

### Conclusion
- The remaining problem is no longer a simple route-option bug
- The remaining problem is physical structure:
  - floorplan
  - macro spacing
  - local routing access around macros and dense logic

### Structural Fix Applied
- Reworked the Innovus init stage in:
  - [innovus_flow.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_flow.tcl)
- Changes:
  - floorplan target changed from `0.40` to `0.30`
  - core margins increased from `60` to `80`
  - added `5um` halo around all hard macros with `addHaloToBlock 5 5 5 5 -allMacro`

### Rebuilt Checkpoints
- `init` reran cleanly with the larger floorplan
- `place` reran cleanly from scratch and saved a new:
  - [place.enc](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/db/place.enc)

### New Placement Snapshot
- placement runtime:
  - about `19m 14s` real time
- early global-route congestion is still essentially clean:
  - `Overflow: 1 = 0 (0.00% H) + 1 (0.00% V)`
  - see [place_congestion.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/place_congestion.rpt)
- the main timing hotspot is still `ReplayQueue`
  - pre-CTS setup is about `-0.533ns`
  - see [place_timing.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/place_timing.rpt)

### Current Status
- APR bring-up remains healthy through:
  - init
  - place
  - CTS on the earlier checkpoint
- The route flow is alive, but full route is still not converged
- We now know the next backend work is structural APR tuning, not more SRAM/RTL work

### Next Step
- Rerun `CTS -> route` on the rebuilt larger-floorplan checkpoint
- Compare whether the new geometry reduces the second full-route DRC explosion
- If not, move to deliberate macro placement rather than more router-option tuning

## Day 12: RSD PG Connectivity Root-Cause Debug

### What Changed In The Innovus Flow
- Updated [innovus_flow.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_flow.tcl) to strengthen the power-grid strategy:
  - added `M8/M9` PG stripes during init
  - reran `sroute` after CTS and again before route
  - disabled post-route wire spreading so the router does not reintroduce cleanable DRC after a zero-DRC detailed-route phase
  - added a bounded `ecoRoute -fix_drc` loop in the route stage

### Important Backend Diagnosis
- The remaining special-connectivity failures are not just generic PG-routing misses.
- I checked the TSMC16 stdcell LEF and confirmed:
  - ordinary standard cells expose `VDD/VSS` on `M1`
  - but `VPP/VBB` are on `NW/PW` well layers, not normal signal-routing metal
- I also checked the synthesized `Core.v` and found:
  - no `TAPCELL` instances were present in the mapped netlist

### Why This Matters
- That means the repeated `VPP/VBB` opens are structurally consistent with missing or insufficient well-tap / secondary-power handling.
- A plain `corePin` or `blockPin` `sroute` pass is not enough by itself.
- The backend needs body-bias-aware tap cells plus explicit secondary-power handling.

### New Structural Fix Applied
- Updated the `place` stage in [innovus_flow.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_flow.tcl) to insert well taps:
  - `addWellTap -cell TAPCELLBWP16P90_VPP_VBB -cellInterval 30 -prefix TAP`
  - followed by `refinePlace`
- Also updated the PG routing helper to include a dedicated `secondaryPowerPin` pass instead of only treating everything like ordinary `corePin` routing.

### Current Status
- This is a real flow fix, not a guess:
  - it directly addresses the physical meaning of `VPP/VBB`
  - it follows the same class of lesson from `soc_design`: solve the actual PG/connectivity structure first, then judge final LVS-style clean reports
- I started a fresh `place` rerun with tap-cell insertion and the revised PG flow, then stopped it rather than leaving a blind long job running.

### Next Step
- Re-run `place` fully with:
  - well taps inserted
  - secondary-power-aware `sroute`
- Then continue `CTS -> route` and recheck:
  - `route_special_connectivity.rpt`
  - `route_drc.rpt`
  - post-route timing

## Day 13: RSD Post-Route DRC Root Cause

### What Changed In The Flow
- Updated [innovus_flow.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_flow.tcl) again so backend iteration is cheaper:
  - added [route_raw.enc](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/db/route_raw.enc) save point immediately after `routeDesign`
  - added [route_clean.enc](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/db/route_clean.enc) save point after the post-route DRC cleanup loop
  - added a new `route_finish` stage so later debug can restart from `route_raw.enc` instead of rerunning the full route
  - disabled post-route filler insertion by default, so filler behavior does not hide the real routed DRC state

### What We Learned
- The backend problem is no longer generic signal-route congestion.
- During route:
  - signal-route DRC falls from about `10.7k` down to low double digits during the router’s own optimization loop
  - but full-chip [route_drc.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/route_drc.rpt) still explodes to the report limit of `10000`
- I parsed that report and found:
  - about `9998/10000` checked violations are `Special Wire`
  - the dominant rule is `VIA1 CUTSPACING` on net `VSS`
  - this is a PG/special-route geometry problem, not a normal signal-wire problem

### Important False Lead Closed
- I tested whether post-route fillers were the main cause.
- Result:
  - fillers were not the primary root cause
  - even with fillers disabled, the post-route `verify_drc` still reports roughly the same `VIA1` special-wire explosion
- So the correct focus stays on `sroute`/PG topology, not filler cleanup.

### New PG Strategy Change
- I changed the PG core-pin routing in [innovus_flow.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_flow.tcl) away from:
  - `corePinTarget {firstAfterRowEnd}`
- and back toward the staged `soc_design` style:
  - `corePinTarget {stripe}` on lower layers first
  - then `corePinTarget {stripe ring}`
  - then `corePinTarget {stripe ring blockring}`

### Why This Matters
- The DRC coordinates cluster at repeated PG-via sites, not random signal-routing hotspots.
- That strongly suggests the special-route connection pattern itself is wrong or too dense.
- Matching the `soc_design` staged `sroute` style is the right next experiment.

### Current Status
- A fresh `pg` rerun with the new staged `corePin` strategy is in progress.
- We still do **not** have `0 DRC / 0 LVS/connectivity`.
- But the backend debug is now much more structured:
  - we know the dominant violation class
  - we know it is special-route PG, not signal route
  - and we now have finer checkpoints to avoid re-running the full route every time

## Day 14: RSD Route Topology Split

### What Improved
- Re-ran full route from the latest `cts.enc` after the staged `sroute` fix.
- Important change in behavior:
  - the old post-route `VIA1 CUTSPACING` `Special Wire` explosion is no longer the dominant failure mode
  - regular connectivity is now clean in [route_connectivity.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/route_connectivity.rpt)
  - `routeDesign` itself still gets ordinary routed-signal DRC to `0` before the later full-chip verification step

### New Post-Route DRC Signature
- The remaining routed database is still not clean.
- Current [route_drc.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/route_drc.rpt) is dominated by:
  - `MINSTEP` on `Special Wire`
  - mainly on `M6` and `M7`
  - net `VSS` on `M6`
  - net `VDD` on `M6/M7`
- The current report summary is roughly:
  - `8903` total DRC
  - about `8246` `MINSTEP`
  - about `480` `CUTSPACING`
  - about `94` `SPACING`
- Coordinate clustering shows these are concentrated around the cache macro region, not randomly across the die.

### Connectivity Diagnosis
- [route_special_connectivity.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/route_special_connectivity.rpt) is no longer dominated by generic signal pins.
- The remaining special-connectivity failures are overwhelmingly:
  - `VPP` on standard-cell instances
  - one `VBB` residual case
- Top modules with the most `VPP` opens:
  - `brPred`
  - `btb`
  - `iCache`
- This means:
  - regular nets are already fine
  - body-bias connectivity is still a separate closure problem

### Structural Change Kept
- Updated [innovus_flow.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_flow.tcl) to remove per-macro block rings from the main PG strategy.
- The new default PG direction is:
  - macro `blockPin -> ring/stripe`
  - no `blockring` target in the normal flow
- Reason:
  - the remaining special-wire `M6/M7` min-step clusters line up with the SRAM-heavy cache region
  - per-macro block rings are the strongest suspected contributor to that geometry

### Structural Change Rejected
- I also tested an explicit `secondaryPowerPin` `sroute` pass from `route_raw.enc`.
- Result:
  - it does touch the missing body-bias network
  - but it does **not** reduce the main post-route DRC signature
  - and it introduces extra via-generation pressure and instability during the post-route cleanup experiment
- So `secondaryPowerPin` routing is not the main DRC fix and should not be the default path for every route iteration.

### Current Best Next Step
- Keep the simplified macro PG topology.
- Rebuild from `prepg.enc` using:
  - no per-macro block rings
  - direct macro `blockPin` PG hookup
- Then rerun:
  - `pg`
  - `cts`
  - `route`
- Goal of the next iteration:
  - see whether removing block rings collapses the remaining `M6/M7` special-wire min-step cluster
  - then revisit `VPP/VBB` connectivity only after the main routed geometry is cleaner

## Day 15: RSD Route-Finish PG Closure Experiments

### Stable Best Geometry Baseline
- Rebuilt the backend from the fresh full-design `place.enc` / `cts.enc` chain and confirmed the best clean raw-route base is still:
  - [route_raw.enc](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/db/route_raw.enc)
  - raw route finishes with only `4` geometry + `4` antenna markers before post-fill cleanup
- The best geometry-focused `route_finish` result still ends at:
  - `24` DRC in [route_drc.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/route_drc.rpt)
  - `0` regular-net connectivity violations

### What Helped
- Adding fillers after `route_raw.enc` is still necessary.
- After fillers, a macro-focused reconnect path is better than the earlier broad `corePin` pass:
  - `blockPinTarget {stripe ring blockring}`
  - `floatingStripeTarget {stripe ring blockring}`
- This path:
  - keeps geometry near the `24`-DRC baseline
  - avoids the runaway `M6/M7` special-wire explosion
  - confirms the ordinary routed netlist is already clean

### What Did Not Help
- Post-fill `corePin -> stripe` full-range `sroute`
  - too slow
  - gets stuck in macro-edge via failures
- Post-fill low-layer `corePin -> ring` (`M1..M4`)
  - routed `0` new wires
  - did not reduce the special-net opens
- Reintroducing per-macro `block_rings`
  - made things much worse
  - raw post-fill route jumped to hundreds of real geometry DRC
  - final special connectivity also degraded into mixed special + regular opens

### Current Best Understanding
- The remaining blocker is still **special PG connectivity**, not signal routing.
- The problem is now clearly localized around macro-side PG stitching.
- The best current no-blockring result still has:
  - `24` geometry DRC
  - `1000` capped special-net opens in [route_special_connectivity.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/route_special_connectivity.rpt)
- The open spans cluster around the SRAM macro regions:
  - `dCache`
  - `iCache`
  - `BTB`
  - `Gshare`
  - `MDP`

### Practical Conclusion
- The overnight experiments narrowed the search space:
  - **do not** use per-macro block rings in the current RSD flow
  - **do not** rely on post-fill `corePin` repair
  - **keep** the no-blockring route baseline with fillers + macro-focused reconnect
- The next structural fix should target the PG mesh itself, most likely:
  - sparse additional horizontal strap / bridge support around the macro bands
  - then rerun from the saved early checkpoint chain instead of patching only the final routed database

## Day 16: Fresh PG Rebuild and Row-Rail Connectivity Analysis

### Fresh Base Rebuilt
- Rebuilt the Innovus backend base from scratch after the PG-flow edits:
  - fresh `init.enc`
  - fresh `prepg.enc`
  - fresh `place.enc`
- Key flow changes in [innovus_flow.tcl](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/innovus_flow.tcl):
  - widened macro halo from `5` to `10`
  - added a local low-layer helper mesh in the cache / predictor / MDP / central-if bands
  - changed the low `corePin` stitch range from `M1..M7` to `M1..M6`

### Important New Result
- The new PG debug flow is materially better than the older stale-checkpoint path.
- With the fresh `prepg.enc` and the new low helper mesh:
  - `pg_after_blockpin_special_connectivity.rpt` is still capped at `1000` open terminals
  - but after the low `corePin` pass, [pg_after_corepin_low_special_connectivity.rpt](/home/fy2243/coding/design_and_perf/rsd_fengze/Processor/Project/Innovus/out/reports/pg_after_corepin_low_special_connectivity.rpt) improves to:
    - `190` terminal opens
    - `810` special-wire opens
- This is the first clear evidence that the new PG topology is helping, but not enough for closure.

### Root Cause Refined Again
- The low-pass report shows the remaining `IMPVFC-200` problems are **long horizontal VDD/VSS row rails** that stay open across wide spans of the core.
- Example pattern:
  - `Net VDD: has special routes with opens at (79.957, 79.971) (1214.873, 80.061)`
  - repeated across many adjacent row heights
- That means the dominant remaining failure is:
  - not ordinary signal routing
  - not random local pin opens
  - but **standard-cell followpin rails that are still not being stitched vertically into the PG mesh**

### What Was Rejected
- A full `corePin` climb on top of the new base was tried again.
- Result:
  - it falls back into repeated via-obstruction hotspots near the SRAM/control clusters
  - it does not produce a clearly better debug checkpoint than the low-pass result
- A sparse full-core low mesh experiment was also started:
  - this is more invasive
  - it changes the geometry heavily
  - early signs show it may be too blunt compared with the more surgical local-helper approach
- So the best current checkpoint remains the **fresh low-pass PG result**, not the broader full-climb/global-mesh path.

### Current Best Understanding
- The remaining physical-design blocker is still **PG special-net closure**.
- More specifically:
  - standard-cell row rails need a better vertical stitch strategy
  - the present upper-mesh + local-helper solution improves things, but still leaves hundreds of full-width open PG fragments
- So the next useful backend experiments should stay focused on:
  - row-rail stitch strategy
  - local low-layer PG support
  - not more general signal-route tuning

### Next-Stage Plan: Soc-Design-Style PG Isolation
- The next backend step should follow the same diagnostic logic that worked in `soc_design`:
  - first isolate and clean the **stdcell / tap / followpin PG skeleton**
  - then reintroduce **macro PG hookup**
- Why this may work:
  - when macros are present during PG closure, `sroute` is trying to solve two problems at once:
    - standard-cell row-rail stitching
    - macro `blockPin` connection into the upper PG mesh
  - if macro geometry fragments the rows or blocks via ladders, the base row-rail network never becomes clean
  - once the base stdcell PG is clean, macro reintegration becomes a smaller delta problem instead of a coupled failure
- How to apply this to RSD:
  - keep the same placed design and macro locations
  - first run PG closure with **macro hookup disabled** or minimized, focused only on:
    - taps
    - endcaps
    - stdcell followpin rails
    - row-rail stitch into the mesh
  - verify whether the stdcell-only PG skeleton becomes clean
  - then re-enable macro `blockPin` hookup on top of that clean checkpoint
  - if needed, reintroduce macro connection by cluster:
    - cache cluster
    - predictor cluster
    - MDP cluster
- Decision rule:
  - if the stdcell-only PG skeleton becomes clean, then macro reintegration is the real remaining problem
  - if it does not, then the problem is deeper than macro interaction and the row-stitch topology itself still needs work
