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

### UART TX (2026-04-04)

#### Modules Completed
- `uart_tx.sv` + testbench — 6/6 tests pass (0x55, 0xA3, 0x00, 0xFF, tx_busy, idle line)

#### Quiz Q&A (Review Before Interview) — Score: 6/10

**Q77. What is the UART frame format? How many bits total per byte?**
1 START bit (0) + 8 DATA bits (LSB first) + 1 STOP bit (1) = **10 bits total**. No clock wire — both sides agree on baud rate ahead of time. Standard config: 8N1 (8 data, No parity, 1 stop).

**Q78. Why is the start bit 0 and stop bit 1?**
IDLE line sits at 1. Start bit = 0 creates a **falling edge** the receiver can detect. Stop bit = 1 returns to idle, guaranteeing a falling edge for the next frame's start bit. If the last data bit were 0 and no stop bit, the next start bit would be invisible (no edge).

**Q79. What happens if TX and RX baud rates don't match?**
Receiver samples at wrong times, gets corrupted data. The sampling point drifts further with each bit — by bit 7-8, it may land in the wrong bit entirely. Must match within ~2-3%.

**Q80. With 50MHz clock and 115200 baud, how many clock cycles per bit? Per byte?**
- Per bit: `50,000,000 / 115,200 = 434 cycles`
- Per byte: `434 × 10 = 4,340 cycles` (10 bits: start + 8 data + stop)

**Q81. What does `tx_busy` tell the CPU, and why is it needed?**
Tells the CPU the transmitter is still sending the last frame — don't send another byte yet. CPU must wait for `tx_busy = 0` before pulsing `tx_start` again, otherwise the new byte overwrites the shift register mid-transmission.

**Q82. In UART RX, why sample at the middle of each bit period?**
Two reasons: (1) At bit edges, the signal is still transitioning (rise/fall time), voltage is unstable. Middle is most stable. (2) Any baud rate mismatch between TX and RX causes the sample point to **drift** over 10 bits — sampling at the middle gives maximum margin before drifting into the wrong bit.

### Clock Divider (2026-04-05)

#### Modules Completed
- `clk_divider.sv` + testbench — 6/6 tests pass (÷3 freq, ÷4 freq, ÷5 freq, ÷3 duty 50%, ÷4 duty 50%, ÷5 duty 50%)

#### Quiz Q&A (Review Before Interview) — Score: 6/10

**Q83. For an even divide-by-6 with 50% duty, how many cycles high? How many low?**
Period = 6 input cycles. 50% duty = **3 high, 3 low**. Divide-by-N means the output period is N input cycles, not N high + N low.

**Q84. Why can't a simple posedge counter achieve 50% duty for odd division (e.g., ÷3)?**
Period = 3 cycles, 50% duty needs 1.5 high + 1.5 low. But posedge-only logic can only toggle at integer cycle boundaries (0, 1, 2, 3...). Best you can do is 1 high + 2 low (33%) or 2 high + 1 low (67%).

**Q85. How does the posedge + negedge OR trick achieve 50% duty for odd division?**
Negedge gives half-cycle resolution — edges at 0.5, 1.5, 2.5... Combined with posedge (0, 1, 2...), you can now toggle at any half-cycle boundary. For ÷3: `clk_pos` is high for count 0 (cycle 0–1), `clk_neg` is the same but shifted by 0.5 cycle. OR them → high from 0 to 1.5, low from 1.5 to 3.0. Exactly 50%.

**Q86. What is `generate` used for in SystemVerilog? Two common use cases.**
Conditionally creates hardware at **compile time** (not runtime — no hardware is being "decided" dynamically). Two uses: (1) `generate if` — conditional implementation based on parameters (e.g., even vs odd divider). (2) `generate for` — instantiate N copies of a module (e.g., N SRAM banks, N pipeline stages, N slaves in an interconnect).

### Dual-Port RAM + Register File (2026-04-05)

#### Modules Completed
- `dual_port_ram.sv` (1R1W, sync read) + testbench — 5/5 tests pass
- `regfile_2r1w.sv` (2R1W, async read, x0 hardwired) + testbench — 6/6 tests pass

#### Quiz Q&A (Review Before Interview) — Score: 3.5/6

**Q87. Synchronous read vs asynchronous read — what's the difference? Which does SRAM use? Register file?**
- Sync read: output registered, data available **next cycle**. SRAM uses this because the physical circuit needs time — address decode → wordline drive → bitline sense → latch output. That chain takes a full cycle.
- Async read: output combinational, data available **same cycle**. Register file uses this because FFs have a direct mux to output — no sense amp delay. The pipeline needs operands immediately in the decode cycle.

**Q88. Why does the dual-port RAM have no reset on the memory array?**
Adding reset with a for-loop prevents the synthesis tool from **inferring an SRAM macro**. The tool sees the reset loop and thinks "each element needs individual reset" → builds from flip-flops instead. Real SRAM macros have no reset pin — contents are undefined at power-on. If you want FF inference (e.g., small register file), then adding reset is fine.

**Q89. Why does a pipeline register file need 2R1W?**
The decode stage reads **rs1 and rs2 simultaneously** in the same cycle. 1R1W can only read one operand at a time — would need 2 cycles, halving throughput. So: 2 read ports for rs1/rs2, 1 write port for rd writeback.

**Q90. How is RISC-V x0=0 implemented in RTL?**
Two places: (1) **Write side**: `if (wr_en && wr_addr != '0)` — block all writes to address 0. (2) **Read side**: `assign rd_data = (rd_addr == '0) ? '0 : regs[rd_addr]` — always return 0 for address 0. x0=0 provides a free constant for compare-to-zero (`beq x1, x0`), discard results (`add x0, x1, x2`), and register copy (`add x1, x0, x2`).

**Q91. Read and write same address on same posedge — what happens in our dual-port RAM?**
**Read-first.** Both `always_ff` blocks use nonblocking `<=`. On posedge, all right-hand sides evaluate first (read sees old `mem` value), then all left-hand sides update (write commits new value). So `rd_data` gets the old value. This is a SystemVerilog simulation guarantee of `<=` — all RHS evaluate before any LHS updates. In real SRAM, behavior depends on the macro (read-first, write-first, or undefined).

**Q92. Why does a register file synthesize to flip-flops, not SRAM?**
Small depth (32 entries) — no matching SRAM macro from the foundry (macros come in sizes like 256×32, 512×64). Also, SRAM macros don't support async read or multi-port (2R1W), which register files require.

### SRAM Design Concepts (2026-04-05)

#### Key Concepts (Review Before Interview)

**6T SRAM Cell:**
- 4 transistors (2 cross-coupled inverters) store the bit. 2 NMOS access transistors (N1, N2) connect cell to bitlines via wordline (WL).
- Node A and Node B are the two internal storage nodes — always complementary. Node A connects to BL through N1, Node B connects to BLB through N2.
- Access transistors are NMOS only (not transmission gates) for density. NMOS is smaller than PMOS for same drive strength.

**Register vs SRAM write approach:**
- Register (latch/FF): uses transmission gate to **disconnect feedback path** of cross-coupled inverters during write. No fight — input writes freely.
- SRAM: does NOT disconnect feedback. Instead, bitline drivers **overpower** the cell's inverters by brute force. Bitline drivers are large transistors outside the array, much stronger than the tiny cell.
- SRAM uses single NMOS (not transmission gates) to save area. Weak-1 problem doesn't matter because sense amps handle it.

**Differential (two-sided) write:**
- BL and BLB driven to complementary values (e.g., BL=1, BLB=0 to write 1).
- Left N1 pushes one direction, right N2 pushes opposite direction — each only needs to move half the voltage.
- Solves the single-transistor sizing conflict: one transistor can't be both strong (for write) and weak (for read) at the same time. Two-sided attack splits the problem.

**Read operation (full process):**
1. **Precharge** BL and BLB to VDD (both start equal and high)
2. **Open WL** — access transistors connect cell to bitlines
3. **Cell develops difference** — the side storing 0 pulls its bitline down slightly (50-100mV). The side storing 1 stays at VDD (same voltage, no current flow).
4. **Sense amplifier fires** — detects tiny voltage difference between BL and BLB, amplifies to full digital 0/1 output
5. **Close WL** — cell isolated, ready for next precharge

**Why precharge to VDD (not VSS)?**
- Access transistors are NMOS → good at pulling **down** (passing strong 0), weak at pulling up
- Precharge to VDD means cell only needs to pull down (its strength), never pull up
- If precharged to VSS, cell would need to pull up through NMOS → signal too weak to detect

**Why sense amplifiers?**
- Cell is tiny (6T, minimum size for density), bitline has huge parasitic capacitance (hundreds of cells per column)
- Full discharge would take too long — sense amp detects 50-100mV difference early and amplifies it
- One sense amp per column (per bitline pair). Column mux (e.g., 4:1) can reduce count by sharing one sense amp across multiple columns.

**Read vs write sizing conflict:**
- Read wants **weak access transistors** — limit current into Node B so it doesn't rise past Vm and flip the cell (read disturb)
- Write wants **strong access transistors** — overpower cell inverters to flip the stored value
- Solution: **cell pull-down NMOS > access NMOS > cell pull-up PMOS** (cell ratio for read stability, pull-up ratio for write ability)

**SRAM macro structure:**
- Memory array (rows × columns of 6T cells)
- Row decoder (address → wordline select)
- Column mux (select which columns to read if array wider than data)
- Sense amplifiers (one per column or shared via column mux)
- Precharge circuits (reset bitlines to VDD before read)

**SRAM vs DRAM vs FF:**
| | SRAM | DRAM | FF |
|---|---|---|---|
| Cell | 6T | 1T1C | ~20+ T |
| Refresh | No | Yes | No |
| Speed | Fast | Slow | Fastest |
| Density | Medium | Highest | Lowest |
| Use | On-chip caches | Main memory | Register files, small arrays |

---

## RSD Project Notes Moved (2026-04-05)

Detailed `rsd_fengze` project and physical-design history has been moved to:
- `/home/fy2243/coding/design_and_perf/rsd_fengze/PD.md`

That file now tracks:
- SRAM-backed RSD storage integration prerequisites
- full Design Compiler synthesis status
- Innovus bring-up history
- all major physical-design approaches tried
- current backend closure status and next steps

This `STUDY_PROGRESS.md` file is now reserved for general study notes and interview review material, so project-specific backend iteration logs do not get mixed into the broader study journal.
