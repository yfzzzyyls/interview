# Architecture Review

Unified microarchitecture review notes for the Qualcomm second-round preparation.

This file has these major review blocks:

1. Computer architecture fundamentals.
2. Decoupled frontend implementation specification.
3. Backend microarchitecture details.
4. LSU + L1D optimization specification.
5. Branch predictor microarchitecture.
6. TLB, MMU, and page-table-walker microarchitecture.
7. Cache, coherence, and memory-system review.
8. Retire, commit, ROB state, and recovery.
9. Vector / SIMD review.
10. Operation-specific implementation notes: interrupt/exception, fences, atomics.

The interviewer focus map below is a preparation router: use it to prioritize likely topics for each second-round interviewer, then jump into the detailed sections linked from that map.

The original FE and LSU source markdown files and their diagram assets remain in place. Local markdown links in the merged sections are rewritten relative to this `interview/` directory so the SVG/PNG pipeline diagrams still resolve from here.

## Interviewer Focus Map

### Ajay Rathee — Likely Interview Focus

Public-signal basis:
- Public LinkedIn preview: focus listed as modeling and analysis of high-performance CPU cores; older projects include C++ cache/memory hierarchy simulation, trace processor with trace cache/trace predictor, checkpoint recovery, speculative load forwarding, and memory-dependence prediction.
- Public patent listings: instruction fetch / branch / fetch-bundle work and instruction-side TLB prefetching.
- Treat this as preparation speculation, not a claim about what he will definitely ask.

Highest-priority map:

| Likely topic | Why it may come up | Existing review section |
|---|---|---|
| Decoupled frontend, FTQ, fetch bubbles | Public work points toward instruction fetch and branch/fetch-bundle behavior | [Part 2 — Decoupled Frontend Specification](#part-2--decoupled-frontend-specification), [Frontend Extra Topics to Review](#frontend-extra-topics-to-review) |
| Branch prediction and predictor metadata | Fetch patents mention branch history and fetch groups; frontend work often tests direction/target/update/recovery reasoning | [Part 5 — Branch Predictor Microarchitecture](#part-5--branch-predictor-microarchitecture), [TAGE Predictor Review](#5-tage-predictor-review) |
| Fetch beyond predicted-taken branch | Direct public patent theme; likely discussion around using fetch-bundle slots after a predicted-taken branch | Ajay-only notes below, plus [Decode Bandwidth and Frontend Bubbles](#decode-bandwidth-and-frontend-bubbles) |
| Instruction TLB and ITLB prefetch | Public patent listing includes instruction TLB prefetching from retired-page history | [Part 6 — TLB, MMU, and Page Table Walker](#part-6--tlb-mmu-and-page-table-walker), [TLB and Virtual Memory Corner Cases](#6-tlb-and-virtual-memory-corner-cases) |
| Trace cache / trace processor | His older project explicitly mentions trace processor, trace cache, trace predictor, and checkpoint recovery | Ajay-only notes below, plus [Uop Cache / Decoded Instruction Cache](#uop-cache--decoded-instruction-cache) |
| Memory dependence prediction and speculative load forwarding | His older project mentions Alpha 21264-inspired MDP and speculative load forwarding | [Memory Dependence Prediction](#141-memory-dependence-prediction), [OoO Load/Store Consistency](#142-ooo-loadstore-consistency), [Store Queue / Store Buffer Discussion](#121-store-queue--store-buffer-discussion) |
| Cache and memory hierarchy modeling | His older project includes C++ cache hierarchy simulation and validation | [Part 7 — Cache, Coherence, and Memory System](#part-7--cache-coherence-and-memory-system), [Replacement Policy and MSHRs](#9-replacement-policy-and-mshrs) |
| Performance model debug and validation | Role is CPU performance modeling; likely asks how to prove model results and debug regressions | [Architecture Performance Evaluation Hooks](#8-architecture-performance-evaluation-hooks), [PMU and Performance Counter Interpretation](#9-pmu-and-performance-counter-interpretation), [Validation and Calibration](#10-validation-and-calibration) |

Lower-priority possible angles:

| Possible topic | Why it may come up | Existing review section |
|---|---|---|
| Memory fabric, address decoding, CXL/HDM-style address translation | Public patent listings include CXL host-managed device memory decoding and reduced-area/power sequencing | [Interconnect Types](#5-interconnect-types), [ACE / CHI Coherent Interconnect Basics](#6-ace--chi-coherent-interconnect-basics), [Mobile Power / Performance Constraints](#11-mobile-power--performance-constraints) |
| Compiler/codegen and intrinsic-aware performance | Public coursework includes code generation/optimization; your BKFIR/intrinsics work is a good bridge if he asks software-to-microarchitecture questions | [Compiler, Intrinsics, and Scheduling Notes](#5-compiler-intrinsics-and-scheduling-notes), [Vector and SIMD](#part-9--vector-and-simd) |

Expected question style:
- Mechanism-first: explain the microarchitecture structure, not only the high-level definition.
- Model-first: identify what state/counters/latencies the performance model needs.
- Validation-first: explain how to prove the result with counters, directed tests, RTL evidence, or workload deltas.
- Tradeoff-first: mention performance benefit, power/timing/area cost, and failure cases.

Preparation priority for Ajay:
1. Be able to draw and explain `BP_S0 -> BP_S1 -> FTQ -> IF_S0 -> IF_S1 -> Decode`.
2. Be able to explain why taken branches inside a fetch block waste bandwidth, and how fetching beyond a predicted-taken branch could help loops.
3. Be able to explain gshare vs TAGE, BTB target misses, GHR checkpoint/restore, and predictor update timing.
4. Be able to explain ITLB miss handling and how instruction-side TLB prefetch could help instruction-stream page crossings.
5. Be able to explain memory-dependence prediction, store-load forwarding, violation detection, and replay.
6. Be able to debug an IPC regression with CPI stack, MPKI, branch MPKI, ITLB MPKI, MSHR occupancy, replay count, and frontend-bubble counters.

Likely mock questions:
- How would you model lost fetch bandwidth from a taken branch in the middle of a fetch bundle?
- What is the difference between BTB miss, direction misprediction, and target misprediction?
- How does TAGE reduce destructive aliasing compared with gshare?
- What state must be checkpointed for branch recovery in a decoupled frontend?
- What is a trace cache, and how is it different from a uop cache?
- How would an ITLB prefetcher work, and what are its risks?
- Why can a memory-dependence predictor improve IPC, and how do you recover from a wrong prediction?
- If your model predicts a frontend speedup, what counters would you inspect to validate it?

Ajay-only topic: fetching beyond a predicted-taken branch:
- Baseline fetch usually stops useful extraction at the first predicted-taken branch in a fetch bundle, because the next PC is predicted to be the branch target.
- If the branch is a loop branch and the next loop iteration also fits in the same fetch bundle or can be reconstructed predictively, the frontend may extract useful instructions beyond the predicted-taken branch rather than wasting later fetch lanes.
- Potential benefit: higher effective fetch bandwidth for tight loops and fewer frontend bubbles.
- Risks: wrong-path fetch/extract work, more complex branch metadata, duplicated loop-iteration bookkeeping, predictor-history update complexity, and recovery corner cases.
- Model counters: useful fetched lanes, wasted fetched lanes after taken branch, loop-iteration extraction hit rate, branch recovery count, and frontend power/activity.

Ajay-only topic: trace cache / trace processor:
- A trace cache stores dynamic instruction traces, often spanning multiple basic blocks and taken branches, instead of only static cache-line-aligned instruction bytes.
- A trace predictor predicts which trace to fetch next, so frontend bandwidth can follow hot dynamic paths.
- Benefit: bypasses repeated decode/fetch steering for hot control-flow paths and can deliver high effective fetch bandwidth across taken branches.
- Costs and risks: trace construction complexity, trace-cache capacity/aliasing, partial trace exits, self-modifying code invalidation, exception/debug mapping, and recovery metadata.
- Modeling hooks: trace-cache hit rate, average trace length, trace exit reason, mispredicted trace count, useful uops per trace, and trace-cache replacement effects.

Ajay-only topic: instruction TLB prefetch from retired-page history:
- Idea: when retirement observes instruction-stream progress into a new page, record retired instruction pages and prefetch likely next instruction translations before the frontend demands them.
- Benefit: hides ITLB miss/page-walk latency for instruction streams that move predictably across pages.
- Risks: ASID/context correctness, page-boundary prediction accuracy, TLB pollution, page-walk bandwidth, wrong-path instruction streams, and interaction with `SFENCE.VMA`.
- Model counters: ITLB MPKI, ITLB prefetch accuracy, ITLB prefetch coverage, late prefetches, page-walk traffic, L2 TLB pollution, and frontend cycles blocked on translation.

Ajay lower-priority topic: CXL/HDM-style address decoding:
- CXL host-managed device memory uses decoder logic to map host physical address ranges to device memory regions.
- The performance-modeling angle is not CXL protocol detail; it is address decode latency, area/power of decoder structures, memory-region selection, and traffic routing.
- Possible questions could resemble cache/TLB address decode: what bits select region, how many parallel compares are needed, how to reduce decoder power, and what happens on remap/reconfiguration.
- Model counters: decoder lookup count, decoder miss/error count, fabric request latency, memory-region bandwidth, queue occupancy, and power proxy from active decoder comparisons.

Ajay lower-priority topic: compiler/codegen bridge:
- If he asks about compiler-aware performance, connect your BKFIR/intrinsics work to microarchitecture: register reuse reduces reloads, fused intrinsics reduce uop count/latency, and branch-to-predicate conversion can improve scheduling when branches are unpredictable.
- Mention that compiler scheduling is usually easiest within basic blocks; branches, aliasing, calls, and exception-visible memory operations constrain motion.
- Model counters: instruction count, uop count if available, load/store count, vector utilization, branch count/mispredicts, register spills/reloads, and memory bandwidth.

### David Palframan — Likely Interview Focus

Public-signal basis:
- Public LinkedIn preview: computer architect with experience in performance modeling; publications include `COP: To Compress and Protect Main Memory` and `Precision-Aware Soft Error Protection for GPUs`.
- UW-Madison architecture group lists him as PhD, May 2015, current employment Qualcomm Research.
- Public Qualcomm patent listing includes `Intelligent data prefetching using address delta prediction`.
- Earlier research includes redundant intermediate bitslices for process variation, critical paths, reliability, and performance.
- Treat this as preparation speculation, not a claim about what he will definitely ask.

Highest-priority map:

| Likely topic | Why it may come up | Existing review section |
|---|---|---|
| Data prefetching beyond next-line | Public patent signal is address-delta data prefetching; likely asks accuracy/coverage/timeliness/pollution tradeoffs | [L1D Next-Line Prefetcher](#5-optimization-c--l1d-next-line-prefetcher), [Beyond Next-Line Prefetching](#58-beyond-next-line-prefetching), David-only notes below |
| MSHRs, bandwidth, and demand interference | Prefetch benefit depends on miss concurrency and whether prefetches steal demand resources | [Replacement Policy and MSHRs](#9-replacement-policy-and-mshrs), [Port Conflicts and Banking](#8-port-conflicts-and-banking), [Cache and Memory-System Corner Cases](#12-cache-and-memory-system-corner-cases) |
| Cache/memory hierarchy modeling | Publications and patent point toward memory hierarchy, cache behavior, and performance-model evidence | [Part 7 — Cache, Coherence, and Memory System](#part-7--cache-coherence-and-memory-system), [Architecture Performance Evaluation Hooks](#8-architecture-performance-evaluation-hooks) |
| Main-memory compression and ECC | `COP` publication combines compression, main-memory capacity, and error protection | David-only notes below, plus [Cache and Memory-System Corner Cases](#12-cache-and-memory-system-corner-cases) |
| Reliability and soft errors | HPCA publication and Spare RIBs work point toward selective protection, register-file/execution logic vulnerability, and reliability/cost tradeoffs | David-only notes below, plus [Power, Timing, and Area Tradeoffs](#10-power-timing-and-area-tradeoffs) |
| Power/performance/critical path tradeoffs | Spare RIBs work is about critical paths, variation, redundancy, area, and performance | [Power, Timing, and Area Tradeoffs](#10-power-timing-and-area-tradeoffs), [Mobile Power / Performance Constraints](#11-mobile-power--performance-constraints) |
| Model validation and counter interpretation | Performance modeling role plus research background likely means he will care about proof, not just claims | [PMU and Performance Counter Interpretation](#9-pmu-and-performance-counter-interpretation), [Validation and Calibration](#10-validation-and-calibration) |

Lower-priority possible angles:

| Possible topic | Why it may come up | Existing review section |
|---|---|---|
| Register file ports and backend scaling | `CRAM: Coded Registers for Amplified Multiporting` points to multi-ported RF cost, wide OoO scaling, and area/power/timing tradeoffs | [Backend Microarchitecture Details](#part-3--backend-microarchitecture-details), [Wakeup / Select](#5-wakeup--select), [Power, Timing, and Area Tradeoffs](#10-power-timing-and-area-tradeoffs) |
| Low-cost error detection and memory fault patching | Public work includes time-redundant parity and patching memory faults using existing memory hierarchy structures | David-only notes below, plus [Cache and Memory-System Corner Cases](#12-cache-and-memory-system-corner-cases), [Validation and Calibration](#10-validation-and-calibration) |

Expected question style:
- Tradeoff-heavy: performance gain versus bandwidth, power, area, latency, and reliability cost.
- Evidence-heavy: what counters prove the mechanism helped, and what counters prove it did not cause damage.
- Modeling-heavy: what state must be represented in the simulator, and what simplifying assumption is acceptable.
- Corner-case-heavy: pollution, MSHR pressure, replacement effects, ECC metadata overhead, and critical-path impact.

Preparation priority for David:
1. Be able to explain prefetch metrics: accuracy, coverage, timeliness, pollution, bandwidth, MSHR pressure, and demand interference.
2. Be able to describe a beyond-next-line prefetcher, especially PC-correlated address-delta prediction.
3. Be able to explain why lower MPKI may not improve IPC: MLP, ROB head blocking, bandwidth, hit latency, and unrelated bottlenecks.
4. Be able to explain MSHR merge/full behavior and how prefetches interact with demand misses.
5. Be able to discuss ECC, soft errors, selective protection, and memory compression at a high level.
6. Be able to validate a memory-system change with counters and directed tests.

Likely mock questions:
- Design a prefetcher for pointer-chasing or irregular memory patterns. What state do you store?
- A prefetcher improves MPKI but hurts IPC. What happened?
- What counters show whether a prefetcher is accurate, timely, and non-interfering?
- How do MSHRs affect memory-level parallelism and prefetch usefulness?
- Why are multi-ported register files expensive, and how can a core reduce RF port pressure?
- Why can main-memory compression improve capacity but hurt latency or bandwidth?
- What is the tradeoff between ECC protection, memory capacity, power, and performance?
- What is the difference between parity detection, ECC correction, and full duplication?
- How would you model soft-error protection or selective hardening in a performance/power study?
- A design improves frequency by changing a critical path but adds area or redundancy. How do you evaluate it?

David-only topic: address-delta data prefetching:
- Idea: identify correlated load instructions whose virtual addresses have a repeating delta, then use the first load's PC/address to prefetch the second load's future address.
- Difference from stride prefetching: stride prefetching tracks one load stream; address-delta/correlation prefetching can learn relationships between different load PCs or dependent misses.
- Useful for irregular but repeatable allocation/layout patterns where normal sequential or stride prefetchers fail.
- Core state to model: miss-tracking table, address-delta prediction table, PC tags, delta value, confidence, replacement policy, and prefetch request queue.
- Training signal: prior D$ misses, resolved miss order, dependence/time correlation, or ROB-walk-based older-miss correlation.
- Risks: virtual-address alias/context issues, page crossing, DTLB pressure, low confidence, MSHR pollution, wrong prefetch target, and demand bandwidth interference.
- Model counters: ADP table hit rate, trained pairs, confidence distribution, prefetch accuracy, coverage, timeliness, MSHR merge/drop rate, demand miss latency, and pollution-induced demand MPKI.

David-only topic: main-memory compression with ECC protection:
- Compression can create space for ECC metadata or increase effective memory capacity, but it adds metadata, layout, and access complexity.
- Key performance issue: can the memory controller locate compressed blocks without expensive variable-size address calculation?
- A linearly compressed page style idea keeps blocks within a page at a uniform compressed size so address calculation remains simple.
- ECC angle: storing check bits protects against soft errors; stronger protection costs capacity, bandwidth, latency, or extra chips unless compression creates room.
- Model questions: compression ratio distribution, compress/decompress latency, memory bandwidth change, metadata access overhead, row-buffer locality, and error coverage.
- Interview framing: compression is useful only if the capacity/reliability benefit is not erased by address-lookup latency, decompression latency, or extra memory traffic.

David-only topic: reliability, soft errors, and variation:
- Soft errors can corrupt architectural state, register files, queues, or execution logic; not every bit has equal impact on final program output.
- Selective protection hardens the most valuable or vulnerable structures rather than paying full protection cost everywhere.
- Precision-aware protection idea: for numeric/GPU-style workloads, the magnitude of the error can matter, not only whether any bit flipped.
- Process variation can slow critical paths; redundancy or bitslice-level techniques can avoid the slowest slice, but at area/power/design-complexity cost.
- Model questions: which structure is protected, what is the performance overhead, what is the area/power cost, and what reliability metric improves.
- Interview framing: reliability mechanisms should be evaluated like performance features: define the fault model, cost, coverage, workload impact, and validation method.

David lower-priority topic: register file multiporting and backend scaling:
- Wide OoO cores need many RF read/write ports because multiple issued instructions may each read two or more operands and write back results in the same cycle.
- True multi-port RFs are expensive: more ports increase cell size, bitline/wordline loading, sense amps, muxing, area, leakage, dynamic energy, and often critical-path delay.
- Common alternatives: banked RF, clustered execution, operand caching, bypass-heavy designs, read-port scheduling, limiting issue width per cluster, multi-cycle RF read, or encoded/coded storage ideas.
- Performance tradeoff: reducing RF ports saves power/timing/area but can create operand-read conflicts, issue restrictions, or extra bypass complexity.
- Model counters: RF read/write port utilization, RF port conflict stalls, bypass hit rate, issue slots lost to operand-read conflicts, cluster imbalance, and writeback conflicts.

David lower-priority topic: low-cost error detection and memory fault patching:
- Parity detects many errors cheaply but usually cannot correct them without replay, redundant state, or recovery support.
- ECC can detect and correct within its code strength but costs storage, encode/decode latency, power, and sometimes extra memory chips or metadata storage.
- Full duplication gives stronger checking but is usually high area/power overhead.
- Time-redundant parity style ideas trade time/checking latency for lower area/power than full duplication.
- Memory fault patching idea: if one memory location is faulty, use redundant copies already present in the hierarchy, such as cache lines or other storage, and increase their persistence so the faulty location is effectively patched.
- Performance/modeling questions: how often faults occur, what recovery latency is, whether protected entries reduce usable cache capacity, whether persistence blocks normal replacement, and whether checking is on the critical path.
- Model counters: detected parity events, ECC corrected/uncorrected events, replay/recovery cycles, protected-entry occupancy, blocked evictions due to persistence, and protection energy/access overhead.

### Sabine Francis — Likely Interview Focus

Public-signal basis:
- Public LinkedIn preview: Qualcomm, Austin; education at UT Austin.
- Public Qualcomm patent listings include pointer prefetching, non-stalling cacheline-triggered prefetch pipeline optimization for indirect memory accesses, and differential training for indirect memory prefetching.
- UT Austin poster work includes SystemC/TLM, OMNeT++, host-compiled simulation, design-space exploration, latency/throughput/QoS modeling.
- Treat this as preparation speculation, not a claim about what she will definitely ask.

Highest-priority map:

| Likely topic | Why it may come up | Existing review section |
|---|---|---|
| Pointer / indirect prefetching | Public patent signal is strongest around pointer and indirect-memory prefetchers | [Beyond Next-Line Prefetching](#58-beyond-next-line-prefetching), Sabine-only notes below |
| Prefetch accuracy, coverage, timeliness, pollution | Pointer prefetchers can easily become late, wrong, or bandwidth-destructive | [Beyond Next-Line Prefetching](#58-beyond-next-line-prefetching), [PMU and Performance Counter Interpretation](#9-pmu-and-performance-counter-interpretation) |
| MSHR pressure and non-stalling prefetch pipeline | Public patent signal includes non-stalling prefetch pipeline optimization | [Replacement Policy and MSHRs](#9-replacement-policy-and-mshrs), [Port Conflicts and Banking](#8-port-conflicts-and-banking), Sabine-only notes below |
| TLB/page-crossing correctness for prefetch | Pointer/indirect prefetch often uses virtual addresses and can cross pages or contexts | [Part 6 — TLB, MMU, and Page Table Walker](#part-6--tlb-mmu-and-page-table-walker), [TLB and Virtual Memory Corner Cases](#6-tlb-and-virtual-memory-corner-cases) |
| Cache pollution and replacement side effects | Indirect prefetch can bring low-usefulness lines and evict useful demand lines | [Cache and Memory-System Corner Cases](#12-cache-and-memory-system-corner-cases), [Replacement Policy and MSHRs](#9-replacement-policy-and-mshrs) |
| Performance model validation | She may ask how to prove a prefetcher helps and does not damage demand traffic | [Validation and Calibration](#10-validation-and-calibration), [Architecture Performance Evaluation Hooks](#8-architecture-performance-evaluation-hooks) |

Lower-priority possible angles:

| Possible topic | Why it may come up | Existing review section |
|---|---|---|
| SystemC/TLM and fast design-space exploration | UT Austin poster signal includes SystemC/TLM and simulation methodology | [Architecture Performance Evaluation Hooks](#8-architecture-performance-evaluation-hooks), [Validation and Calibration](#10-validation-and-calibration) |
| QoS / latency / throughput modeling | NoS work mentions latency, throughput, and QoS; lower priority for CPU-core interview but relevant to performance modeling style | [PMU and Performance Counter Interpretation](#9-pmu-and-performance-counter-interpretation), [ACE / CHI Coherent Interconnect Basics](#6-ace--chi-coherent-interconnect-basics) |

Expected question style:
- Practical prefetch-design questions: what state is stored, what triggers training, and when to issue/drop a prefetch.
- Damage-control questions: how to detect pollution, late prefetches, MSHR pressure, and demand interference.
- Implementation-aware questions: how to avoid prefetch pipeline stalls, critical-path growth, and expensive arithmetic.
- Validation questions: what counters and directed tests prove correctness and usefulness.

Preparation priority for Sabine:
1. Be able to explain why pointer chasing is hard for stride/next-line prefetchers.
2. Be able to design a pointer/indirect prefetcher with trigger PC, pointer load, target address, confidence, and throttling.
3. Be able to explain prefetch metrics: accuracy, coverage, timeliness, pollution, and demand interference.
4. Be able to explain MSHR merge/full behavior and how prefetches should be lower priority than demand misses.
5. Be able to discuss VA/PA, page crossing, DTLB pressure, ASID/context correctness, and MMIO/non-cacheable filtering for prefetch.
6. Be able to validate a prefetcher with directed pointer-chase, linked-list, sparse-array, and graph-like tests.

Likely mock questions:
- Why is pointer chasing hard to prefetch?
- How would you design a hardware pointer prefetcher?
- What is a trigger access, and how do you train the prefetcher?
- How can a prefetcher improve MPKI but reduce IPC?
- What counters tell you a prefetcher is late versus inaccurate?
- How do you avoid MSHR pollution and demand interference?
- How do page crossings and DTLB misses affect a pointer prefetcher?
- What does a non-stalling prefetch pipeline need to avoid blocking demand access?

Sabine-only topic: pointer / indirect prefetching:
- Pointer-chasing load pattern: load address A to get pointer P, then later load from address P. The second address is not known until the first load returns.
- Normal next-line/stride prefetchers fail because the target stream may not have a constant address delta.
- A pointer prefetcher tries to identify a producer load whose data value is a future memory address, then prefetches the cache line pointed to by that value.
- Core state to model: trigger PC, pointer-load PC, last pointer value, confidence counter, prefetch distance, prefetch queue, and filter bits for cacheable/valid address ranges.
- Useful workloads: linked lists, trees, graph traversal, sparse data structures, object graphs, hash chains, and some ML/recommender access patterns.
- Risks: wrong pointer interpretation, stale pointer value, low reuse, page faults, DTLB pressure, MMIO/non-cacheable addresses, security/speculation policy, and cache pollution.
- Model counters: trigger count, generated pointer prefetches, useful pointer prefetches, late pointer prefetches, dropped unsafe prefetches, DTLB misses caused by prefetch, MSHR occupancy, and pollution-induced demand misses.

Sabine-only topic: trigger/training for indirect prefetchers:
- A trigger access is an earlier demand access that indicates a later indirect access is likely.
- Training can observe repeated relationships between a producer load and a consumer load, such as `consumer_addr = load_value_from_producer` or `consumer_addr = producer_value + offset`.
- Differential training idea: learn a compact delta/offset relationship rather than storing full target addresses when possible.
- Confidence is essential; low-confidence relationships should not issue prefetches.
- Replacement policy matters because training tables can be polluted by one-time pointer relationships.
- Model counters: trained entries, confidence promotions/demotions, table hit rate, table eviction rate, false trigger rate, and relationship age.

Sabine-only topic: non-stalling prefetch pipeline:
- Demand load/store traffic should not wait behind prefetch address generation, prefetch tag probes, or prefetch MSHR allocation.
- Prefetch generation should be decoupled through a queue so the load pipeline can enqueue hints and continue.
- Prefetch probes should use idle cache ports or low-priority arbitration.
- Expensive address-generation math should be kept off the demand critical path; use simple shifts/masks/adders when possible, or pipeline the computation.
- If resources are full, the prefetcher should drop or defer the request rather than stalling demand.
- Model counters: prefetch queue full drops, prefetch-generation stalls avoided, demand-port wins over prefetch, prefetch port conflicts, MSHR allocation failures, and prefetch issue latency.

Sabine-only topic: directed tests for pointer prefetchers:
- Linked list traversal: one pointer per node; tests pure pointer-chase latency hiding.
- Tree traversal: branch-dependent pointer path; tests confidence and wrong-path prefetch filtering.
- Graph BFS/DFS: irregular adjacency traversal; tests coverage, MSHR pressure, and cache pollution.
- Sparse matrix / CSR: indirect index array followed by value array; tests producer/consumer relationship detection.
- Hash table chains: pointer chains with low spatial locality; tests trigger quality and pollution.
- Object-pointer chains: pointer-to-struct layouts; tests sub-cacheline usefulness and field-offset relationships.
- Array of pointers versus pointer-to-struct layout: tests whether prefetcher learns pointer array loads and target object loads separately.
- Measurements: pointer-prefetch coverage, useful/late/useless prefetches, MSHR occupancy, DTLB pressure, demand MPKI, pollution-induced evictions, and speedup by access pattern.

Sabine lower-priority topic: SystemC/TLM and design-space exploration:
- TLM abstracts transactions rather than every cycle, so it is useful for fast design-space exploration and system-level latency/throughput studies.
- CPU-core performance modeling usually needs more microarchitectural detail than TLM, but the same discipline applies: define abstraction level, timing contracts, validation targets, and error tolerance.
- If asked, connect this to Sparta/Olympia-style modeling: use modular components, clear ports/events, parameterized latency/capacity, and counters for throughput/QoS.

### Pratishtha Dehadray — Likely Interview Focus

Public-signal basis:
- Public LinkedIn preview: Qualcomm, Santa Clara; CMU education.
- Public project history includes C++ models of global/local/tournament/perceptron/YAGS branch predictors.
- Public project history includes SystemVerilog ROB and issue queue with custom arbitration, VCS simulation, Genus synthesis, max-frequency analysis, and energy optimization.
- Public project history includes dynamic cache partitioning, BLISS/ATLAS DRAM scheduling, Snapdragon 855 profiling, cache coherence stress tests, Linux frequency governors, cache simulator with MESI, and latency modeling for DL workloads.
- Treat this as preparation speculation, not a claim about what she will definitely ask.

Highest-priority map:

| Likely topic | Why it may come up | Existing review section |
|---|---|---|
| Branch predictor modeling | Public project directly lists global/local/tournament/perceptron/YAGS predictors and BTB hit rate | [Part 5 — Branch Predictor Microarchitecture](#part-5--branch-predictor-microarchitecture), [TAGE Predictor Review](#5-tage-predictor-review), Pratishtha-only notes below |
| ROB and issue queue arbitration | Public project lists SystemVerilog ROB/IQ with custom arbitration and synthesis | [ROB / ActiveList](#3-rob--activelist), [Issue Queue](#4-issue-queue), [Wakeup / Select](#5-wakeup--select) |
| Backend power/timing/energy tradeoffs | Public project includes Genus synthesis, max frequency, and energy optimization | [Power, Timing, and Area Tradeoffs](#10-power-timing-and-area-tradeoffs), [Mobile Power / Performance Constraints](#11-mobile-power--performance-constraints) |
| Cache partitioning and DRAM scheduling | Public project lists dynamic cache partitioning, BLISS, and ATLAS | [Part 7 — Cache, Coherence, and Memory System](#part-7--cache-coherence-and-memory-system), Pratishtha-only notes below |
| Cache coherence and MESI | Public project lists C cache simulator and MESI protocol | [MESI and MOESI](#3-mesi-and-moesi), [Snooping vs Directory Coherence](#4-snooping-vs-directory-coherence) |
| Snapdragon profiling and governors | Public project lists Snapdragon 855 stress tests and schedutil/ondemand/performance/powersave governor analysis | [PMU and Performance Counter Interpretation](#9-pmu-and-performance-counter-interpretation), [Mobile Power / Performance Constraints](#11-mobile-power--performance-constraints), Pratishtha-only notes below |
| C++/RTL model validation | Public project mix includes C++ models, SystemVerilog, VCS, synthesis, and profiling | [Validation and Calibration](#10-validation-and-calibration), [Architecture Performance Evaluation Hooks](#8-architecture-performance-evaluation-hooks) |

Expected question style:
- Broad microarchitecture coverage: branch predictor, backend, cache, DRAM, and power/perf.
- Implementation-aware: not only what a structure does, but how arbitration, timing, and energy affect the design.
- Model-building: define state, update rules, counters, and validation for a predictor, ROB, IQ, cache, or DRAM scheduler.
- Profiling-aware: real SoC behavior, PMU counters, frequency governors, and workload sensitivity.

Preparation priority for Pratishtha:
1. Be able to implement/explain a branch predictor model: index, tag/history, prediction, update, aliasing, and accuracy metric.
2. Be able to explain ROB/IQ behavior, custom arbitration policies, and oldest-ready versus fairness/energy tradeoffs.
3. Be able to explain why wakeup/select and multi-ported structures are timing/power sensitive.
4. Be able to discuss shared-cache partitioning and DRAM scheduling fairness/throughput tradeoffs.
5. Be able to explain MESI and cache coherence stress-test patterns.
6. Be able to profile mobile SoC performance under different governors and explain DVFS effects.

Likely mock questions:
- Implement or describe a branch predictor model. What state does it keep and how is it updated?
- Compare global, local, tournament, perceptron, YAGS, and TAGE predictors.
- How does issue-queue arbitration affect IPC, fairness, and energy?
- What happens when the ROB is full, IQ is full, or commit is blocked?
- How would you partition a shared LLC among threads?
- What is the difference between optimizing system throughput and fairness?
- How do BLISS and ATLAS-style DRAM schedulers think about fairness?
- How would you profile branch predictor behavior on Snapdragon hardware?
- How do Linux governors such as `schedutil`, `ondemand`, `performance`, and `powersave` affect benchmark measurements?

Pratishtha-only topic: YAGS and perceptron predictors:
- YAGS: "Yet Another Global Scheme"; uses a choice predictor plus exception caches for taken/not-taken exceptions to reduce aliasing versus a simple global predictor.
- YAGS intuition: most branches have a bias; store the common bias cheaply and use tagged exception tables for cases that disagree with the bias.
- Perceptron predictor: treats branch prediction as a weighted sum of global history bits. Positive sum predicts taken; negative sum predicts not taken.
- Perceptron benefit: can learn linearly separable long-history correlations with less table explosion than some counter-based predictors.
- Perceptron cost: dot-product latency, weight storage, update complexity, and frontend timing risk.
- Interview contrast: gshare is simple and fast; tournament chooses among predictors; YAGS reduces destructive aliasing with exception caches; perceptron learns long correlations; TAGE is often stronger practical high-end baseline.
- Model counters: prediction accuracy by branch class, table hit rate, aliasing/conflict rate, update count, wrong-path update pollution, and predictor latency.

Pratishtha-only topic: issue queue arbitration policy:
- Oldest-ready arbitration improves fairness and reduces starvation risk, but can cost timing/power because age comparisons across many ready entries are expensive.
- Round-robin or banked arbitration can be cheaper but may issue a younger op while an older ready op waits.
- Criticality-aware arbitration may prioritize branches, cache-miss-dependent ops, or long-latency ops to reduce overall stalls.
- Energy-aware arbitration may avoid waking/selecting too many entries or may partition the queue to reduce CAM activity.
- Model counters: ready-but-not-issued cycles, select conflicts, oldest-ready violations, starvation age, issue-port utilization, replay pressure, and IQ CAM access count.

Pratishtha-only topic: shared cache partitioning:
- Goal: prevent one thread from evicting another thread's useful shared-cache lines.
- Way partitioning: allocate ways per core/thread/class; simple but can reduce flexibility.
- Utility-based partitioning: give more cache to the thread that gains more misses saved per way.
- Dynamic partitioning: adjust based on miss rate, occupancy, reuse, or QoS target.
- Tradeoff: improves fairness/isolation but can lower total hit rate if partition boundaries are too rigid.
- Model counters: per-thread occupancy, per-thread MPKI, evictions caused by other threads, hit-rate change per allocated way, STP, ANTT, and QoS violations.

Pratishtha-only topic: BLISS and ATLAS DRAM scheduling:
- BLISS idea: blacklist applications that generate too many consecutive memory requests, reducing interference from memory-intensive threads.
- BLISS goal: simple fairness improvement by preventing one aggressive thread from dominating DRAM service.
- ATLAS idea: prioritize threads that have received the least attained memory service over a scheduling quantum.
- ATLAS goal: improve system throughput while limiting starvation by periodically ranking threads based on attained service.
- Model counters: per-thread memory requests served, row-buffer hit rate, average memory latency per thread, slowdown estimate, STP, ANTT, and starvation/outlier latency.

Pratishtha-only topic: Snapdragon governor profiling:
- `performance`: tends to hold high frequency; useful for reducing DVFS noise but higher power.
- `powersave`: biases low frequency; useful for energy studies but can hide microarchitecture improvements behind frequency limits.
- `ondemand`: reacts to utilization with threshold-based frequency changes.
- `schedutil`: integrates scheduler utilization signals with DVFS; can respond differently by workload phase and core class.
- Heterogeneous cores such as silver/gold/gold-prime complicate analysis because migration changes both microarchitecture and frequency.
- Profiling rule: record governor, frequency trace, core placement, thermal state, input size, warmup, PMU counters, and run-to-run variance.

Pratishtha-only topic: C++ model contracts to practice:
- Branch predictor model:
  - Input trace: `{pc, taken, target}` plus optional branch type.
  - State: predictor tables, local/global history, chooser table for tournament, BTB tags/targets, optional RAS.
  - API: `predict(pc)`, `update(pc, actual_taken, actual_target)`.
  - Metrics: predictions, mispredictions, direction accuracy, BTB hit rate, MPKI-style miss rate, aliasing/conflict count if modeled.
  - Key choice: update at execute/retire versus immediately after reading the trace; explain speculative-history limitations if simplified.
- ROB/IQ model:
  - State: circular ROB with head/tail/count, IQ entries with source-ready bits, physical tags, age, op type, and port requirements.
  - API: `allocate`, `wakeup(tag)`, `select(issue_width)`, `complete(rob_id)`, `commit(commit_width)`, `flush(recovery_id)`.
  - Invariants: no ROB overrun, in-order commit, no completed-but-unallocated instruction, no issue before operands ready, no starvation under arbitration policy.
  - Metrics: ROB-full cycles, IQ-full cycles, ready-not-issued cycles, port conflicts, commit bandwidth utilization, and average instruction age.
- Cache / DRAM scheduler model:
  - State: cache sets/ways/replacement, per-thread request queues, row-buffer state, bank/channel mapping, per-thread service counters.
  - API: `access(thread_id, addr, type)`, `enqueue_mem_request`, `schedule_next_request`, `complete_request`.
  - Metrics: per-thread MPKI, row-buffer hit rate, average memory latency, bandwidth, queue occupancy, STP, ANTT, and fairness/outlier slowdown.
  - Key choice: define whether timing is cycle-level, event-driven, or trace-level; explain what overlap/MLP assumptions are included.

## Part 1 — Computer Architecture Fundamentals

Source: original architecture fundamentals from this file before the merge.

Key concepts for firmware/embedded engineer interviews.

---

### 1. Memory Hierarchy

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

### 2. Cache

#### Cache Organization

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

#### Address Breakdown (example: 32-bit address, 256B cache, 4-way, 16B lines)

```
Total cache = 256 bytes
Line size   = 16 bytes  → Offset bits = log2(16) = 4
Num sets    = 256 / (4 ways * 16 bytes) = 4  → Index bits = log2(4) = 2
Tag bits    = 32 - 4 - 2 = 26

Address: [ 26-bit Tag | 2-bit Set Index | 4-bit Offset ]
```

#### Cache Miss Types (the 3 C's)

| Type | Cause | Fix |
|------|-------|-----|
| **Compulsory** (Cold) | First access to a block — never been in cache | Prefetching |
| **Conflict** | Two addresses map to same set, evicting each other | Increase associativity |
| **Capacity** | Cache too small to hold all active data | Bigger cache |

#### Write Policies

| Policy | Description | Pros | Cons |
|--------|-------------|------|------|
| **Write-through** | Write to cache AND memory simultaneously | Memory always up-to-date, simple | Slow writes, high bus traffic |
| **Write-back** | Write to cache only, write to memory on eviction | Fast writes | Complexity, dirty bit needed |
| **Write-allocate** | On write miss, load block into cache then write | Good for repeated writes | Wastes time if no reuse |
| **No-write-allocate** | On write miss, write directly to memory | Simpler | Misses future reads to same block |

Common combo: **write-back + write-allocate** (most modern processors)

#### Cache Coherence (Multi-core)

**Problem**: Core A writes to address X in its L1 cache. Core B still has the old value of X in its L1.

**Solution**: MESI protocol (4 states per cache line):
- **M**odified: Only this cache has it, it's dirty
- **E**xclusive: Only this cache has it, it's clean
- **S**hared: Multiple caches have it, clean
- **I**nvalid: Not valid

**Interview question**: "What happens when Core A writes to a Shared line?"
- Core A invalidates all other copies (Shared → Invalid in other caches), then transitions to Modified.

#### VIPT Caches

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

#### Cache Banking

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

#### Memory Consistency

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

##### TSO vs RVWMO

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

### 3. Pipeline

#### Classic 5-Stage Pipeline

```
Stage 1    Stage 2    Stage 3    Stage 4     Stage 5
+------+   +------+   +------+   +-------+   +------+
|  IF  | → |  ID  | → |  EX  | → |  MEM  | → |  WB  |
| Fetch|   |Decode|   |Execute|  |Memory |   |Write |
| Instr|   |& Reg |   | ALU  |  |Access |   | Back |
+------+   +------+   +------+   +-------+   +------+
```

**Ideal**: One instruction completes every cycle (throughput = 1 IPC).

#### Pipeline Hazards

##### Data Hazard
**Problem**: Instruction needs a result that isn't computed yet.
```
ADD R1, R2, R3    // writes R1 in WB stage (cycle 5)
SUB R4, R1, R5    // needs R1 in ID stage (cycle 3) — R1 not ready!
```

**Solutions**:
- **Forwarding/Bypassing**: Route result from EX output back to EX input — avoids stall
- **Stalling**: Insert bubble (NOP) and wait — simple but wastes cycles
- **Load-use hazard**: Load from memory (available after MEM stage) can't be fully forwarded — needs 1 stall cycle

##### Control Hazard
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

##### Structural Hazard
**Problem**: Two instructions need the same hardware resource simultaneously.
```
Example: Single memory port — IF and MEM both need memory in the same cycle.
```
**Solution**: Separate instruction and data memory/cache (Harvard architecture).

---

### 4. Virtual Memory

#### Address Translation

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

#### Virtual Address Breakdown (example: 32-bit VA, 4KB pages)

```
Page size = 4KB = 2^12 → Offset = 12 bits
VPN (Virtual Page Number) = 32 - 12 = 20 bits

VA: [ 20-bit VPN | 12-bit Page Offset ]
                       ↓ (translation)
PA: [ PPN (Physical Page Number) | 12-bit Page Offset ]
```

**Page offset stays the same** — only the page number gets translated.

#### Page Table

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

### 5. Interrupts

#### Interrupt Handling Flow

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

#### Key Concepts

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

### 6. Bus Protocols (ARM AMBA)

#### AXI / AHB / APB Comparison

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

#### AXI Key Concepts
- **5 channels**: Read Address (AR), Read Data (R), Write Address (AW), Write Data (W), Write Response (B)
- **Handshake**: Every channel uses `VALID`/`READY` handshake — transfer happens when both are high
- **Outstanding transactions**: Can issue multiple requests before getting responses (pipelined)
- **Burst types**: FIXED (same address), INCR (incrementing), WRAP (wrapping)

#### AXI Handshake (most important concept)

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

### 7. Endianness

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

### 8. DMA (Direct Memory Access)

#### What is DMA?

```
Without DMA (CPU copies data):          With DMA:
CPU reads byte from peripheral          CPU programs DMA: src, dst, length
CPU writes byte to memory               DMA transfers data independently
CPU reads next byte...                   CPU is free to do other work
(CPU is 100% busy copying!)             DMA interrupts CPU when done
```

**Purpose**: Transfer data between memory and peripherals (or memory-to-memory) without CPU involvement.

#### How DMA Works

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

#### DMA Transfer Modes

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

### Quick Reference Table

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

### Embedded-Specific Concepts

#### Volatile Keyword
```c
volatile int* reg = (volatile int*)0x40021000;
```
- Tells compiler: don't optimize away reads/writes to this address
- Use for: memory-mapped registers, shared variables with ISR, hardware status registers
- Without `volatile`: compiler might cache the value in a register and never re-read

#### Memory-Mapped I/O vs Port-Mapped I/O
- **Memory-mapped**: Peripherals share address space with memory. Access with normal load/store. (ARM uses this)
- **Port-mapped**: Separate address space, special instructions (`IN`/`OUT`). (x86 uses this for legacy I/O)

#### Watchdog Timer
- Hardware timer that resets the system if not periodically "kicked" (written to)
- Purpose: recover from firmware crashes or infinite loops
- Firmware must periodically reset the watchdog — if it hangs, watchdog expires and resets the chip

## Part 2 — Decoupled Frontend Specification

Source: `design_and_perf/rsd_fengze/Processor/Src/FetchUnit/deCoupled_FE.md`

Diagram assets remain under `design_and_perf/rsd_fengze/Processor/Src/FetchUnit/diagrams/`.

This document describes the frontend that is implemented in RTL behind
`RSD_MARCH_DECOUPLED_FRONTEND`.

It is not a future proposal. It intentionally removes the earlier raw-byte
fetch packet plan, FTQ-to-I$ bypass plan, I-cache MSHR assumptions, and the
claim that the BPU can run sixteen fetch blocks ahead of Fetch. The current RTL
keeps the existing RSD 32-bit instruction lane model and decouples prediction
from I-cache access through an FTQ.

### Implemented Files

| File | Role |
| --- | --- |
| `FetchUnit/FTQ_Types.sv` | FTQ entry, pointer, ID, and helper functions |
| `FetchUnit/FTQ_IF.sv` | FTQ interface shared by BPU, Fetch, Decode, Execute, Commit, and redirect logic |
| `FetchUnit/FTQ.sv` | FTQ ring buffer and lifecycle state |
| `FetchUnit/DecoupledBPU.sv` | BTB plus gshare predictor pipeline that enqueues FTQ entries |
| `Pipeline/FetchStage/NextPCStage.sv` | FTQ-head fetch request stage under the decoupled macro |
| `Pipeline/FetchStage/FetchStage.sv` | I-cache response stage plus four-entry fetch packet buffer |
| `Cache/ICache.sv` | Existing I-cache FSM plus a two-entry next-line prefetch queue |
| `Pipeline/PipelineTypes.sv` | `ftqID` and `ftqLast` fields in frontend and backend pipeline registers |
| `Pipeline/PreDecodeStage.sv` | Carries `ftqID` and `ftqLast` |
| `Pipeline/DecodeStage.sv` | Reads and updates FTQ lane prediction metadata |
| `Pipeline/RenameStage.sv` | Writes `ftqID` and `ftqLast` into ActiveList entries |
| `Pipeline/DispatchStage.sv` | Sends `ftqID` into issue queue entries |
| `Pipeline/IntegerBackEnd/*` | Reads FTQ prediction metadata and resolves branches into FTQ |
| `Pipeline/CommitStage.sv` | Sends predictor update and FTQ release information |
| `Recovery/RecoveryManager*.sv` | Carries recovery FTQ IDs for frontend squash |
| `Core.sv` | Instantiates `DecoupledBPU`, `FTQ`, and macro-specific stage wiring |

### High-Level Behavior

The original RSD frontend couples PC selection, branch prediction, and I-cache
request generation. Under `RSD_MARCH_DECOUPLED_FRONTEND`, this is split:

1. `DecoupledBPU` owns the prediction PC and predicts one fetch block.
2. The BPU writes the prediction result into the FTQ.
3. `NextPCStage` consumes the FTQ head and issues the demand I-cache request.
4. `FetchStage` receives I-cache data and pushes a lane packet into a small
   fetch buffer before PreDecode.
5. Backend stages carry `FTQ_ID` so branch resolution, recovery, predictor
   update, and FTQ release refer back to the original FTQ entry.

The predictor algorithm remains BTB plus gshare. The change is the pipeline
organization and metadata lifetime, not a replacement of the predictor.

### Frontend Deep-Dive Questions to Resolve

Use this checklist for the next detailed frontend walkthroughs. For each topic,
compare the implemented RSD path against a more advanced out-of-order CPU
frontend.

1. Lane PC generation:
   - What exactly is a lane PC?
   - Why does RSD create one PC per fetch lane instead of only one fetch-block
     PC?
   - How do lane PCs flow into BTB/PHT lookup, FTQ metadata, PreDecode, Decode,
     Execute branch comparison, and `ftqLast` marking?
   - RSD anchor: `DecoupledBPU` creates `bpS1LanePC`; `NextPCStage` recreates
     fetch lane PCs from `ftq.headEntry.startPC`.

2. RAS, indirect jump predictor, and BTB structure:
   - RSD does not currently implement RAS or an indirect target predictor in
     the inspected decoupled frontend, so treat these as advanced CPU review
     topics.
   - Need a detailed review of return-address-stack push/pop/repair behavior.
   - Need a detailed review of indirect jump target prediction, indexing,
     tags, target selection, and update timing.
   - Need a detailed review of RSD BTB fields, indexing, partial tags, target
     encoding, valid bits, `isCondBr`, lane-based lookup, and replacement
     behavior.

3. BTB working with gshare/TAGE:
   - Direction predictor predicts taken/not-taken; BTB predicts the taken
     target and identifies branch lanes.
   - What happens if multiple branch instructions are in one fetch line?
   - What happens on BTB miss: do we simply predict fall-through?
   - How does earliest-taken-lane selection work?
   - How would this change with TAGE instead of gshare?
   - When should the frontend learn that a predicted non-branch was actually a
     branch: PreDecode, Execute, Commit, or some hybrid?
   - RSD anchor: current predictor update is commit-driven; BTB updates only
     for resolved taken branches.

4. FTQ structure, purpose, and lifetime:
   - What exactly does the FTQ store: `startPC`, `fetchEndPC`, `predTarget`,
     `predTaken`, branch offset, BTB hit, conditional bit, GHR snapshot, PHT
     index/value, resolved result, and per-lane predictions?
   - Why does each FTQ entry need a GHR snapshot instead of relying only on one
     global GHR?
   - What are `FTQ_ID` and `ftqLast`?
   - How are `FTQ_ID`, `headPtr`, `tailPtr`, and `commitPtr` related but not
     identical?
   - When is an FTQ entry allocated: every predicted fetch block or only every
     predicted branch?
   - When is it released: branch execute, branch writeback, commit, recovery,
     or interrupt flush?

5. BTB update timing:
   - Is the BTB updated when PreDecode discovers a branch?
   - Is it updated at Execute when the real branch target is known?
   - Is it updated only at Commit to avoid wrong-path pollution?
   - What are the tradeoffs between early update and commit-only update?
   - RSD anchor: current decoupled BPU updates BTB from committed, resolved,
     taken branch metadata.

6. BTB partial target and partial tag:
   - RSD stores a partial BTB tag and partial target bits.
   - This is not because all branches have small architectural offsets; it is a
     storage/latency/energy tradeoff.
   - Need to understand what happens for long jumps, indirect jumps, calls,
     returns, and far targets when upper target bits differ from the current PC.
   - Need to distinguish partial target aliasing from BTB tag aliasing.

7. Fetch packet / instruction buffer format:
   - What exactly enters the fetch buffer?
   - Is it raw cacheline bytes, decoded instructions, predecode metadata, or
     lane packets?
   - What fields are carried per lane: valid bit, PC, instruction bits,
     `ftqID`, `ftqLast`, branch prediction metadata, and stage-control fields?
   - RSD anchor: the implemented buffer stores `PreDecodeStageRegPath
     lane[FETCH_WIDTH]`, not a raw byte stream.

8. TAGE-SC-L:
   - Need a detailed explanation of TAGE-SC-L because it is a common
     high-performance direction predictor family.
   - Cover TAGE provider/alternate provider, geometric histories, tagged
     tables, allocation, usefulness bits, statistical corrector, loop predictor,
     speculative history, update metadata, and frontend timing impact.
   - Compare against RSD's simpler BTB plus gshare PHT implementation.

9. Micro-op cache:
   - What is a micro-op cache or decoded instruction cache?
   - How is it different from I-cache, trace cache, loop buffer, and normal
     decode queue?
   - What does it store, how is it indexed, how does it interact with branch
     prediction, and how is it invalidated by self-modifying code or `FENCE.I`?
   - RSD anchor: not implemented in the inspected decoupled frontend.

### Real Pipeline Stage Mapping

The original RSD frontend has two live frontend pipeline stages:

| Original stage | Role |
| --- | --- |
| `NextPCStage` | Select next PC and drive the next I-cache read address |
| `FetchStage` | Hold fetched lane PCs, receive I-cache hit/data, and forward to PreDecode |

The decoupled frontend keeps those two fetch stages and adds a two-stage BPU in
front of them. FTQ is a queue and lifecycle structure, not a pipeline stage.

| Implemented logical stage | RTL location | Register boundary |
| --- | --- | --- |
| `BP_S0` | `DecoupledBPU.sv` | Combinational PC/GHR selection, lane PC adders, gshare index XOR, and BTB/PHT read addresses |
| `BP_S0 -> BP_S1` | `DecoupledBPU.sv` | `bpS1PC`, `bpS1LanePC`, `bpS1Ghist`, `bpS1Valid` |
| `BP_S1` | `DecoupledBPU.sv` | BTB tag match, PHT direction, earliest-taken pick, FTQ entry pack/enqueue |
| `FTQ` | `FTQ.sv` | Decoupling queue plus metadata lifetime from prediction through commit/recovery |
| `IF_S0` / `NextPCStage` | `NextPCStage.sv` | Consume FTQ head, form fetch lane PCs/`ftqID`/`ftqLast`, drive `icNextReadAddrIn`, advance FTQ head |
| `IF_S0 -> IF_S1` | `FetchStage.sv` pipe register | `FetchStageRegPath`: `valid`, `pc`, `ftqID`, `ftqLast` |
| `IF_S1` / `FetchStage` | `FetchStage.sv` and `ICache.sv` | Receive I-cache hit/data for the registered fetch lanes, capture into the four-entry packet buffer or bypass to PreDecode |

So the correct implemented frontend view is:

```text
BP_S0 -> BP_S1 -> FTQ -> IF_S0/NextPCStage -> IF_S1/FetchStage -> PreDecode
```

### Implemented Diagrams

#### Detailed Datapath Pipeline View

![Implemented decoupled frontend datapath](design_and_perf/rsd_fengze/Processor/Src/FetchUnit/diagrams/implemented_datapath_vertical.svg)

This is the primary frontend pipeline diagram. It shows the implemented
datapath with muxes, DFFs, adders, predictor SRAMs, FTQ pointers, I-cache
arrays/FSM, fetch buffer state, backend FTQ_ID lifecycle, and the real stage
boundaries listed above.

#### Connectivity Summary View

![Implemented decoupled frontend connectivity](design_and_perf/rsd_fengze/Processor/Src/FetchUnit/diagrams/implemented_pipeline.svg)

#### Pipeline Timing Summary View

![Implemented decoupled frontend pipeline timing](design_and_perf/rsd_fengze/Processor/Src/FetchUnit/diagrams/implemented_pipeline_timing.svg)

These diagrams are the implemented path. They replace the older proposal
diagrams that included FTQ-to-I$ bypass, raw cacheline/IBuffer forwarding, and
head advance from an IF_S1 stage. Those older SVG/PNG files are still in
`diagrams/` for history, but they should not be treated as the implemented
frontend.

### Macro and Core Wiring

The implemented macro is:

```systemverilog
RSD_MARCH_DECOUPLED_FRONTEND
```

`Core.sv` changes the frontend wiring under this macro:

- Instantiates `FTQ_IF ftqIF`.
- Instantiates `DecoupledBPU bpu(npStageIF, recoveryManagerIF, ftqIF)`.
- Instantiates `FTQ ftq(ftqIF)`.
- Instantiates `NextPCStage` with the `FTQ_IF.Fetch` modport.
- Instantiates `DecodeStage`, `IntegerExecutionStage`,
  `IntegerRegisterWriteStage`, and `CommitStage` with FTQ ports.
- Removes live use of the legacy `BTB` and `BranchPredictor` modules from the
  decoupled frontend path. They remain in the legacy `#else` path.

The redirect arbiter in `Core.sv` drives `ftqIF.redir*`:

- Redirect sources are interrupt, recovery, and Decode-stage early redirect.
- PC priority is interrupt, then recovery, then Decode-stage redirect.
- `redirFTQ_ID` is zero for interrupt, recovery FTQ ID for recovery, and Decode
  FTQ ID for Decode-stage redirect.
- `redirFlushAll` is asserted only for interrupt.
- `redirGhist` exists in the interface but is currently tied to zero and is not
  used by `DecoupledBPU`.

### FTQ Data Model

The FTQ has 16 entries:

```systemverilog
localparam int FTQ_ENTRY_NUM = 16;
localparam int FTQ_INDEX_WIDTH = $clog2(FTQ_ENTRY_NUM);
localparam int FTQ_PTR_WIDTH = FTQ_INDEX_WIDTH + 4;
typedef logic [FTQ_PTR_WIDTH-1:0] FTQ_Ptr;
typedef FTQ_Ptr FTQ_ID;
```

`FTQ_ID` is the full FTQ pointer value, not only the low index bits. The low
bits select the physical FTQ array entry through `ToFTQ_Index(id)`. The upper
bits let downstream stages distinguish wrapped generations.

`FTQ_Entry` contains:

- Fetch block identity:
  - `valid`
  - `startPC`
  - `fetchEndPC`
  - `predTarget`
- Scalar prediction summary:
  - `predTaken`
  - `brOffsetBytes`
  - `brInsnBytes`
  - `btbHit`
  - `isCondBr`
- Gshare update metadata:
  - `ghistSnapshot`
  - `phtIndex`
  - `phtPrevValue`
- Execute resolution metadata:
  - `resolved`
  - `execBrAddr`
  - `execIsCondBr`
  - `execTaken`
  - `execTarget`
  - `execPredTaken`
  - `mispred`
  - `execGlobalHistory`
  - `execPhtPrevValue`
- Per-lane compatibility metadata:
  - `lanePred[FETCH_WIDTH]`
  - `execLanePred[FETCH_WIDTH]`

`lanePred` is used by Decode for early branch handling. `execLanePred` is used
by Execute for the later branch comparison. Both are initialized by BPU and can
be updated by Decode for the matching PC.

### FTQ Pointers and Lifetime

`FTQ.sv` maintains three pointers:

- `tailPtr`: next BPU enqueue position.
- `headPtr`: next fetch block to consume.
- `commitPtr`: oldest FTQ entry still needed by backend/commit.

The queue is empty when `headPtr == tailPtr`.

The queue is considered full when either:

- The lifetime window from `commitPtr` to `tailPtr` reaches `FTQ_ENTRY_NUM`, or
- The BPU runahead throttle is reached.

The implemented runahead throttle is:

```systemverilog
localparam FTQ_BPU_MAX_AHEAD_ENTRY_NUM = 1;
```

So the BPU is currently allowed to produce only one unconsumed fetch block ahead
of Fetch. The FTQ still has 16 entries because entries remain live after Fetch
consumes them and until Commit releases them.

Fetch advances `headPtr` when `NextPCStage` accepts the FTQ head:

```systemverilog
headAccepted = ftq.headValid && !stall && !clear && !redirect && !port.rst;
ftq.fetchAdvanceHead = headAccepted;
```

Commit advances `commitPtr` through `commitReleaseValid` and
`commitReleaseID`. A normal release happens when a committed ActiveList entry
has `ftqLast`. Recovery also releases through the recovery FTQ ID.

On interrupt redirect, `redirFlushAll` resets `headPtr`, `tailPtr`, and
`commitPtr` and clears valid bits. On non-interrupt redirect, FTQ moves
`headPtr` and `tailPtr` to the entry after `redirFTQ_ID` within the current
`commitPtr..tailPtr` window. This drops younger speculative fetch entries while
preserving older entries that can still be needed for backend commit/recovery.

### DecoupledBPU

`DecoupledBPU.sv` implements the live predictor path. It still uses BTB plus
gshare PHT:

- BTB and PHT arrays are instantiated inside `DecoupledBPU`.
- PHT index is formed by XORing PC index bits with the speculative global
  history.
- Reset initializes BTB entries invalid and PHT counters to weak taken.

The BPU has a one-cycle SRAM-read style pipeline:

- The read address is `readPC`.
- SRAM outputs are interpreted in the next registered state:
  - `bpS1PC`
  - `bpS1LanePC[FETCH_WIDTH]`
  - `bpS1Ghist`
  - `bpS1Valid`

`readPC` selection:

1. Redirect PC when `ftq.redirValid` or recovery is active.
2. Hold `bpS1PC` when `ftq.ftqFull`.
3. Otherwise use the previous S1 entry's predicted target or sequential end PC.

The BPU enqueues when S1 is valid, there is no redirect, and FTQ is not full.

For each lane, the BPU checks:

- The lane is within the current I-cache line.
- BTB valid/tag hit.
- PHT MSB predicts taken.

If more than one lane predicts taken, the earliest taken lane wins. If no lane
predicts taken, the fetch block ends at the sequential end of the block, clipped
to the current I-cache line.

#### BTB SRAM Organization

The implemented BTB is a direct-indexed SRAM table, not a fully associative
CAM. The current configuration uses 1024 entries:

- `BTB index = PC[11:2]` because instructions are 4-byte aligned and
  `log2(1024) = 10`.
- `BTB tag = PC[15:12]`; this is only a partial tag, so aliasing is possible.
- Each fetch lane independently reads the BTB using that lane's instruction PC,
  not the cacheline address.

Each BTB entry stores `valid`, partial `tag`, partial target `data`, and
`isCondBr`. On a hit, the predicted target PC is reconstructed from the current
PC upper bits plus the stored target bits:

```systemverilog
predTarget = { currentPC[31:15], btbEntry.data[12:0], 2'b00 };
```

This saves BTB storage and works well for local control flow, but long-range
targets can be reconstructed incorrectly and are later recovered by branch
resolution.

The BPU writes both scalar FTQ metadata and per-lane `lanePred`/`execLanePred`
metadata. This preserves compatibility with the existing branch resolver and
execute branch comparison flow while allowing downstream stages to carry only an
`FTQ_ID`.

#### GHR Update and Restore

On a successful enqueue, the BPU speculatively updates its global history for
conditional BTB-hit lanes, stopping at the first predicted-taken lane.

On branch misprediction, the BPU restores from the branch result carried by the
existing backend branch result path:

- Conditional branch: `(oldGlobalHistory << 1) | execTaken`.
- Non-conditional branch: `oldGlobalHistory`.

The FTQ interface has a `redirGhist` field, but the current implementation does
not consume it.

#### Predictor Update

Predictor update is commit driven:

- `CommitStage` asserts `bpUpdateValid[i]` for committed branch entries.
- `DecoupledBPU` reads `ftq.bpUpdateEntry[i]`.
- PHT updates when the FTQ entry is resolved.
- BTB updates only for resolved taken branches.
- PHT update uses `execBrAddr`, `execGlobalHistory`, and `execPhtPrevValue`.

### NextPCStage Fetch Request Path

Under `RSD_MARCH_DECOUPLED_FRONTEND`, `NextPCStage` no longer owns branch
prediction. It selects the fetch request PC from:

1. FTQ redirect PC.
2. Interrupt PC.
3. Recovery PC.
4. `ftq.headEntry.startPC` when the FTQ has a head.
5. The existing PC register output as fallback.

When the FTQ head is accepted, `NextPCStage` creates a `FetchStageRegPath` lane
packet:

- `pc = ftq.headEntry.startPC + lane * INSN_BYTE_WIDTH`
- `ftqID = ftq.headID`
- `valid = lane PC is before fetchEndPC and does not cross the I-cache line`
- `ftqLast = last valid lane in this FTQ fetch block`

The I-cache request address is:

- Redirect PC during redirect.
- The stalled IF-stage PC when Fetch is stalled on an existing request.
- Otherwise the selected fetch PC.

There is no FTQ-to-I$ bypass in the current RTL. Fetch consumes the FTQ head
through `NextPCStage`.

### FetchStage Packet Buffer

`FetchStage.sv` keeps the existing RSD instruction-lane interface and adds a
conservative fetch packet buffer under the decoupled macro.

The buffer is:

```systemverilog
localparam int FETCH_BUFFER_ENTRY_NUM = 4;
```

Each entry stores `PreDecodeStageRegPath lane[FETCH_WIDTH]`. It is not a raw
byte stream, and it does not redesign PreDecode for compressed instructions.

A packet is ready when:

```systemverilog
pipeReg[0].valid && port.icReadHit[0] && !packetCapturedReg
```

The packet is either:

- Bypassed directly to PreDecode when the buffer is empty and PreDecode can
  accept it, or
- Pushed into the four-entry buffer.

Fetch applies backpressure when the current packet is ready but the buffer
cannot accept it. I-cache miss behavior is still the existing frontend stall:

```systemverilog
pipeReg[0].valid && !port.icReadHit[0]
```

`packetCapturedReg` prevents the same I-cache response from being pushed more
than once during a stall.

Branch prediction is no longer calculated in `FetchStage` under the decoupled
macro. `updateBrHistory` is driven false there, and Decode/Execute recover
prediction metadata through the FTQ.

### I-Cache Prefetch

The implemented prefetcher is a simple next-line request path:

- `NextPCStage` requests a prefetch for `NextICacheLineAddr(startPC)` when it
  accepts an FTQ head and the FTQ entry is not predicted taken.
- `ICache.sv` has a two-entry prefetch queue.
- Demand fetch has priority over queued prefetch work.
- Prefetch probing starts only when the I-cache is in `ICACHE_PHASE_READ_CACHE`,
  there is no demand read, the prefetch queue is non-empty, and there is no
  flush request.

The I-cache does not have an MSHR in this implementation. A prefetch miss uses
the existing I-cache miss FSM:

1. `ICACHE_PHASE_PREFETCH_PROBE`
2. `ICACHE_PHASE_MISS_READ_MEM_REQUEST`
3. `ICACHE_PHASE_MISS_READ_MEM_RECEIVE`
4. `ICACHE_PHASE_MISS_WRITE_CACHE`

If a prefetch probe hits, it updates NRU state and pops the queue entry. If a
demand fetch appears during a prefetch probe, demand fetch wins and the prefetch
entry is retried later.

### Frontend Extra Topics to Review

These are not implemented in the inspected RSD decoupled frontend, but they are useful interview topics if the discussion moves beyond BTB/gshare/FTQ basics.

#### Uop Cache / Decoded Instruction Cache

Purpose:
- Cache decoded uops or decoded instruction metadata so hot loops can bypass part of fetch/decode.
- Reduce frontend power by avoiding repeated decode work.
- Improve frontend bandwidth when decode is the bottleneck.

Design questions:
- Is it indexed by virtual PC or physical PC?
- Does it store fixed uops, macro-ops, or decoded instruction packets?
- How are branch boundaries and taken targets represented?
- How is it invalidated on self-modifying code, I-cache maintenance, context switch, or `FENCE.I`?
- What happens when the uop cache hits but branch prediction metadata misses?

Modeling hooks:
- Uop-cache hit rate.
- Decode-bypass cycles.
- Frontend power proxy from decode activity reduction.
- Mispredict recovery latency when refetching from uop cache versus I-cache.

#### Macro-Op / Uop Fusion

Fusion idea:
- Combine multiple architectural instructions or decoded uops into one internal uop when the pair is common and safe.
- Common examples in other ISAs include compare+branch, address-generation combinations, and load-op forms.

Performance benefit:
- Reduces rename/dispatch/issue/retire pressure.
- Can improve effective frontend bandwidth and ROB occupancy.
- May reduce register-file and bypass traffic.

Constraints:
- Fusion must preserve exceptions, flags/predicate semantics, debug behavior, and precise retirement.
- Fused instructions may need special handling in branch recovery and commit accounting.

#### Decode Bandwidth and Frontend Bubbles

Decode bandwidth:
- Fetch bandwidth, decode width, rename width, and dispatch width must be balanced.
- A 4-wide fetch feeding 2-wide decode can still bottleneck at decode.
- Variable-length instructions or compressed instructions can create alignment and packet-boundary issues.

Taken-branch bubbles:
- A taken branch inside a fetch block can waste later lanes in that same block.
- If the predictor/BTB target is late, the next useful fetch block may be delayed.
- Direction hit but target miss still creates redirect bubbles.

Fetch alignment:
- Fetch groups are usually aligned to I-cache lines or fetch blocks.
- A hot loop crossing a cache-line boundary can require two fetches per iteration.
- Branch targets landing near the end of a fetch block may reduce useful fetched instructions.

Modeling hooks:
- Fetched instructions versus useful decoded instructions.
- Decode queue empty/full cycles.
- Taken branch lane position.
- Fetch-block crossing count.
- I-cache line split count.
- Redirect latency by source: decode redirect, execute branch, exception, interrupt.

### FTQ Metadata Full Lifecycle

The implemented design keeps the FTQ entry live from prediction until the fetch
block commits or is recovered. Downstream stages carry `FTQ_ID` rather than a
full `BranchPred` struct.

Lifecycle:

1. BPU enqueues an `FTQ_Entry`.
2. `NextPCStage` assigns `ftqID` and `ftqLast` to fetch lanes.
3. `FetchStage`, `PreDecodeStage`, `DecodeStage`, and `RenameStage` carry
   `ftqID` and `ftqLast`.
4. `RenameStage` writes `ftqID` and `ftqLast` into ActiveList entries.
   `ftqLast` is kept only on the last micro-op of the final instruction in the
   FTQ fetch block.
5. `DispatchStage` writes `ftqID` into integer branch subinfo and into complex,
   memory, and FP issue queue entries.
6. `IntegerExecutionStage` reads `execLanePred` from FTQ using `ftqID` and PC,
   then compares the actual branch result against that prediction.
7. `IntegerRegisterWriteStage` writes resolved branch metadata back to the FTQ
   through `execResolve*`.
8. Complex, memory, and FP writeback stages propagate `ftqID` into
   `ActiveListWriteData` so recovery can identify the correct FTQ point even
   when the recovering op is not an integer branch.
9. `ActiveList` records the oldest recovery FTQ ID.
10. `RecoveryManager` forwards recovery FTQ IDs to the frontend redirect path.
11. `CommitStage` sends branch predictor updates and releases FTQ entries when
    committed ActiveList entries carry `ftqLast`.

This is the "full lifecycle" FTQ path in the current RTL: the entry is held
past Fetch and Decode, is visible to Execute and Commit, and is released only
after the corresponding fetch block has committed or recovery has selected the
entry.

### Decode-Stage FTQ Use

`DecodeStage` reads FTQ entries for each decode lane:

```systemverilog
ftq.decodeReadID[i] = pipeReg[i].ftqID;
brPredIn[i] = FTQBranchPredForPC(ftq.decodeReadEntry[i], pipeReg[i].pc);
```

The existing `DecodedBranchResolver` still performs early redirect detection.
When Decode completes, it writes corrected lane prediction metadata back into
the FTQ:

```systemverilog
ftq.decodeUpdateValid[i]
ftq.decodeUpdateID[i]
ftq.decodeUpdatePC[i]
ftq.decodeUpdatePred[i]
```

`FTQ.sv` updates both `lanePred` and `execLanePred` for the matching PC. This
keeps Decode's early branch handling and Execute's later branch comparison
consistent for the same instruction.

Decode-stage redirects also carry `nextFlushFTQ_ID` and `nextFlushPC`. For
cases where Decode's early redirect would require already-renamed backend work
to be flushed, `RenameStage` and `RecoveryManager` support a rename-stage
recovery path under the decoupled frontend macro.

### Recovery and Squash

Frontend redirect sources are:

- Interrupt redirect from `NextPCStageIF`.
- Recovery redirect from `RecoveryManager`.
- Decode-stage early redirect from `DecodeStage`.

The FTQ redirect ID is the instruction/fetch block that caused the redirect.
Normal redirect sets the FTQ fetch and enqueue pointers to the entry after that
ID, removing younger predictions. Interrupt redirect flushes the whole FTQ.

Backend selective flush still uses ActiveList ranges. The FTQ ID is additional
frontend metadata used to align the predictor/fetch queue with the backend
recovery point.

### What This Implementation Does Not Do

The following items were in earlier design notes but are not implemented:

- No `RSD_MARCH_DECOUPLED_FE` macro. The macro is
  `RSD_MARCH_DECOUPLED_FRONTEND`.
- No raw-byte instruction buffer.
- No compressed-instruction byte-stream PreDecode redesign.
- No FTQ-to-I$ bypass.
- No sixteen-block BPU runahead. Current runahead is one unconsumed FTQ entry.
- No I-cache MSHR.
- No independent architectural GHR register driven by `redirGhist`.
- No separate standalone prefetch arbiter. Prefetch is integrated into
  `ICache.sv`.

### Validation Status

The decoupled frontend checkpoint was validated with the existing RSD functional
test flow. Local benchmark staging for Dhrystone and CoreMark is wired and has
run successfully:

| Test | Result | Elapsed cycles |
| --- | --- | ---: |
| Dhrystone | PASS | 1,182,719 |
| CoreMark | PASS | 4,209,057 |

Embench is intentionally not part of the regular FE validation loop because the
full suite is too long for iteration.

## Part 3 — Backend Microarchitecture Details

This section is the backend review placeholder for a Qualcomm-style CPU performance modeling interview. Use it to connect generic out-of-order backend concepts to the RSD implementation, then compare against BOOM or another open-source OoO core when useful.

### 1. RSD Backend Snapshot

RSD parameters to remember:
- Fetch / decode / rename / dispatch width: 2.
- Commit width: 2.
- Physical scalar integer registers: 64.
- Issue queue entries: 16.
- ActiveList entries: 64; this is RSD's ROB-equivalent structure.
- Load queue / store queue entries: 16 / 16.
- Integer issue width: 2; complex integer issue width: 1 unless unified with memory; memory issue width: 2 in the split load/store configuration.

Primary code anchors:
- `MicroArchConf.sv` — backend sizing knobs.
- `Pipeline/RenameStage.sv` — rename, allocation, serialization checks.
- `Pipeline/DispatchStage.sv` — dispatch into scheduler / issue structures.
- `Scheduler/` — source readiness, wakeup/select, issue queue, replay.
- `RenameLogic/ActiveList.sv` — ROB-like in-order allocation, completion state, recovery bookkeeping.
- `Pipeline/CommitStage.sv` — commit decision, store/load release, recovery trigger.
- `Recovery/RecoveryManager.sv` — frontend/backend flush and recovered PC selection.

### 2. Rename

What to explain:
- Logical registers are mapped to physical registers through rename-table state.
- A destination register allocates a fresh physical register; the old physical register is retained until commit so precise state can be restored.
- Source operands read producer tags and readiness; renamed operands carry physical register numbers and issue-queue dependency information.
- Rename allocates backend resources in program order: ActiveList entry, issue-queue entry, LQ/SQ entry for memory ops, and physical destination register when needed.
- Rename must stall on resource pressure: ActiveList full, issue queue full, free-list empty, LQ/SQ full, or a serialized instruction that requires an empty machine.

RSD-specific notes:
- Serialized ops such as fences use rename-stage gating, because they need prior committed state and an empty store queue before entering the backend.
- RSD records LSQ recovery pointers with each op so a recovery can restore LQ/SQ tail state.

Interview prompts:
- Why does rename need both speculative and committed mapping tables?
- What happens when a destination physical register is freed too early?
- Where does backpressure first show up when the backend is full?

### 3. ROB / ActiveList

Generic ROB state model:
- **Allocated / busy / not finished**: entry exists, but execution result has not reached writeback.
- **Executed / complete**: functional unit has produced result or fault state; entry waits for older entries.
- **Exception / recovery pending**: entry contains branch misprediction, replay, trap, or fault metadata.
- **Committed / retired**: head entry updates architectural state and is popped.
- **Squashed / flushed**: younger speculative entries are removed after redirect, exception, or replay recovery.

RSD-specific model:
- `ActiveList.sv` is a FIFO with tail allocation and head commit/recovery readout.
- Main entry RAM stores metadata such as PC, destination register, load/store flags, branch flags, FTQ ID, and LSQ pointers.
- A separate execution-state RAM tracks whether each entry is still unfinished or can be treated as successful at commit.
- A recovery register records the oldest in-flight recovery point from writeback stages, including PC, execution state, fault address, and LSQ pointers.

Key details to remember:
- The ROB/ActiveList gives precise exceptions because commit is still in order.
- Head pointer moves forward only for committed entries.
- Tail pointer moves forward on allocation; on squash, tail is effectively rewound by recovery logic.
- Multi-uop instructions need a `last` marker or equivalent so commit can retire complete instructions, not half an instruction.

### 4. Issue Queue

What to explain:
- The issue queue holds renamed but not-yet-issued micro-ops.
- Entries store source tags, destination tags, op class, ActiveList pointer, LSQ pointers, and execution metadata.
- The queue can be unified or split by type. Unified queues improve utilization but cost more CAM/selection power; split queues simplify select and routing but can fragment capacity.

RSD-specific notes:
- RSD has scheduler data plus type-specific issue payloads for integer, complex integer, memory, and optional FP paths.
- The scheduler tracks selected entries and then routes them into the matching issue stage.
- ReplayQueue is shared across pipes; this matters for performance modeling because a memory-heavy workload can create global replay pressure.

Interview prompts:
- Why is issue-queue wakeup/select often a timing-critical loop?
- What is the tradeoff between issue queue size and frequency/power?
- How would widening issue affect CAM comparisons and select arbitration?

### 5. Wakeup / Select

Wakeup:
- Producers broadcast destination physical tags when results become available.
- Waiting issue-queue entries compare source tags against broadcast tags.
- When all required operands are ready, the entry becomes eligible to issue.

Select:
- Select chooses ready entries for available functional-unit ports.
- Policies usually prioritize older ops for fairness and forward progress, while also respecting port type and replay constraints.
- Stores often do not wake up consumers because their architectural destination is memory, not a register.

RSD-specific notes:
- `Scheduler/WakeupLogic.sv`, `SourceCAM.sv`, `ProducerMatrix.sv`, and `SelectLogic.sv` are the key anchors.
- RSD explicitly notes that store ports do not wake consumers; load and ALU writebacks do.

Performance-modeling hooks:
- Model wakeup/select as one or more cycles depending on issue queue size and target frequency.
- Count issue conflicts separately from operand-not-ready stalls.
- Track per-port utilization to identify structural bottlenecks.

### 6. Execute

Backend execution groups to review:
- Integer ALU: branch resolution, simple arithmetic, address-independent integer ops.
- Complex integer: multiply/divide, potentially longer latency or pipelined execution.
- Memory: address generation, D$ access, SQ forwarding, MSHR allocation, replay.
- FP/vector if implemented: longer pipelines, separate register file and bypass network.

RSD-specific notes:
- Integer branch resolution happens in the integer backend and writes branch result metadata.
- Memory execution has multiple backend stages: address, tag, data, writeback.
- Long-latency operations must either hold pipeline state, reserve replay resources, or write back when complete.

### 7. Commit and Recovery Overview

Commit rules:
- Commit only the oldest contiguous completed instructions.
- Commit updates the committed rename map, releases old physical registers, releases committed LQ entries, and marks retired stores for store-commit processing.
- Store data should not update memory architecturally until the store is safe to retire.

Recovery rules:
- Branch misprediction and some replay conditions may be detected before the mispredicted op reaches ROB head.
- Exceptions, traps, and CSR-visible events usually wait until commit to preserve precise architectural state.
- Recovery chooses a flush range, restores rename/LSQ/FTQ state, and sends a recovered PC to the frontend.

RSD-specific notes:
- RSD can start recovery from writeback for refetch-style events while CSR-visible traps/faults are handled at commit.
- `RecoveryManager.sv` always flushes the frontend during recovery; backend structures use selective flush based on ActiveList pointer range.
- This gives a concrete example for discussing full flush versus early restart.

### 8. Architecture Performance Evaluation Hooks

This section is the architecture-side view of performance modeling: what state, counters, and model knobs should exist so a backend proposal can be evaluated cleanly.

Core methodology:
- Start from a baseline core and define the one design question being tested.
- Choose metrics before running experiments: IPC/CPI, miss penalty, queue occupancy, replay count, port conflict count, utilization, energy proxy, and area/timing risk.
- Separate functional misses from structural stalls. A D$ miss, MSHR-full stall, D$ port conflict, and replay-queue-full event need different fixes.
- Use CPI-stack style accounting when possible, because CPI components are additive and easier to explain than raw IPC deltas.
- Run sensitivity sweeps on one or two key parameters: ROB size, issue queue size, MSHR count, LQ/SQ size, branch penalty, cache latency, memory latency.
- Validate the model against code evidence, waveforms, counters, or known RTL behavior before using the result to justify an architecture change.

Interview framing:
- A good performance model is not only a fast simulator. It should make bottlenecks visible, preserve the right resource constraints, and avoid attributing a speedup to the wrong mechanism.
- For RSD-based discussion, tie each claim to a concrete block such as `ActiveList.sv`, `SelectLogic.sv`, `LoadQueue.sv`, `StoreQueue.sv`, `DCache.sv`, or `RecoveryManager.sv`.

### 9. PMU and Performance Counter Interpretation

Why this matters:
- Performance counters are the bridge between model results, RTL simulation, and real silicon measurement.
- They help answer "what changed?" after an IPC delta, but they can mislead if the event definitions are unclear.

Counters to know:
- Retired instructions and cycles: base for IPC/CPI.
- Frontend stalls: I-cache miss, ITLB miss, branch redirect, fetch bubble, decode queue empty/full.
- Branch events: conditional branches, mispredictions, BTB misses, RAS misses, indirect misses.
- Backend stalls: ROB full, issue queue full, physical register free-list empty, LQ/SQ full, commit blocked.
- Memory events: L1/L2/LLC accesses and misses, DTLB misses, page walks, MSHR full, replay count, store-forwarding failure.
- Structural events: port conflicts, bank conflicts, FU utilization, cache-array arbitration losses.
- Power proxies: active cycles, gated cycles, SRAM/CAM access counts, predictor table accesses.

CPI-stack discipline:
- CPI components should be mutually exclusive when possible.
- If events overlap, report them as diagnostic counters, not additive CPI components.
- Normalize counters: MPKI, branch MPKI, miss latency, bandwidth, occupancy, utilization, and replay rate.
- Always pair a top-line metric with a bottleneck metric. Example: IPC improved because MSHR-full cycles dropped, not merely because L1D MPKI changed.

Common pitfalls:
- Counter skid: sampled PC may point after the causing instruction.
- Multiplexing: limited hardware counters can require multiple runs, which adds run-to-run noise.
- Event ambiguity: "stall cycle" may mean no dispatch, no issue, no retire, or resource-specific backpressure.
- Double counting: a D$ miss, replay, and ROB-full cycle may all describe the same root cause.
- Warmup effects: early misses or predictor cold-start can distort short measurements.
- User/kernel attribution and interrupts can matter for full-system workloads.

Interview framing:
- I would first ask what each counter precisely counts and whether events are exclusive. Then I would build a small CPI-stack or bottleneck table and confirm the diagnosis with directed microbenchmarks.

### 10. Validation and Calibration

Validation goal:
- Prove that the model is accurate enough for the design question being asked. It does not need to be perfect for all workloads, but it must preserve the bottlenecks under discussion.

Validation levels:
- Unit tests: queues, predictors, cache tag/index decode, MSHR merging, replay behavior, and counter updates.
- Directed microbenchmarks: isolate branch penalty, cache miss latency, MSHR capacity, TLB miss latency, store-forwarding cases, and fence serialization.
- RTL/waveform comparison: check per-cycle behavior for selected sequences when RTL exists.
- Silicon/perf-counter comparison: compare aggregate counters and trends when hardware is available.
- Sensitivity checks: sweep latency/capacity knobs and verify monotonic or explainable behavior.

Calibration method:
- Start with architectural constants: widths, queue sizes, latencies, associativity, MSHR count, predictor sizes.
- Tune uncertain timing parameters only after structural behavior is correct.
- Use separate workloads for calibration and validation to avoid overfitting.
- Report error with both top-line metrics and bottleneck metrics: IPC error, MPKI error, branch miss error, latency distribution error, and stall-breakdown error.

Failure modes:
- Matching IPC for the wrong reason.
- Using average latency where queue occupancy or overlap matters.
- Missing wrong-path, OS, interrupt, TLB, or coherence effects for workloads where they matter.
- Calibrating to one benchmark and losing generality.

Interview framing:
- I would rather explain a model's limitations explicitly than claim cycle accuracy without evidence. Credibility comes from clear assumptions, code evidence, validation tests, and counter agreement.

### 11. Backend Review Checklist

- Can I draw rename -> dispatch -> schedule -> issue -> register-read -> execute -> writeback -> commit?
- Can I explain what each ROB/ActiveList entry stores?
- Can I explain why branch recovery can sometimes start before commit, while exceptions wait until commit?
- Can I explain how a store becomes architectural later than a register-writing ALU op?
- Can I map each backend concept to one RSD source file?

## Part 4 — LSU + L1D Optimization Specification

Source: `design_and_perf/rsd_fengze/Processor/Src/LoadStoreUnit/LSU_Optimization.md`

Diagram assets remain under `design_and_perf/rsd_fengze/Processor/Src/Cache/diagrams/`.

**Status:** DRAFT v0.1 — 2026-04-22
**Owner:** fy2243
**Scope:** unified load/store unit and L1 data-cache optimizations on top of current `Processor/Src/LoadStoreUnit/` and `Processor/Src/Cache/DCache.sv`
**Gate macros:** `RSD_MARCH_LSU_SEL_SQ`, `RSD_MARCH_LSU_LRB`, `RSD_MARCH_DC_PREFETCH`, `RSD_MARCH_DC_WAYPRED` (legacy path must still build when undefined)

This document is the **golden reference** for the LSU/L1D optimization block:
- **Selective Store Queue Lookup** — reduce the 32-comparator full-CAM on every load to a partial-tag prefilter + gated full compare.
- **Load Replay Buffer (LRB)** — dedicated structure for blocked loads; replay from LSU directly without round-tripping through IQ / ReplayQueue.
- **L1D Next-Line Prefetcher** — issue low-priority `load_addr + line` prefetches for sequential demand loads.
- **L1D Way Predictor** — predict the likely D$ way and gate tag-array activation; recover with a 1-cycle other-way retry on misprediction.

RTL must not be written until this spec is frozen.

---

### 0. Unified LSU + L1D Pipeline Diagrams

Top-to-bottom vertical flow through the 4 LSU stages plus the coupled L1D pipeline. The four resume-level optimizations are highlighted in yellow:
- **Optimization A** (Selective SQ Lookup) is shown inside stage ② D$TAG — partial-tag column on the SQ, partial-tag compare row, and GATED full CAM.
- **Optimization B** (Load Replay Buffer) is shown as the tall block on the right; captures blocked loads from stage ② D$TAG (matching legacy RSD block detection at [MemoryTagAccessStage.sv:493](design_and_perf/rsd_fengze/Processor/Src/Pipeline/MemoryBackEnd/MemoryTagAccessStage.sv#L493) — `ldUpdate[i] && !ldRegValid[i]`), replays directly into stage ① D$ADDR (bypassing IQ and scheduler).
- **Optimization C** (L1D Next-Line Prefetcher) and **Optimization D** (L1D Way Predictor) are shown as L1D blocks on the same D$ADDR/D$TAG/D$DATA path.

![L1D optimized datapath](design_and_perf/rsd_fengze/Processor/Src/Cache/diagrams/dcache_datapath_vertical.png)

*(source: [dcache_datapath_vertical.svg](design_and_perf/rsd_fengze/Processor/Src/Cache/diagrams/dcache_datapath_vertical.svg))*

---

### 1. Baseline — Current RSD LSU

#### 1.1 Pipeline stages
Loads and stores travel through four LSU-adjacent stages (names from `Processor/Src/Pipeline/MemoryBackEnd/`):

| Stage | Action |
|---|---|
| `MemoryExecutionStage`  (D$ADDR) | Address compute; issue D$ read request through `DCacheArrayPortArbiter` |
| `MemoryTagAccessStage`  (D$TAG)  | D$ tag compare; **SQ CAM lookup** for loads; MSHR conflict / MSHR-bypass check |
| `MemoryAccessStage`     (D$DATA) | Data forwarding mux (SQ fwd / D$ / MSHR); result latch |
| `MemoryRegisterWriteStage` (D$RW) | Writeback to register file |

#### 1.1.1 L1D configuration (from `MicroArchConf.sv`)

| Param | Value |
|---|---|
| `CONF_DCACHE_WAY_NUM` | 2 |
| `CONF_DCACHE_INDEX_BIT_WIDTH` | 8 → **256 sets** |
| `CONF_DCACHE_LINE_BYTE_NUM` | 8 |
| Total capacity | 2 × 256 × 8 = **4 KB** |
| `CONF_DCACHE_MSHR_NUM` | 2 |

Baseline D$ organization:
- Tag array: one read-side array slot and one write-side array slot. The read-side slot indexes all tag-way arrays in parallel; current `DCacheTagSRAM_TSMC16` has no read-enable input and ties the SRAM `REB` low.
- Data array: functionally selects one `hit_way` in D$DATA, but current wrappers index every data-way array and then mux the selected way.
- Misses allocate one of two D$ MSHRs; fills write back into a normal D$ way using tree-LRU replacement.
- There is no demand-triggered prefetcher and no way predictor today.

#### 1.2 Key structures (baseline)
| Structure | Size | Source | Notes |
|---|---|---|---|
| Load Queue (LQ) | 16 | [LoadQueue.sv](design_and_perf/rsd_fengze/Processor/Src/LoadStoreUnit/LoadQueue.sv) | FIFO, tracks in-flight loads; allocated at rename |
| Store Queue (SQ) | 16 | [StoreQueue.sv](design_and_perf/rsd_fengze/Processor/Src/LoadStoreUnit/StoreQueue.sv) | Address/control metadata is a flop array; store data is `DistributedMultiPortRAM`; FIFO discipline |
| Global ReplayQueue | 20 | `Processor/Src/Scheduler/ReplayQueue.sv` | **Shared across all pipes** — any stall fills it |
| MSHR | 2 | in DCache | Miss tracking |

#### 1.2.1 Store Queue / Store Buffer Discussion

Why we need it:
- Stores cannot update cache/memory while speculative, because an older branch, exception, or replay may squash them.
- Loads younger than a store still need correct data if they read the same address, so the store buffer must support store-to-load forwarding.
- Stores often miss in cache or wait for memory; buffering lets the core retire the store logically and drain it to the memory hierarchy later.
- The store buffer preserves memory ordering by keeping stores in program order and by exposing unresolved older stores to younger loads.

Generic store-buffer responsibilities:
- Allocate an entry at rename/dispatch for every store.
- Capture address, byte mask, word mask, data, and condition/valid state when the store executes.
- Forward matching bytes to younger loads.
- Detect partial-forwarding cases where the store covers only part of the load.
- Drain committed stores to L1D in order.
- Recover tail state when younger speculative stores are flushed.

RSD implementation:
- `StoreQueue.sv` has 16 FIFO entries with `headPtr` / `tailPtr`. The address/control side is a flop array; store data is in a `DistributedMultiPortRAM`.
- Store address/data are written when the store executes; `finished` marks an address/data entry usable for forwarding.
- On each load, `StoreQueue.sv` compares the load block address and byte/word enables against older finished SQ entries, then uses `CircularRangePicker` to select the relevant store.
- If a matching store does not cover all requested bytes, RSD marks a forwarding miss and the load is recovered/replayed.
- `StoreCommitter.sv` drains retired stores through a commit pipeline: `Commit -> SQ read -> D$ tag -> D$ data`.
- D$ writes are acknowledged through `dcWriteReqAck`; a store miss can allocate an MSHR and stall the store-commit pipeline until the writeback/refill path completes.

Interview framing:
- Store queue before commit = speculative memory-order structure.
- Store commit pipeline after commit = non-speculative drain path into D$ / memory.
- A high-performance core may add a separate write buffer below L1 so committed dirty data can move toward L2 without blocking the L1 pipeline.

#### 1.2.2 ICache / DCache Port Conflicts and Banking

Port conflicts:
- Caches are usually built from SRAM macros with limited read/write ports.
- If two clients need the same physical cache port in the same cycle, one must stall, replay, arbitrate, or use another bank.
- D$ conflicts are common because loads, retired stores, MSHR fills, MSHR victim reads, flushes, and prefetches all want tag/data access.

RSD D$ implementation:
- `DCache.sv` exposes one read-side array port and one write-side array port.
- `DCacheArrayPortArbiter` arbitrates LSU read/write traffic, MSHR traffic, flush traffic, and prefetch probes.
- Loads use the read-side port; retired stores first read tags and then write data on a hit through `dataWE_OnTagHit`.
- MSHR fills and dirty victim writebacks compete with demand requests, so arbitration policy affects miss latency and demand-hit interference.

RSD I$ implementation:
- `ICache.sv` has a demand fetch path, miss handling, flush handling, and a next-line prefetch queue.
- Demand fetch has priority over queued prefetch probe/fill work.
- Because RSD has no real TLB/PTW path, I$ indexing/tagging is directly physical-address based in this design.

Banking review:
- Banking increases bandwidth by splitting arrays into independent banks.
- Bank conflicts happen when two same-cycle accesses map to the same bank.
- Common bank selects use low-order set bits or address-interleaving bits; the choice affects sequential access conflicts.
- Banking is different from associativity: associativity gives placement choices, banking gives parallel access resources.

#### 1.3 SQ lookup today (the CAM)
On every load in `D$TAG`, a **full associative CAM** runs ([StoreQueue.sv:285-294](design_and_perf/rsd_fengze/Processor/Src/LoadStoreUnit/StoreQueue.sv#L285-L294)):

```
for each load i (0..LOAD_ISSUE_WIDTH-1):
    for each SQ entry j (0..15):
        addrMatch[i][j] = sq[j].finished
                        AND sq[j].address == ToBlockAddr(load[i].addr)
                        AND (sq[j].wordWE & load[i].wordRE) != 0
                        AND (sq[j].byteWE & load[i].byteRE) != 0
```

- **16 full block-address comparators active per executed load** in the current core (`CONF_LOAD_ISSUE_WIDTH=1`, `STORE_QUEUE_ENTRY_NUM=16`). This scales as `LOAD_ISSUE_WIDTH × STORE_QUEUE_ENTRY_NUM` if the load pipe is widened later.
- No gating — every comparator is live regardless of whether a match is plausible.
- `CircularRangePicker` then selects oldest-matching store between SQ head and load's `storeQueuePtr`.

#### 1.4 Load blocking and replay today
A load that cannot complete is detected at D$TAG ([MemoryTagAccessStage.sv:493](design_and_perf/rsd_fengze/Processor/Src/Pipeline/MemoryBackEnd/MemoryTagAccessStage.sv#L493) — `ldUpdate[i] && !ldRegValid[i]`) and blocks via the **global ReplayQueue**:

| Block reason | Today's handling |
|---|---|
| D$ miss | MSHR allocated; load goes into global ReplayQueue carrying full IQ entry; replays when MSHR completes |
| SQ partial forwarding | Exec state `STORE_LOAD_FORWARDING_MISS`; **flushed and re-issued by scheduler** |
| Memory ordering violation | Flushed with memory-dep predictor training |

Problems:
- Global ReplayQueue is **shared** across int/complex/mem/FP. When it's full, **the whole core stalls** (threshold = 20 − ISSUE_QUEUE_MEM_LATENCY = 17 entries).
- Each replayed load carries a full IQ entry (operand data + active list ptr + …) — heavy.
- Replay path goes back through the scheduler, adding latency.

#### 1.4.1 Memory Dependence Prediction

Why it exists:
- OoO cores want to issue loads before all older stores have drained, but doing so blindly can violate program order when an older store later resolves to the same address.
- A memory-dependence predictor predicts which loads should wait for older stores and which can safely issue early.
- Correctness still comes from violation detection and recovery; the predictor only improves the performance/correctness tradeoff.

Generic implementation topics:
- Store-set style predictors use a table such as SSIT to map loads/stores into dependence sets and LFST to track the youngest in-flight store for each set.
- A conservative predictor blocks or delays risky loads behind unresolved older stores.
- If a load violates ordering, the core flushes/replays younger work and trains the predictor to be more conservative for that load/store pair.
- Useful counters: predicted-dependent loads, blocked cycles, false dependences, violations, replay count, and predictor-table aliasing.

RSD anchor:
- RSD already has memory-order violation detection and MDP training hooks in the LSU/recovery path.
- `LoadQueue.sv` checks store-load ordering, and memory-order violations are handled as recovery/replay events rather than silent data corruption.
- The current LRB proposal keeps MDP behavior unchanged: MDP-trained ordering violations are recovered, while LRB is only for loads waiting on data availability.

#### 1.4.2 OoO Load/Store Consistency

Rules to explain:
- Loads may execute before older stores only when the core can prove or predict that no address conflict exists.
- Stores become globally visible only after they are non-speculative, usually after commit and store-buffer drain.
- If a younger load reads before an older same-address store resolves, the violation must trigger recovery and predictor training.
- Fences, atomics, acquire/release operations, and MMIO accesses tighten ordering and may require serialization or store-buffer drain.

RISC-V review angle:
- Base RISC-V uses RVWMO, which allows more memory reordering than TSO but relies on fences and acquire/release annotations for stronger ordering.
- `FENCE` orders memory operations according to predecessor/successor masks.
- `FENCE.I` is about instruction-side visibility after data-side code writes, not normal data-memory ordering.

Performance-modeling hooks:
- Model unresolved older-store blocking separately from store-buffer-full stalls and D$ misses.
- Track memory-order replays as a distinct recovery class, because the fix may be predictor policy rather than cache size or latency.

#### 1.5 File inventory
| File | Role |
|---|---|
| `LoadStoreUnitTypes.sv` | LQ/SQ entry structs, addr/data paths, byte/word enable |
| `LoadStoreUnitIF.sv` | Modports for LQ, SQ, StoreCommitter, main LSU |
| `LoadQueue.sv` | 16-entry LQ; store→load memory-ordering check |
| `StoreQueue.sv` | Address/control metadata array + store-data RAM; 16-entry CAM for SQ→load forward |
| `StoreCommitter.sv` | Commit pipeline; retired stores → D$ |
| `LoadStoreUnit.sv` | Top-level mux + arbitration (SQ fwd / D$ / MSHR) |
| `Processor/Src/Cache/DCache.sv` | L1D tag/data pipeline, MSHR, refill, arbiter |
| `Processor/Src/Cache/DCacheSRAM.sv` | D$ SRAM wrappers |
| `Processor/Src/Cache/DCacheIF.sv` | D$ interface signals |
| `Processor/Src/Cache/CacheSystemTypes.sv` | D$ path types, MSHR types, cache parameters |

#### 1.6 Fit of proposed optimizations to current RTL

| Optimization | Current RTL fit | Notes |
|---|---|---|
| Selective SQ lookup | Good | `StoreQueue.sv` already has one local 16-entry load→store CAM; adding `ptag` is localized. |
| Load Replay Buffer | Invasive | RSD has separate LQ/SQ, but blocked loads currently route through global `ReplayQueue`; LRB needs a new capture path, replay mux, and recovery handling. |
| L1D next-line prefetcher | Medium | DCache already has MSHRs and an array arbiter, but prefetch must be a strictly lowest-priority read-side requester and low-priority MSHR allocator. |
| L1D way predictor | Medium-high | The predictor table is small, but real power savings require adding per-way tag read enables through `DCacheIF`, `DCacheArray`, and `DCacheTagSRAM_TSMC16`. |

---

### 2. Goals & Non-Goals (v1)

#### Goals
1. **Selective SQ lookup** — cut CAM power ≥ 60 % by gating the current 16 per-load SQ full comparators with a cheap partial-tag prefilter. Timing-neutral or better.
2. **Load Replay Buffer** — remove load-replay pressure from the shared ReplayQueue. Blocked loads replay directly from LSU without IQ / scheduler round-trip. Non-load pipes (int, complex, FP) stay free of LSU stalls.
3. **L1D next-line prefetch** — hide first-pass cold-miss latency on sequential load streams (arrays, memcpy, structure walks). Target IPC uplift ≈ 1–2 % on CoreMark / Dhrystone style loops.
4. **L1D way prediction** — reduce tag-array activation from 2 ways to 1 predicted way per access. Target tag-array dynamic power ≈ 50 % down at high prediction accuracy.
5. Correctness preserved — no change to memory-model semantics.

#### Non-Goals
- No change to SQ / LQ capacity (16 / 16).
- No store-to-load forwarding policy changes (still oldest-matching, full-word match required; partial → force replay).
- No speculative disambiguation (e.g. store-set predictor changes).
- No changes to StoreCommitter or retirement path.
- No changes to the memory-dependency predictor (MDT) or ReplayQueue itself.
- Global ReplayQueue remains for non-load pipes.
- No D$ capacity / associativity change (stays 2-way × 256 × 8 B = 4 KB).
- No stride or stream prefetcher in v1; next-line only.
- No prefetch buffer separate from L1D; fills go directly into normal D$ ways through the existing MSHR/refill path.
- No coherence protocol changes (RSD is single-core).

---

### 3. Optimization A — Selective Store Queue Lookup

#### 3.1 Idea

Add a **partial-tag** column alongside the SQ address array. On every load:

1. Compute load's partial tag (cheap hash of the physical block address).
2. Compare against all 16 SQ partial tags (narrow, power-cheap).
3. **Gate** the full-address comparators to fire only on partial-tag-matching entries.

Most loads see 0–2 partial-tag hits out of 16 → only those comparators and their byte/word-enable ANDs toggle.

#### 3.2 Partial-tag definition

| Param | Value | Notes |
|---|---|---|
| `SQ_PTAG_WIDTH` | 6 bits | Covers 64 distinct tags; false-positive rate ≈ 1 in 64 per entry |
| Hash | `block_addr[5:0] ^ block_addr[11:6]` | Cheap XOR fold of low/mid bits of `LSQ_ToBlockAddr(PhyAddrPath)` |

**Why not lower bits only?** Low bits alias heavily for array-walking loads. XOR-folding the mid bits spreads the tag space.

#### 3.3 SQ entry additions

```
typedef struct packed {
    // --- existing fields ---
    logic                        regValid;
    logic                        finished;
    LSQ_BlockAddrPath            address;
    LSQ_BlockWordEnablePath      wordWE;
    LSQ_WordByteEnablePath       byteWE;
    // --- new ---
    logic [SQ_PTAG_WIDTH-1:0]    ptag;           // partial-tag
} StoreQueueAddrEntry;
```

`ptag` is computed and written when the store address resolves (same cycle as existing `address` / `wordWE` write). In current RSD this widens the SQ address/control flop array, not an SRAM macro.

#### 3.4 Lookup flow (D$TAG stage, updated)

```
// Cycle C1 (combinational, in D$TAG):
load_ptag[i]     = fold_hash(load[i].addr);
for each sq entry j:
    ptag_hit[j]  = sq[j].finished && (sq[j].ptag == load_ptag[i]);

// Gated full compare — only fires for ptag-matching entries:
for each sq entry j:
    full_match[i][j] =
        ptag_hit[j]   // GATE
        && (sq[j].address == ToBlockAddr(load[i].addr))
        && ((sq[j].wordWE & load[i].wordRE) != 0)
        && ((sq[j].byteWE & load[i].byteRE) != 0);

// Oldest-match selection unchanged
```

RTL: use clock-gated or operand-isolated comparators. Under synthesis, `&&` on a known-false `ptag_hit` will let the tool power-gate the downstream compare (with explicit `if (ptag_hit[j])` guard).

#### 3.5 Correctness

- Partial-tag **never produces a false negative** (if the full address matches, the partial tag *also* matches by construction).
- False positives are harmless — the full compare catches them, and oldest-match still selects correctly.
- No semantic change; same store→load forwarding discipline.

#### 3.6 Expected impact

- **Full comparators activated per executed load**: 16 → expected `16 × P(ptag-hit)`. With P ≈ 1/64 → ≈ 0.25 full-compare activations per load on average. **≥ 95 % reduction** in full-compare switching.
- **IPC**: neutral (same result).
- **Timing**: compare path unchanged; new path is `load_ptag gen` (one XOR) + 16 × 6-bit compare — shorter than existing 16 × addr-width compare, so not critical.
- **Area**: 16 × 6 = 96 additional flops in SQ address/control metadata.

---

### 4. Optimization B — Load Replay Buffer (LRB)

#### 4.1 Idea

Add a dedicated 8-entry LRB inside LSU for blocked loads. A load that can't complete is detected at D$TAG (reusing legacy `ldUpdate && !ldRegValid` — see §1.4), captured into LRB, and re-injected at the D$ADDR request path when its block condition clears — all without touching the global ReplayQueue or the scheduler.

Non-load pipes see no pressure from load blockage.

#### 4.2 LRB entry

```
typedef struct packed {
    logic              valid;

    // Existing RSD payload needed to recreate the memory pipe state.
    // Captured from MemoryTagAccessStage's ldPipeReg/ldRecordData.
    MemIssueQueueEntry       memData;
    MemoryTagAccessStageRegPath tagStagePayload;

    // Resolved address fields; replay does not need to re-read source regs.
    PhyAddrPath        addr;
    MemoryMapType      memMapType;
    MemAccessMode      memAccessMode;
    ActiveListIndexPath alPtr;
    LoadQueueIndexPath  lqId;

    // --- why it blocked and what to wait for ---
    ReplayReason       reason;       // { MSHR_PENDING, SQ_PARTIAL_FWD, GENERIC_RETRY }
    MSHR_IndexPath     mshrId;       // valid if reason == MSHR_PENDING
    StoreQueueIndexPath sqBlockerId; // valid if reason == SQ_PARTIAL_FWD
} LRB_Entry;
```

This is intentionally closer to the existing RSD replay payload than a minimal load-only record. It reduces decode/rebuild risk because `MemoryTagAccessStage` currently records blocked loads as `MemIssueQueueEntry` for the global ReplayQueue.

**Width**: roughly one compact memory-pipe payload plus address/reason fields. Expect low-kbit flop storage for 8 entries, not a large SRAM.

#### 4.3 LRB parameters

| Param | Value | Notes |
|---|---|---|
| `LRB_ENTRY_NUM` | 8 | Power of 2 |
| `LRB_INDEX_WIDTH` | 3 | |

#### 4.4 Allocate / deallocate

| Event | Action |
|---|---|
| Load reaches D$TAG but **can't complete** (cache miss / MSHR not ready, SQ forward miss, operand-not-ready replay) | Capture into LRB (reuses legacy `ldUpdate && !ldRegValid` detection at [MemoryTagAccessStage.sv:493](design_and_perf/rsd_fengze/Processor/Src/Pipeline/MemoryBackEnd/MemoryTagAccessStage.sv#L493)); do **not** enter global ReplayQueue |
| LRB entry is granted for replay | Free that LRB entry; if the replay still cannot complete, normal D$TAG detection recaptures it |
| Recovery / flush | Walk LRB; invalidate entries whose `alPtr` is ≥ redirect point |
| LRB full + new blocked load arrives | **Stall this load in D$TAG** (single-lane stall); do not stall scheduler globally |

#### 4.5 Replay engine

Every cycle the LRB monitors clear conditions:
- `mshrValid[mshrId] && mshrPhase[mshrId] >= MSHR_PHASE_MISS_WRITE_CACHE_REQUEST` → same readiness test used by the current global ReplayQueue before replaying MSHR-backed loads.
- `SQ[sqBlockerId]` becomes executable/forwardable → requires a new `StoreQueue.sv` output because current `pickedPtr` / forward-miss blocker information is internal.
- Operand-not-ready / generic replay entries can use a conservative retry policy or stay in the global ReplayQueue in v1; memory-data waits are the primary LRB target.

When a condition clears:
1. Select the oldest (by `alPtr`) ready LRB entry.
2. Re-inject it into `D$ADDR` / `D$TAG` in the next idle load slot (arbitrated against fresh scheduler loads).

#### 4.6 Arbitration at D$ADDR

The load port accepts one of:
- Fresh load from scheduler (existing `MemoryExecutionStage` path)
- Replay from LRB

Priority: **LRB replay > scheduler load** for the single load issue lane (`CONF_LOAD_ISSUE_WIDTH=1`). Implementation is a mux around the load request and the `MemoryExecutionStage → MemoryTagAccessStage` payload so the replayed entry sees a normal D$ADDR/D$TAG/D$DATA sequence.

#### 4.7 Interaction with global ReplayQueue

Global ReplayQueue **still exists** for int / complex / FP pipes. Under macro `RSD_MARCH_LSU_LRB`, the load path stops feeding it:

- Loads enter LRB instead.
- If LRB is full, the *load* stalls — not the whole scheduler.
- Global RQ's MSHR-readiness logic remains useful as the reference policy, but the memory-load feed is gated off under the macro.

#### 4.8 Interaction with MDP (memory-dep predictor)

Memory-ordering violations still train MDP as today. After training, the offending load is invalidated (redirect from commit); it does not loop via LRB. LRB only holds loads waiting for **data** to arrive, not loads that committed misordered.

#### 4.9 Expected impact

- Loads that would have filled global ReplayQueue now sit in LRB → **fewer full-core stalls**.
- Replay path is **shorter** (no IQ round-trip). Measured as latency from MSHR-complete to load writeback:
  - Today: MSHR complete → ReplayQueue pop → scheduler select → IQ issue → D$TAG → D$DATA → D$RW = 5–7 cycles
  - With LRB: MSHR ready → LRB select → D$ADDR request → D$TAG → D$DATA → D$RW = **4 cycles**
- Expected IPC gain on memory-latency-bound loops (pointer chasing in CoreMark, Dhrystone D$ array walks): **1–2 %**.

#### 4.10 Implementation effort / risk

LRB is a **medium-to-high effort** change because RSD already has separate LQ/SQ but does **not** have an LSU-local replay injection point. The hard part is not the 8-entry buffer; it is cutting the current blocked-load path out of the global ReplayQueue cleanly.

| Item | Effort | Why |
|---|---|---|
| LRB storage + oldest-ready picker | Low | Small 8-entry flop structure; similar age comparison to other queues |
| Capture at D$TAG | Medium | Reuses `ldUpdate && !ldRegValid`, but must classify reason and preserve the existing memory-pipe payload |
| Replay injection | High | Needs a mux into the single load lane around `MemoryExecutionStage` / D$ADDR and matching payload into `MemoryTagAccessStage` |
| MSHR readiness | Low | Current ReplayQueue already uses `mshrValid` / `mshrPhase >= MSHR_PHASE_MISS_WRITE_CACHE_REQUEST` |
| SQ-forward-miss readiness | Medium | Current `StoreQueue.sv` keeps `pickedPtr` / blocker state internal; LRB needs a blocker pointer or conservative retry policy |
| Recovery/flush | Medium | LRB entries need active-list based invalidation like existing replay structures |
| Verification | High | Must prove no duplicate completion, no lost load, no MSHR leak, and no ordering regression |

Practical estimate: **1–2 weeks for a careful prototype**, **2–4 weeks to make it regression-clean** in this codebase. Selective SQ lookup is much smaller and should be landed first.

---

### 5. Optimization C — L1D Next-Line Prefetcher

#### 5.1 Idea

On every demand **load** access in D$ADDR, compute the next cache-line address and enqueue it into a small prefetch queue if simple safety gates pass. A low-priority prefetch engine drains the queue when the D$ read-side array slot is idle, probes the tag array, and allocates an MSHR only on a tag miss.

Stores do not trigger v1 prefetches. Demand load/store traffic always wins arbitration over prefetch traffic.

#### 5.2 Address generation

```
prefetch_addr = (load_addr & ~(DCACHE_LINE_BYTE_NUM - 1)) + DCACHE_LINE_BYTE_NUM
              = (load_addr & ~7)                         + 8
```

Target: the block immediately after the demand block. This is intentionally simple and useful for RSD's tiny 8-byte line size.

#### 5.3 Gating

Drop the prefetch if any condition is true:

| Condition | Reason |
|---|---|
| Access is a store | Avoid bandwidth waste on write-only streams |
| Demand access is uncachable / non-memory | Do not prefetch MMIO or illegal regions |
| MSHR already has an in-flight fill for this line | Already being fetched |
| Both MSHRs busy | Demand must be protected |
| Prefetch queue full | No back-pressure into demand path |
| Load itself missed and this would alias its own MSHR | Avoid duplicate fill |

#### 5.4 Structures

```
typedef struct packed {
    logic              valid;
    PhyAddrPath        addr;       // line-aligned
} DC_PrefetchQueueEntry;

DC_PrefetchQueueEntry dc_prefetch_queue [DC_PREFETCH_QUEUE_DEPTH];
```

| Param | Value | Notes |
|---|---|---|
| `DC_PREFETCH_QUEUE_DEPTH` | 2 | Symmetric with the frontend next-line prefetch queue |

#### 5.5 Prefetch engine behavior

Every cycle:

1. If queue not empty, D$ read-side slot idle, and engine not busy:
   - Pop or reserve the head entry.
   - Issue a low-priority tag probe at `addr`.
2. In D$TAG for the prefetch probe:
   - Tag hit → drop; line already exists.
   - Tag miss + free MSHR → allocate MSHR with `prefetch_flag = 1`.
   - Tag miss + no free MSHR → drop or keep in queue; v1 default is drop to protect demand.
3. Prefetch MSHR fills through the normal cache refill path. The prefetched line is indistinguishable from a demand-filled line once installed; `prefetch_flag` lives only in the MSHR for accounting/priority.

#### 5.6 MSHR priority

Prefetch is inserted below the existing LSU/MSHR read-side arbitration in `DCacheArrayPortArbiter`:

```
existing LSU/MSHR traffic > prefetch tag probe > prefetch MSHR alloc
```

Prefetch must never block a demand access. If all MSHRs are busy, the prefetch is dropped or waits in the prefetch queue depending on final policy; v1 default is no reclaim/cancel machinery.

#### 5.7 Expected impact

- Sequential data streams: Dhrystone string ops, CoreMark matrix/list walks, Embench memcpy-like kernels.
- With 8-byte D$ lines, sequential loads cross lines frequently, so next-line prefetch can cover a meaningful fraction of miss latency.
- Estimated IPC gain: **+1 % to +2.5 %** depending on MSHR saturation and memory latency.

#### 5.8 Beyond Next-Line Prefetching

Next-line is a good first implementation because it is simple and low-risk, but interview discussion should include the broader design space:

- Stride prefetcher: detects fixed address deltas per PC; useful for array walks with regular strides.
- Stream prefetcher: detects consecutive cache-line streams and can prefetch multiple lines ahead.
- Spatial/region prefetcher: predicts nearby lines within a page or region after observing access patterns.
- Correlation prefetcher: learns address sequences that are not simple strides.
- Pointer-chase prefetcher: follows dependent load chains, but is harder because the next address is data-dependent.
- Runahead-style execution: uses speculative execution past a long miss to discover future misses.

Key metrics:
- Accuracy: fraction of prefetches that are later used.
- Coverage: fraction of demand misses eliminated by prefetching.
- Timeliness: whether the prefetched line arrives before demand.
- Pollution: useful lines evicted by prefetches.
- Bandwidth/MSHR pressure: demand traffic must keep priority.

RSD fit:
- RSD currently has only two D$ MSHRs, so aggressive prefetching can easily hurt demand misses.
- Any extension beyond next-line should include throttling based on MSHR occupancy, prefetch usefulness, and demand-miss interference.

---

### 6. Optimization D — L1D Way Predictor

#### 6.1 Idea

Current RSD instantiates one tag SRAM wrapper per way, but every read-side access presents the same read address to every way and the `DCacheTagSRAM_TSMC16` wrapper currently has no read-enable input. A 2-way cache only needs a 1-bit way prediction. In D$ADDR, read a small set-indexed prediction table and activate only the predicted way's tag SRAM in D$TAG. If the predicted way misses but the other way would hit, retry the other way in the next cycle and update the predictor.

Prediction is not architecturally visible. It only controls tag-SRAM activation and a 1-cycle retry path.

#### 6.2 Prediction table

```
logic [0:0] dc_way_pred_table [DCACHE_INDEX_NUM];  // 256 bits total = 32 B in current 2-way config
```

| Param | Value | Notes |
|---|---|---|
| `DC_WAY_PRED_ENTRY_NUM` | 256 | = D$ set count |
| `DC_WAY_PRED_BIT` | 1 | `$clog2(DCACHE_WAY_NUM)` for 2-way |
| Storage | 32 bytes | Flops; too small to justify SRAM |

#### 6.3 Access flow

```
// D$ADDR
set_idx  = addr[IDX_HI:IDX_LO];
pred_way = dc_way_pred_table[set_idx];
tagArrayReadEnable[pred_way][READ_PORT] = 1;  // only predicted way fires

// D$TAG
pred_hit = tag_out[pred_way_r].valid &&
           tag_out[pred_way_r].tag == addr_tag_r;

if (pred_hit) {
    hit_way = pred_way_r;
    proceed to D$DATA;
}
else if (!already_retried) {
    retry_other_way_next_cycle = 1;
}
else if (other_hit) {
    hit_way = ~pred_way_r;
    dc_way_pred_table[set_idx] <= ~pred_way_r;
}
else {
    true_miss = 1;             // normal MSHR path
}
```

Implementation note for current RSD: this is not only a predictor-table change. It also requires adding per-way tag read enables through `DCacheIF`, `DCacheArray`, and `DCacheTagSRAM_TSMC16` (`REB` is currently tied low). Generic `BlockDualPortRAM` simulation can keep functional reads from both ways, but the synthesis path needs real `tag_rd_en[way]` gating to realize the power benefit.

#### 6.4 Predictor update

| Event | Update |
|---|---|
| Hit on predicted way | No update |
| Hit on other way after retry | `table[set_idx] <= ~pred_way` |
| Miss fill into way `w` | `table[set_idx] <= w` |

Reset initializes the table to way 0.

#### 6.5 Timing / power impact

- **Power**: tag SRAM activation 2 → 1 per access after per-way read-enable plumbing, so tag-array dynamic power can drop by roughly 50 % when prediction is correct.
- **Timing**: table lookup is a small set-indexed flop array in D$ADDR.
- **IPC**: small negative on way mispredicts. At 95 % accuracy, penalty is roughly 1 cycle × 5 % of D$ accesses, usually negligible.

#### 6.6 Correctness

- If prediction is wrong, the retry path checks the other way before declaring a true miss.
- No memory-ordering, store-forwarding, or coherence semantic changes.
- Way prediction only changes which tag SRAM toggles first.

---

### 7. Unified Module & Interface Changes

#### 7.1 New files
| File | Role |
|---|---|
| `Processor/Src/LoadStoreUnit/LoadReplayBuffer.sv` | LRB ring buffer + replay engine |
| `Processor/Src/LoadStoreUnit/LoadReplayBufferIF.sv` | Interface |
| `Processor/Src/Cache/DCachePrefetcher.sv` | PrefetchQueue + PrefetchEngine + tag-probe arbitration for demand-idle cycles |
| `Processor/Src/Cache/DCachePrefetcherIF.sv` | Prefetcher ↔ DCache interface |
| `Processor/Src/Cache/DCacheWayPredictor.sv` | 256-entry prediction table + lookup + update engine |
| `Processor/Src/Cache/DCacheWayPredictorIF.sv` | WayPredictor ↔ DCache interface |

#### 7.2 Modified files
| File | Change |
|---|---|
| `Processor/Src/LoadStoreUnit/LoadStoreUnitTypes.sv` | Add `ptag` to `StoreQueueAddrEntry`; add `LRB_Entry`, `ReplayReason` |
| `Processor/Src/LoadStoreUnit/StoreQueue.sv` | Compute + store `ptag` on SQ write; gate full CAM with `ptag_hit`; optionally expose SQ forward-miss blocker pointer |
| `Processor/Src/Pipeline/MemoryBackEnd/MemoryExecutionStage.sv` | Add LRB replay mux before the D$ADDR load request / next-stage payload |
| `Processor/Src/LoadStoreUnit/LoadStoreUnitIF.sv` | Signals: `lrb_replay_valid`, `lrb_replay_entry`, `lrb_full`, replay/capture sideband |
| `Processor/Src/Pipeline/MemoryBackEnd/MemoryTagAccessStage.sv` | Route block condition → LRB capture (reuses legacy `ldUpdate && !ldRegValid` hook at line 493) |
| `Processor/Src/Scheduler/ReplayQueue.sv` | Under `RSD_MARCH_LSU_LRB`, stop taking load entries |
| `Processor/Src/Cache/DCache.sv` | Add low-priority prefetch probes/MSHR alloc; add way-pred lookup, single-way tag enable, and other-way retry |
| `Processor/Src/Cache/DCacheSRAM.sv` | Under way predictor: add scalar `tag_rd_en` to each per-way tag SRAM wrapper |
| `Processor/Src/Cache/DCacheIF.sv` | Add prefetch probe interface and way predictor signals |
| `Processor/Src/Cache/CacheSystemTypes.sv` | Add `DC_PrefetchQueueEntry`, `UpdateReason`, and `prefetch_flag` in MSHR entry |
| `Processor/Src/SynthesisMacros.sv` | Add four gate macros |
| `Processor/Src/MicroArchConf.sv` | Add LSU/L1D optimization parameters listed in §9.1 |

#### 7.3 New interfaces

##### 7.3.1 `LoadReplayBufferIF`

Full interface contract for Optimization B (LRB). Optimization A (selective SQ) is local to `StoreQueue.sv` and does not require a new interface.

```systemverilog
interface LoadReplayBufferIF(input logic clk, rst);

    // === LSU → LRB : capture a blocked load =================================
    logic                          captureValid;   // a load cannot complete
    LRB_Entry                      captureEntry;   // full context (see §4.2)
    logic                          lrbFull;        // back-pressure to LSU

    // === LRB → LSU : ready-to-replay signalling =============================
    logic                          replayValid;    // LRB has a ready entry
    LRB_Entry                      replayEntry;
    logic [LRB_INDEX_WIDTH-1:0]    replayId;       // pointer into LRB
    logic                          replayGranted;  // LSU arbiter granted this replay

    // === Watcher inputs (completion events that wake LRB entries) ===========
    logic [DCACHE_MSHR_NUM-1:0]                mshrValid;
    MSHR_Phase                                 mshrPhase[DCACHE_MSHR_NUM];
    logic [STORE_QUEUE_ENTRY_NUM-1:0]          sqBlockerReady; // new StoreQueue sideband
    logic                                      genericRetryTick;

    // === Recovery ===========================================================
    logic                          redirValid;     // pipeline flush / redirect
    ActiveListIndexPath            redirAlPtr;     // oldest surviving instruction

    // === Modports ===========================================================
    modport LSU (
        output captureValid, captureEntry,
               replayGranted,
        input  lrbFull,
               replayValid, replayEntry, replayId
    );

    modport LRB (
        input  captureValid, captureEntry,
               replayGranted,
               mshrValid, mshrPhase, sqBlockerReady, genericRetryTick,
               redirValid,  redirAlPtr,
        output lrbFull,
               replayValid, replayEntry, replayId
    );

    modport MSHR   (output mshrValid, mshrPhase);
    modport SQ     (output sqBlockerReady);
    modport Recov  (output redirValid, redirAlPtr);
endinterface
```

**Signal → diagram mapping** (see §0):
- `captureValid`, `captureEntry` ← orange "capture" arrow from D$TAG to LRB block
- `replayValid`, `replayEntry`, `replayGranted` ← green "replay" arrow wrapping from LRB back to D$ADDR
- `mshrValid/mshrPhase`, `sqBlockerReady`, `genericRetryTick` ← "Watchers + Replay Engine" block inside LRB
- `redirValid`, `redirAlPtr` ← "Recovery Walker" block inside LRB

##### 7.3.2 `DCachePrefetcherIF`

```systemverilog
interface DCachePrefetcherIF(input logic clk, rst);
    // LSU/D$ demand side -> prefetcher
    logic                     demandValid;
    PhyAddrPath               demandAddr;
    logic                     demandIsStore;

    // Prefetcher -> DCache low-priority tag probe
    logic                     prefProbeValid;
    PhyAddrPath               prefProbeAddr;
    logic                     prefProbeGranted;
    logic                     prefProbeHit;
    logic                     prefProbeMiss;

    // Prefetcher -> MSHR low-priority allocation
    logic                     prefMshrAllocReq;
    PhyAddrPath               prefMshrAllocAddr;
    logic                     prefMshrAllocGranted;

    // DCache/MSHR status back to prefetcher
    logic [DCACHE_MSHR_NUM-1:0] mshrBusy;
    logic [DCACHE_MSHR_NUM-1:0] mshrSameLinePending;
endinterface
```

##### 7.3.3 `DCacheWayPredictorIF`

```systemverilog
interface DCacheWayPredictorIF(input logic clk, rst);
    logic                              lookupValid;
    logic [DCACHE_INDEX_BIT_WIDTH-1:0] lookupSetIdx;
    logic [CONF_DC_WAY_PRED_BIT-1:0]   predWay;

    logic                              updateValid;
    logic [DCACHE_INDEX_BIT_WIDTH-1:0] updateSetIdx;
    logic [CONF_DC_WAY_PRED_BIT-1:0]   updateWay;
    UpdateReason                       updateReason; // {HIT_OTHER_WAY, MSHR_FILL}
endinterface
```

#### 7.4 Modified Types

| Type | File | Change |
|---|---|---|
| `StoreQueueAddrEntry` | `LoadStoreUnitTypes.sv` | add `logic [SQ_PTAG_WIDTH-1:0] ptag` (under `RSD_MARCH_LSU_SEL_SQ`) |
| `LRB_Entry`          | `LoadStoreUnitTypes.sv` | **new** (under `RSD_MARCH_LSU_LRB`) — see §4.2 |
| `ReplayReason` enum  | `LoadStoreUnitTypes.sv` | **new** — `{MSHR_PENDING, SQ_PARTIAL_FWD, GENERIC_RETRY}` |
| `DC_PrefetchQueueEntry` | `CacheSystemTypes.sv` | **new** — `{valid, addr}` |
| `UpdateReason` enum | `CacheSystemTypes.sv` | **new** — `{HIT_OTHER_WAY, MSHR_FILL}` |
| `MissStatusHandlingRegister` | `CacheSystemTypes.sv` | add `logic prefetch_flag` under `RSD_MARCH_DC_PREFETCH` |
| D$ tag read port | `DCacheIF.sv` / `DCacheSRAM.sv` | under `RSD_MARCH_DC_WAYPRED`, add per-way read enables |
| `ReplayQueueEntry`   | `Scheduler/ReplayQueue.sv` | unchanged structurally, but load-feed path disabled under `RSD_MARCH_LSU_LRB` (see Step 6) |
| (params)             | `MicroArchConf.sv`       | add LSU/L1D params listed in §9.1 |
| (macros)             | `SynthesisMacros.sv`     | add `RSD_MARCH_LSU_SEL_SQ`, `RSD_MARCH_LSU_LRB`, `RSD_MARCH_DC_PREFETCH`, `RSD_MARCH_DC_WAYPRED` |

---

### 8. RTL Implementation Plan

All steps compile and regress under every macro combination. A (selective SQ), B (LRB), C (D$ prefetch), and D (D$ way predictor) are orthogonal — land them independently.

LSU configs:

| Config | `RSD_MARCH_LSU_SEL_SQ` | `RSD_MARCH_LSU_LRB` | Meaning |
|---|---|---|---|
| A0 | 0 | 0 | Baseline (today's RSD). Must keep working. |
| A1 | 1 | 0 | Selective SQ only. |
| A2 | 0 | 1 | LRB only. |
| A3 | 1 | 1 | Both LSU optimizations. |

L1D configs:

| Config | `RSD_MARCH_DC_PREFETCH` | `RSD_MARCH_DC_WAYPRED` | Meaning |
|---|---|---|---|
| B0 | 0 | 0 | Baseline D$. Must keep working. |
| B1 | 1 | 0 | D$ next-line prefetch only. |
| B2 | 0 | 1 | D$ way predictor only. |
| B3 | 1 | 1 | Both L1D optimizations. |

#### Step 1 — Types, params, macros
**Goal**: add new types and config; no behavior change; all listed LSU/L1D configs compile.

**Actions**
- `SynthesisMacros.sv` — add `RSD_MARCH_LSU_SEL_SQ`, `RSD_MARCH_LSU_LRB`, `RSD_MARCH_DC_PREFETCH`, `RSD_MARCH_DC_WAYPRED` (default undefined).
- `MicroArchConf.sv` — add
  ```
  localparam CONF_SQ_PTAG_WIDTH  = 6;
  localparam CONF_LRB_ENTRY_NUM  = 8;
  localparam CONF_LRB_INDEX_WIDTH = $clog2(CONF_LRB_ENTRY_NUM);
  localparam CONF_DC_PREFETCH_QUEUE_DEPTH = 2;
  localparam CONF_DC_WAY_PRED_ENTRY_NUM   = 256;
  localparam CONF_DC_WAY_PRED_BIT         = $clog2(CONF_DCACHE_WAY_NUM);
  ```
- `LoadStoreUnitTypes.sv`:
  - Add `typedef logic [CONF_SQ_PTAG_WIDTH-1:0] SQ_PTagPath;`
  - Under `RSD_MARCH_LSU_SEL_SQ`: extend `StoreQueueAddrEntry` with `SQ_PTagPath ptag`.
  - Under `RSD_MARCH_LSU_LRB`: define `ReplayReason` enum and `LRB_Entry` struct per §4.2.
- `CacheSystemTypes.sv`:
  - Add `DC_PrefetchQueueEntry`, `UpdateReason`.
  - Under `RSD_MARCH_DC_PREFETCH`: add `prefetch_flag` to `MissStatusHandlingRegister`.

**Regression**: `A0` and `B0` bit-identical to current master (no RTL touched).

#### Step 2 — Selective SQ CAM (Optimization A)
**Goal**: gate the current 16 full block-address comparators per load with a cheap 16 × 6-bit partial-tag filter.

**File: `StoreQueue.sv`** — under `RSD_MARCH_LSU_SEL_SQ`:

*New logic*
- Compute store's `ptag` on SQ write:
  ```
  function SQ_PTagPath foldPTag(LSQ_BlockAddrPath a);
      return a[5:0] ^ a[11:6];   // see §3.2
  endfunction
  ```
- On SQ execute/update: `storeQueue[idx].ptag <= foldPTag(executedStoreAddr);`
- On load lookup (D$TAG stage):
  ```
  load_ptag[i] = foldPTag(LSQ_ToBlockAddr(port.executedLoadAddr[i]));
  for j in 0..15:
      ptag_hit[i][j] = storeQueue[j].finished
                       && (storeQueue[j].ptag == load_ptag[i]);
  for j in 0..15:
      addrMatch[i][j] = ptag_hit[i][j] && <existing full compare>;
  ```

*New registers*: 16 × 6 ptag flops in the existing SQ address/control metadata array.

*SVA*
```
// partial tag is a necessary condition for a real match
for (genvar i = 0; i < LOAD_ISSUE_WIDTH; i++) begin
  for (genvar j = 0; j < STORE_QUEUE_ENTRY_NUM; j++) begin
    assert property(@(posedge clk)
      (addrMatch[i][j]) |-> (ptag_hit[i][j]));
  end
end
```

*Regression (A0 vs A1)*: identical architectural state on every test. Perf counter `sq_full_cam_fire` should be ≥ 10× lower on A1 vs A0.

#### Step 3 — LRB module skeleton (Optimization B, compile-only)
**Goal**: add `LoadReplayBuffer.sv` + `LoadReplayBufferIF.sv`. No capture or replay yet.

**New file: `LoadReplayBufferIF.sv`** — per §7.3.1.

**New file: `LoadReplayBuffer.sv`** — skeleton:
```
module LoadReplayBuffer(
    LoadReplayBufferIF.LRB port,
    input logic clk, rst
);
    LRB_Entry  entries [CONF_LRB_ENTRY_NUM];
    logic      valid   [CONF_LRB_ENTRY_NUM];

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < CONF_LRB_ENTRY_NUM; i++)
                valid[i] <= 0;
        end
        // TODO: capture, replay, watchers, recovery
    end

    // Stub outputs — safe defaults
    assign port.lrbFull      = 0;
    assign port.replayValid  = 0;
    assign port.replayEntry  = '0;
    assign port.replayId     = 0;
endmodule
```

**Integration stub**: `Core.sv` instantiates LRB under `RSD_MARCH_LSU_LRB` and passes `LoadReplayBufferIF` modports; no wiring of captureValid / replayGranted yet.

**Regression**: A0 and A2 must compile; behaviorally identical to A0 since LRB does nothing.

#### Step 4 — LRB core logic: capture + recovery
**Goal**: accept captures; track entries; walk on redirect. Still no replay.

**In `LoadReplayBuffer.sv`**:
- Allocation: on `captureValid && !lrbFull`, write `captureEntry` into first-free slot; set `valid[slot]=1`.
- `lrbFull` combinational = (all `valid` set).
- Recovery walker:
  ```
  for i in 0..N-1:
      if valid[i] && redirValid && isOlderOrEqual(redirAlPtr, entries[i].alPtr):
          valid[i] <= 0;  // squash newer entries
  ```

**In `MemoryTagAccessStage.sv`** — under macro, hook into the existing `ldUpdate[i] && !ldRegValid[i]` detection at line 493 (today's ReplayQueue trigger):
- Detect block condition using existing D$TAG signals: `dcReadHit`, `mshrReadHit`, `loadHasAllocatedMSHR/loadMSHRID`, `mshrAddrHit/mshrAddrHitMSHRID`, `storeLoadForwarded`, and `forwardMiss`.
- Pack `LRB_Entry` from `ldPipeReg[i]` / `ldRecordData[i]` plus resolved `phyAddrOut` and reason.
- Drive `lrbIF.captureValid = block_condition;` and `lrbIF.captureEntry = packed;`.
- **Under macro**: do NOT feed this load into the global ReplayQueue (the existing replay-enq path is gated off).

*SVA*
```
assert property(@(posedge clk) (lrbIF.captureValid && !lrbIF.lrbFull)
                               |=> valid[<allocated_idx>]);
assert property(@(posedge clk) !(lrbIF.captureValid && lrbIF.lrbFull));
// full LRB: load must stall in D$TAG (no capture, no progress)
```

*Regression (A0 vs A2)*: identical architectural state. Perf counter: `lrb_capture_count` should be > 0 on load-miss-heavy tests.

#### Step 5 — LRB replay engine + D$ADDR arbitration
**Goal**: LRB entries wake on their watch events and replay into D$ADDR, preempting fresh scheduler loads.

**In `LoadReplayBuffer.sv`**:
- Ready mask per entry:
  ```
  ready[i] = valid[i] &&
             ((entries[i].reason == MSHR_PENDING &&
               mshrValid[entries[i].mshrId] &&
               mshrPhase[entries[i].mshrId] >= MSHR_PHASE_MISS_WRITE_CACHE_REQUEST)
           || (entries[i].reason == SQ_PARTIAL_FWD &&
               sqBlockerReady[entries[i].sqBlockerId])
           || (entries[i].reason == GENERIC_RETRY &&
               genericRetryTick));
  ```
- Pick oldest ready (by `alPtr`):
  ```
  replayId_comb  = oldestReady(ready, entries[].alPtr);
  replayValid    = |ready;
  replayEntry    = entries[replayId_comb];
  ```
- On `replayGranted`: `valid[replayId] <= 0;`.

**In `MemoryExecutionStage.sv` D$ADDR driver**:
- Mux the single load lane before `loadStoreUnit.dcReadReq/dcReadAddr` and before `port.nextStage` is written toward `MemoryTagAccessStage`:
  ```
  if (lrbIF.replayValid):
      dcReadReq   = 1;
      dcReadAddr  = lrbIF.replayEntry.addr;
      nextStage   = lrbIF.replayEntry.tagStagePayload;
      lrbIF.replayGranted = 1;
  else:
      use existing scheduler-issued load path;
  ```
- Priority: LRB > scheduler. Scheduler load is held (stall at IQ) when LRB replays.

*Combinational only*. No new FSM.

*SVA*
```
// replay entry must actually have been captured earlier
assert property(@(posedge clk) lrbIF.replayGranted |-> lrbIF.replayValid);
// once granted, the slot frees next cycle
assert property(@(posedge clk) lrbIF.replayGranted |=> !valid[$past(lrbIF.replayId)]);
```

*Regression (A2)*: IPC ≥ A0 on memory-latency-bound loops (expect +1–2 %).

#### Step 6 — Decouple global ReplayQueue load feed
**Goal**: under `RSD_MARCH_LSU_LRB`, no load enters the global `ReplayQueue` any more.

**In `Scheduler/ReplayQueue.sv`** — guard load-enqueue logic:
```
`ifdef RSD_MARCH_LSU_LRB
    assign enqLoadValid = 0;                // load-feed path disabled
`else
    // legacy load feed (unchanged)
`endif
```

Non-load pipes (int / complex / FP) still feed the global RQ as before.

*SVA*: `assert (!enqLoadValid)` under macro (functional assertion — there should never be a load-enq under A2/A3).

#### Step 7 — D$ prefetcher skeleton and body (Optimization C)
**Goal**: add the D$ next-line prefetcher and integrate it as a low-priority requester.

**New files**
- `DCachePrefetcherIF.sv` — per §7.3.2.
- `DCachePrefetcher.sv`:
  ```
  module DCachePrefetcher(DCachePrefetcherIF.Prefetcher port, input logic clk, rst);
      DC_PrefetchQueueEntry queue [CONF_DC_PREFETCH_QUEUE_DEPTH];
      // addr generation, queue management, engine
  endmodule
  ```

**In `DCachePrefetcher.sv`**
```
prefetch_addr = (demandAddr & ~(DCACHE_LINE_BYTE_NUM - 1)) + DCACHE_LINE_BYTE_NUM;
drop = demandIsStore
    || demandIsUncachable
    || demandIsNonMemory
    || |mshrSameLinePending
    || &mshrBusy
    || queueFull;
```

**In `DCache.sv`**
- `DCacheArrayPortArbiter` gains one lowest-priority read-side requester: prefetch probe. Existing LSU/MSHR arbitration remains above prefetch.
- MSHR alloc arbiter gains one requester: prefetch miss. Priority: demand miss > prefetch miss.
- On prefetch MSHR allocation: `mshr[i].prefetch_flag = 1`.

*SVA*
```
assert property(@(posedge clk) (demandAccess && prefProbeValid) |-> !prefProbeGranted);
assert property(@(posedge clk) prefMshrAllocGranted |-> (|~mshrBusy));
```

*Regression (B1)*: architectural state matches B0; collect `dc_prefetch_issued`, `dc_prefetch_hit`, `dc_prefetch_useful`.

#### Step 8 — D$ way predictor skeleton (Optimization D, compile-only)
**Goal**: add predictor table and interface; no behavior change yet.

**New files**
- `DCacheWayPredictorIF.sv` — per §7.3.3.
- `DCacheWayPredictor.sv`:
  ```
  module DCacheWayPredictor(DCacheWayPredictorIF.Predictor port, input logic clk, rst);
      logic [CONF_DC_WAY_PRED_BIT-1:0] table [CONF_DC_WAY_PRED_ENTRY_NUM];
      always_ff @(posedge clk) begin
          if (rst)
              for (int i = 0; i < CONF_DC_WAY_PRED_ENTRY_NUM; i++) table[i] <= 0;
          else if (port.updateValid)
              table[port.updateSetIdx] <= port.updateWay;
      end
      assign port.predWay = table[port.lookupSetIdx];
  endmodule
  ```

**In `DCache.sv`**
- Drive `lookupValid`, `lookupSetIdx` from D$ADDR.
- Consume `predWay`, but still read both tag ways for this step.
- Add `predWay` / `predWayReg` sideband in `DCacheArrayPortMultiplexer` so D$TAG knows which way was predicted for the read-side request.

*Regression (B2 skeleton)*: bit-identical to B0.

#### Step 9 — D$ single-way tag enable + other-way retry
**Goal**: activate only predicted way's tag SRAM, recover on misprediction.

**In `DCacheSRAM.sv`**
```
`ifdef RSD_MARCH_DC_WAYPRED
    input logic tag_rd_en;      // scalar because DCache instantiates one tag SRAM wrapper per way
`else
    // legacy wrapper: read always enabled
`endif
```

**In `DCacheIF.sv` / `DCacheArray` D$ADDR**
```
tagArrayReadEnable[way][READ_PORT] = (way == predWay);
```

**In `DCache.sv` D$TAG**
```
pred_hit = tag_out[pred_way_r].valid &&
           tag_out[pred_way_r].tag == addr_tag_r;

if (pred_hit) {
    hit_way = pred_way_r;
}
else if (!already_retried) {
    retry_state = RETRYING;
    tagArrayReadEnable[~pred_way_r][READ_PORT] = 1;  // next cycle
}
else if (other_hit) {
    hit_way = ~pred_way_r;
    wayPredIF.updateValid  = 1;
    wayPredIF.updateSetIdx = set_idx_r;
    wayPredIF.updateWay    = ~pred_way_r;
}
else {
    true_miss = 1;
}
```

On MSHR fill, update predictor with the fill way.

*SVA*
```
assert property(@(posedge clk) hit |-> (tag_out[hit_way].tag == addr_tag_r));
assert property(@(posedge clk) (retry_state == RETRYING) |=> (retry_state != RETRYING));
assert property(@(posedge clk) $onehot0(tagArrayReadEnable[:, READ_PORT]) || retry_state == RETRYING);
```

#### Step 10 — D$ macro feasibility check
Before enabling Step 9 as the default path, confirm the TSMC16 tag macro wrapper exposes a real read enable. Current `DCacheTagSRAM_TSMC16` instantiates one wrapper per way, but ties macro `REB` low. The way predictor should plumb `tag_rd_en` to `REB = !tag_rd_en`; otherwise the predictor is functionally correct but has little SRAM-level power benefit.

#### Step 11 — Unified regress & measure
**Unit tests**: all LSU configs (A0/A1/A2/A3), L1D configs (B0/B1/B2/B3), and combined configs produce bit-identical final architectural state on the RSD regression suite.

**Benchmarks**: Dhrystone / CoreMark / Embench. Record in §9.4:
- IPC per config
- `sq_full_cam_fire` / `sq_cam_activation_rate` (confirms A savings)
- `lrb_capture_count`, `lrb_replay_latency_avg`, `replay_queue_load_enq_count` (confirms B works + displaces global RQ)
- `core_stall_rq_full` (should go to zero on A2 / A3 for load-caused stalls)
- `dc_prefetch_issued`, `dc_prefetch_useful`, MSHR occupancy (confirms C works without starving demand)
- `dc_waypred_accuracy`, tag-SRAM activations/cycle (confirms D power benefit)

---

### 9. Scope, Parameters, Open Questions

#### 9.1 Parameters
| Param | Value | Notes |
|---|---|---|
| `CONF_SQ_PTAG_WIDTH` | 6 | Bits per partial tag; width chosen for ≈ 1/64 false-positive rate |
| `CONF_LRB_ENTRY_NUM` | 8 | Per-load replay capacity |
| `CONF_LRB_INDEX_WIDTH` | 3 | = `$clog2(CONF_LRB_ENTRY_NUM)` |
| `CONF_DC_PREFETCH_QUEUE_DEPTH` | 2 | L1D next-line prefetch queue |
| `CONF_DC_WAY_PRED_ENTRY_NUM` | 256 | One prediction entry per D$ set |
| `CONF_DC_WAY_PRED_BIT` | 1 | 2-way cache |
| `DCACHE_LINE_BYTE_NUM` | 8 | Unchanged |
| `DCACHE_WAY_NUM` | 2 | Unchanged |
| `DCACHE_MSHR_NUM` | 2 | Unchanged |
| `LOAD_ISSUE_WIDTH` | 1 | Unchanged |
| `STORE_QUEUE_ENTRY_NUM` | 16 | Unchanged |
| `LOAD_QUEUE_ENTRY_NUM` | 16 | Unchanged |

#### 9.2 Deferred
- Store-set predictor / speculative load-store disambiguation (v1.1 candidate).
- Partial store-to-load forwarding (today: full-word required; partial → replay).
- Multi-bank SQ for higher load issue width.
- Stride / stream prefetcher for L1D (v1.1 candidate).
- PC-indexed way predictor; v1 uses set-indexed table.
- Prefetch confidence/throttling and prefetch MSHR reclaim.

#### 9.3 Open Questions (sign-off before RTL)
- [ ] **Q1 — Partial-tag width**: 6 vs 8 bits? 8 gives 1/256 false positive but adds 32 flops. Default **6**.
- [ ] **Q2 — Partial-tag hash**: XOR-fold of `addr[11:0]`? Or include bits from pc? Default **addr-only**, two-level XOR fold.
- [ ] **Q3 — LRB capacity**: 4 / 8 / 16? Sized against LQ=16 and MSHR=2. Default **8** — covers the common case of 2 in-flight misses + a few SQ-partial stalls.
- [ ] **Q4 — Replay priority**: LRB > scheduler at D$ADDR by default. Should stores ever preempt? Spec default: **no, loads in LRB win; stores continue as today via StoreCommitter**.
- [ ] **Q5 — Full-LRB handling**: stall load in D$TAG (current spec) or spill into global ReplayQueue as a fallback? Default **stall** — simpler, keeps cores clean; measure whether spill is needed.
- [ ] **Q6 — Recovery cost**: walking 8 LRB entries each cycle on redirect is cheap; no open issue.
- [ ] **Q7 — D$ prefetch stores?** v1 says no; measure store-miss-prefetch only if store streams are a bottleneck.
- [ ] **Q8 — D$ prefetch MSHR reclaim**: v1 says no reclaim; revisit if demand misses starve behind prefetch fills.
- [ ] **Q9 — D$ way predictor SRAM feasibility**: confirm per-way tag SRAM enable. If ways are physically packed, power savings drop to logic gating only.
- [ ] **Q10 — D$ way predictor indexing**: set-indexed by default. PC+set indexing may improve accuracy at area cost.

#### 9.4 Measured results (filled post-implementation)
| Benchmark | Baseline IPC | +SelSQ | +LRB | +D$PF | +WayPred | All on | CAM activity Δ | D$ prefetch useful | WayPred accuracy |
|---|---|---|---|---|---|---|---|---|---|
| Dhrystone | | | | | | | | | |
| CoreMark | | | | | | | | | |
| Embench | | | | | | | | | |

---

**Sign-off gate**: §3.2 (partial-tag hash), §4.2 (LRB entry), §4.4 (full-LRB policy), §5.3 (prefetch gates), §6.3 (way-pred retry), §9.3 open questions.

## Part 5 — Branch Predictor Microarchitecture

This section complements the decoupled frontend spec. The frontend section explains the implemented RSD dataflow; this section is the interview review checklist for branch prediction concepts and model knobs.

### 1. What a Branch Predictor Predicts

Direction:
- Conditional branch taken / not taken.
- Structures: bimodal counters, local history, global history, gshare, tournament, TAGE, perceptron-like predictors.

Target:
- BTB predicts the target PC for taken branches and jumps.
- Return address stack predicts function returns.
- Indirect predictor handles indirect jumps with many possible targets.

Fetch-block metadata:
- Which lane in the fetch packet is the first taken branch.
- Where the fetch block ends.
- What history snapshot must be restored on misprediction.

### 2. RSD Implementation Anchor

RSD decoupled frontend uses:
- `DecoupledBPU.sv` with BTB + PHT + global-history indexing.
- `CONF_BTB_ENTRY_NUM = 1024`.
- `CONF_PHT_ENTRY_NUM = 2048`.
- `CONF_BRANCH_GLOBAL_HISTORY_BIT_WIDTH = 10`.
- A gshare-style PHT index: PC index bits XORed with global history.
- FTQ entries that carry prediction metadata, GHR snapshots, PHT index/value, branch offset, predicted target, and lane predictions.
- Predictor update from resolved branch metadata through the FTQ update path.

What RSD does not currently model:
- RAS.
- TAGE / tournament predictor.
- Indirect branch target predictor.
- Multi-level BTB hierarchy.

### 3. Prediction Flow

1. Use fetch PC to read BTB and PHT.
2. Match BTB tag for each fetch lane.
3. Use PHT counter MSB as taken/not-taken direction for BTB-hit lanes.
4. Pick the first predicted-taken lane in the fetch block.
5. Set predicted next PC to BTB target if taken, otherwise fall-through fetch end.
6. Enqueue prediction metadata into FTQ.
7. Speculatively update global history for predicted conditional branches.
8. On resolution, update BTB/PHT and restore/update global history if the speculation was wrong.

### 4. Performance-Modeling Knobs

- Direction accuracy by branch class.
- BTB capacity, associativity, tag width, and aliasing.
- PHT size/history length and destructive aliasing.
- Predictor latency and fetch redirection latency.
- Update timing: execute-time, commit-time, or hybrid.
- Misprediction penalty: frontend depth + backend recovery + lost issue/commit opportunity.
- Fetch bandwidth loss from taken branches inside a fetch packet.

### 5. TAGE Predictor Review

TAGE idea:
- TAGE means tagged geometric history length predictor.
- It keeps multiple predictor tables indexed with different global-history lengths.
- Short-history tables learn local/simple patterns; long-history tables learn long-range correlations.
- Each non-base table stores a partial tag to reduce destructive aliasing.

Core structures:
- Base predictor: simple bimodal predictor used when no tagged table matches.
- Tagged tables: each entry usually has prediction counter, tag, and usefulness bit.
- Geometric history lengths: table history lengths grow roughly geometrically, such as short, medium, long, and very long histories.
- Provider: the longest-history matching table that supplies the main prediction.
- Alternate provider: a shorter-history matching table or base predictor used when the provider is weak or newly allocated.
- Usefulness tracking: tells whether an entry has been helpful enough to keep during replacement.

Prediction flow:
1. Hash PC with different global-history slices for each table.
2. Read base predictor and tagged tables in parallel if timing allows.
3. Compare tags in tagged tables.
4. Choose the longest matching provider.
5. If provider confidence is weak, optionally use alternate prediction.
6. Carry provider/alternate metadata into the FTQ or branch metadata for update.

Update/allocation:
- Correct prediction: strengthen the provider counter and possibly usefulness.
- Misprediction: update provider, then allocate entries in longer-history tables that did not match.
- Replacement prefers entries with low usefulness.
- History update timing is critical because speculative GHR must be recoverable on misprediction.

Performance-modeling knobs:
- Number of tables.
- History lengths.
- Table entry count and associativity.
- Tag width.
- Counter width and allocation policy.
- Predictor latency: single-cycle vs pipelined prediction.
- Update timing and wrong-path history pollution.

Interview contrast:
- Gshare is compact and simple but aliases many unrelated branches into one counter.
- TAGE uses multiple tagged history lengths to reduce aliasing and learn both short and long branch correlations.
- TAGE improves accuracy but costs more SRAM, history bookkeeping, update complexity, and possibly frontend latency.

### 6. Review Questions

- What is the difference between a direction miss and a target miss?
- Why does a BTB miss on a taken branch look like a not-taken prediction?
- Why do global-history predictors alias?
- What metadata must be checkpointed to recover history after a misprediction?
- Why is RAS important for return-heavy workloads?
- How does TAGE choose between provider and alternate prediction?
- Why do TAGE tables use geometric history lengths?
- What is the usefulness bit protecting against?

## Part 6 — TLB, MMU, and Page Table Walker

RSD note: the inspected RSD tree does not appear to implement a real TLB, MMU, `satp`, or page-table walker. The cache paths use physical-address-style indexing/tagging and the verification environment uses a pretranslated memory map. Treat this section as external architecture review unless we later find a different RSD branch with MMU support.

### 1. Translation Pipeline

Common high-performance path:
- I-side: fetch VA -> ITLB lookup -> I$ access.
- D-side: load/store VA -> DTLB lookup -> D$ access.
- VIPT L1 cache can overlap TLB lookup with cache set indexing when index+offset bits fit inside the page offset.
- On L1 TLB hit, translation returns PPN, permissions, memory attributes, page size, and possibly cacheability.
- On L1 TLB miss, the request probes L2 TLB / shared TLB.
- On L2 TLB hit, refill L1 TLB.
- On L2 TLB miss, page table walker reads PTEs from memory and then fills L2 TLB, usually followed by L1 refill.

### 2. L1 and L2 TLB Organization

Typical organization:
- L1 ITLB / DTLB: small, low-latency, often fully associative or highly associative.
- L2 TLB / STLB: larger, usually set associative.
- Entries include VPN tag, PPN, ASID/VMID, page size, permissions, valid bit, global bit, and replacement state.
- Fully associative L1 reduces conflict misses but costs CAM power.
- Set-associative L2 scales better but can suffer set conflicts.

Important policy questions:
- Does an L2 TLB hit fill only the requesting L1 or both ITLB/DTLB?
- Are superpage entries duplicated in a separate CAM or mixed into the normal arrays?
- Does the PTW fill L2 first and then L1, or fill both directly?
- How are stale entries invalidated on `SFENCE.VMA` or context switch?

### 3. RISC-V Page Sizes

Sv32:
- 2-level page table.
- 4 KB base pages.
- 4 MB megapages.

Sv39:
- 3-level page table.
- 4 KB base pages.
- 2 MB megapages.
- 1 GB gigapages.

Sv48:
- 4-level page table.
- 4 KB base pages.
- 2 MB, 1 GB, and 512 GB superpages.

Interview point:
- Larger pages reduce TLB pressure but increase internal fragmentation and can complicate OS allocation.

### 4. Page Table Walker Flow

For an L2 TLB miss:

1. Capture the faulting VPN, privilege mode, access type, ASID, and page-table root from `satp`.
2. Read the top-level PTE from memory.
3. Check PTE validity and permissions.
4. If the PTE is a pointer to the next level, compute the next PTE address and repeat.
5. If the PTE is a leaf, check alignment for the page size.
6. Check R/W/X/U/G/A/D bits and privilege rules.
7. On success, form the physical address from PPN + page offset.
8. Fill L2 TLB with page size and permissions.
9. Refill L1 TLB from L2 or directly from the PTW result.
10. Replay or restart the original fetch/load/store.

Fault cases:
- Invalid PTE.
- Permission violation.
- Misaligned superpage.
- Accessed/dirty bit handling fault if hardware does not update A/D bits.
- Page-table memory access fault.

### 5. Modeling Hooks

- ITLB miss rate, DTLB miss rate, L2 TLB hit rate.
- PTW latency distribution and cache hit/miss behavior of page-table reads.
- Number of outstanding PTW walks.
- PTW contention with normal D$ or memory traffic.
- Page size mix.
- TLB shootdown and `SFENCE.VMA` overhead.

### 6. TLB and Virtual Memory Corner Cases

Synonyms and homonyms:
- Synonym: two different virtual addresses map to the same physical address. This can create VIPT cache aliasing if both VAs can occupy different L1 sets.
- Homonym: the same virtual address in different address spaces maps to different physical addresses. ASID/VMID tags prevent stale cross-process hits.

ASID / VMID / global entries:
- ASID distinguishes user processes within an address space regime.
- VMID distinguishes virtual machines or guest contexts in virtualized systems.
- Global mappings can be shared across ASIDs, such as kernel mappings, but must be used carefully.

TLB invalidation:
- RISC-V uses `SFENCE.VMA` to order page-table updates and invalidate stale translations.
- Context switches can either flush TLBs or rely on ASIDs to avoid full flushes.
- Multiprocessor systems need TLB shootdown so other cores stop using stale translations.
- Shootdowns are expensive because they involve inter-processor coordination and serialization.

Page fault vs TLB miss:
- TLB miss: translation is not cached; PTW may find a valid PTE and refill the TLB.
- Page fault: translation or permission is invalid architecturally; OS must handle it.
- Access fault: page-table memory access or physical memory access failed for a reason other than normal page permission.

Superpage corner cases:
- Superpages improve TLB reach, but leaf PTEs at upper levels require physical-address alignment.
- Misaligned superpage PTEs fault.
- Mixed page sizes complicate TLB lookup, replacement, and page-walk refill policy.

VIPT cache constraints:
- VIPT L1 can overlap TLB lookup with cache indexing only if set-index bits fit inside the page offset.
- If index bits extend above page offset, synonyms can map the same PA into different sets.
- Common fixes include page coloring, lower associativity/index constraints, or physical-indexed lookup.

Memory attributes:
- TLB/PTE result may carry cacheability, ordering, executable, user/supervisor, dirty/accessed, and device-memory attributes.
- MMIO/device mappings are usually non-cacheable and strongly ordered relative to normal cacheable memory.

### 7. Review Questions

- Why is L1 TLB often fully associative while L2 TLB is set associative?
- What is the difference between a page fault and an access fault?
- What state must be included in a TLB tag besides VPN?
- How do huge pages improve performance?
- Why can page-table walks create cache pollution?
- What is the difference between a synonym and a homonym?
- Why do ASIDs reduce context-switch overhead?
- Why are TLB shootdowns expensive?

## Part 7 — Cache, Coherence, and Memory System

This is the broader memory-system review section beyond the RSD L1D optimization spec.

### 1. Cache Write Policies

Write-back:
- Store updates the cache line and sets dirty bit.
- Memory/lower cache is updated only on eviction or writeback.
- Lower bandwidth, more complexity.

Write-through:
- Store updates both cache and lower level immediately.
- Simpler coherence and recovery, but much higher write traffic.

Write-allocate:
- On write miss, fetch the line into cache, then write it.
- Good when stores have locality or later reads use the line.

No-write-allocate:
- On write miss, send write to lower level without filling the cache.
- Good for streaming writes with little reuse.

Common modern pairing:
- L1D usually write-back + write-allocate.
- Non-temporal stores may bypass or reduce allocation to avoid pollution.

### 2. Write Buffers Between Caches

Why write buffers exist:
- Decouple the core/L1 from slower lower-level cache or memory.
- Merge adjacent writes.
- Hold dirty evictions while the L1 continues serving hits.
- Reduce structural stalls when the lower-level interface is busy.

Things to model:
- Capacity and backpressure.
- Store-to-load forwarding from buffer if needed.
- Write merging and byte masks.
- Ordering rules for fences, atomics, uncached MMIO, and release/acquire operations.
- Deadlock avoidance when write buffer competes with refill traffic.

### 3. MESI and MOESI

MESI states:
- Modified: only this cache has the line, dirty.
- Exclusive: only this cache has the line, clean.
- Shared: multiple caches may have the line, clean.
- Invalid: line is not valid.

MOESI adds:
- Owned: dirty data may be shared; owner supplies data and eventually writes back.

Common transitions:
- Read miss: get line in Exclusive or Shared depending on other sharers.
- Write to Shared: invalidate other sharers, move to Modified.
- Read by another core while Modified: supply data, downgrade to Shared/Owned depending on protocol.
- Evict Modified/Owned: write back or transfer ownership.

### 4. Snooping vs Directory Coherence

Snooping bus:
- All coherent caches observe transactions on a shared bus.
- A core broadcasts read, read-exclusive, upgrade, or invalidate requests.
- Other caches snoop the address and respond if they have the line.
- Simple and fast for small core counts, but bus bandwidth and electrical scaling limit it.

Directory:
- A directory tracks which cores may have each cache line.
- Requests go to the directory/home agent, which sends targeted invalidations or forwards.
- Scales better to many cores or chiplets, but adds directory storage and indirection latency.

Interview contrast:
- Snooping = broadcast and observe.
- Directory = lookup sharer set and send targeted messages.

### 5. Interconnect Types

Shared bus:
- Single shared medium.
- Simple arbitration.
- Natural fit for snooping.
- Poor bandwidth scaling.

Crossbar:
- Multiple masters can connect to multiple slaves simultaneously when paths do not conflict.
- Needs arbitration per target.
- Higher area/wiring cost than a bus.

Ring:
- Packets circulate around a ring.
- Moderate scalability and regular layout.
- Latency depends on hop count and congestion.

Mesh / NoC:
- Packet network with routers and links.
- Scales to many agents.
- Needs routing, virtual channels or buffering, ordering rules, and deadlock avoidance.

Point-to-point coherent fabric:
- Used in many modern SoCs.
- Often combines request, response, snoop, and data channels with credits or valid/ready handshakes.

### 6. ACE / CHI Coherent Interconnect Basics

Why this matters:
- Qualcomm/Arm-style SoC discussions often use Arm coherent-fabric vocabulary even when the core-level concept is generic cache coherence.
- ACE and CHI are Arm coherent interconnect protocols/families; details vary by implementation, but the concepts are useful for interview discussion.

ACE high-level:
- ACE extends AXI with coherent transactions and snoop channels.
- It is commonly described around read/write address/data/response channels plus snoop request and snoop response/data behavior.
- It fits smaller coherent systems better than very large mesh fabrics.

CHI high-level:
- CHI is a packetized coherent interconnect protocol designed for scalable systems.
- It separates request, response, snoop, and data traffic into protocol channels.
- It uses transaction IDs, credits, ordering rules, and explicit node roles.

Common node roles:
- Request node: usually a CPU, GPU, accelerator, or coherent master that initiates requests.
- Home node: owns ordering/serialization for an address region and tracks coherence state or directory information.
- Slave node / memory node: provides access to memory or lower-level storage.
- Snoop target: a cache that may hold a copy and must respond to snoop requests.

Important terms:
- Snoop filter: structure that tracks which caches may hold a line so the fabric can avoid broadcasting unnecessary snoops.
- Home agent: coherence manager for an address range; may consult directory/snoop filter state.
- Credits: flow-control tokens that prevent overrunning downstream buffers.
- Request channel: carries read/write/atomic/coherence requests.
- Response channel: carries completion, permission, and ordering responses.
- Snoop channel: asks other caches to invalidate, downgrade, or supply data.
- Data channel: carries cache-line data separately from control messages.

Modeling hooks:
- Snoop traffic volume.
- Home-node queue occupancy.
- Credit stalls.
- Data-channel bandwidth.
- Directory/snoop-filter hit rate.
- Coherence-induced invalidations and ownership transfers.
- Latency split between request path, snoop path, and data response path.

Interview framing:
- Snooping bus is conceptually broadcast-and-observe.
- Directory/home-node coherence is lookup-and-target.
- CHI-style fabrics make this scalable by separating message classes and using credits and node roles, but add queues, ordering rules, and latency.

### 7. Handshake Rules

Valid/ready basics:
- Transfer happens only when `valid && ready`.
- Producer holds data stable while `valid` is asserted and transfer has not happened.
- Consumer may assert/deassert `ready` based on capacity.
- Avoid combinational loops between `valid` and `ready`.
- Multi-channel protocols need ordering IDs, response matching, and deadlock rules.

AXI-style ideas to remember:
- Separate address, data, and response channels.
- Reads and writes are independent.
- Burst transactions amortize address overhead.
- IDs allow multiple outstanding transactions.
- Backpressure is legal on every channel.

### 8. Port Conflicts and Banking

Port conflict examples:
- Load hit vs store commit write to same L1D array resource.
- Demand miss refill vs dirty victim read/writeback.
- I$ demand fetch vs I$ prefetch probe.
- PTW memory request vs normal load/store miss.

Banking examples:
- Bank by cache set index.
- Bank by line-interleaving address bit.
- Split tag/data arrays separately.
- Multi-bank conflict policy: replay loser, stall loser, or schedule around predicted bank conflicts.

Performance-modeling hook:
- Track cache misses separately from structural access conflicts. They can have very different fixes.

### 9. Replacement Policy and MSHRs

Replacement policy:
- True LRU: tracks exact recency, simple for 2-way, expensive for high associativity.
- Pseudo-LRU: cheaper approximation commonly used for larger associative caches.
- NRU/second-chance: low-cost valid/reference-bit style policy.
- Random: simple and sometimes competitive, but harder to reason about for deterministic debugging.
- RRIP/DRRIP-style ideas: predict re-reference distance to protect high-reuse lines and reduce pollution.

RSD anchor:
- Current RSD D$ fills use a tree-LRU style replacement path.
- With a tiny 2-way L1D, replacement policy is less important than port conflicts, MSHR count, line size, and miss latency, but it is still part of any cache-performance explanation.

MSHR responsibilities:
- Track outstanding cache misses: address, target way, request type, waiting loads/stores, refill state, and writeback/victim metadata.
- Merge secondary misses to the same line so multiple loads do not allocate duplicate memory requests.
- Allow hit-under-miss and miss-under-miss when the cache pipeline and MSHR resources permit it.
- Enforce backpressure when all MSHRs are full.
- Prioritize demand requests over prefetch requests.

Performance-modeling hooks:
- Count primary misses, secondary misses, MSHR merges, MSHR-full stalls, refill-port conflicts, and dirty-victim writebacks separately.
- Model MSHR occupancy and service time, not only average miss latency, because a design can be limited by memory-level parallelism rather than raw cache hit rate.

### 10. Power, Timing, and Area Tradeoffs

Common tradeoffs:
- More ports increase bandwidth but make SRAM macros, muxing, wires, and timing harder.
- Banking is cheaper than true multi-porting but introduces bank conflicts and arbitration policy.
- Larger CAM-based structures such as issue queues, load/store queues, and wakeup logic scale poorly in dynamic power and critical-path delay.
- Bigger ROBs and queues improve tolerance of latency but increase area, energy, recovery bookkeeping, and wakeup/select pressure.
- Larger predictors reduce misspeculation but consume SRAM/flops and can add frontend latency.
- More MSHRs improve memory-level parallelism but increase bookkeeping and lower-memory pressure.

Architecture interview framing:
- Do not describe an optimization only by IPC. Also describe the hardware cost and the bottleneck it moves.
- A good low-risk proposal reduces switching or stalls without widening a critical path.
- Examples from this file: selective SQ lookup reduces full-CAM toggle activity; way prediction reduces tag-SRAM activation but adds a retry path; LRB reduces replay-queue pressure but adds LSU-local storage and replay arbitration.

### 11. Mobile Power / Performance Constraints

Qualcomm/mobile framing:
- Mobile CPU design is often constrained by perf-per-watt, burst performance, sustained thermals, and battery energy rather than only peak IPC.
- A feature that improves benchmark IPC can still be a bad mobile tradeoff if it increases always-on power or causes thermal throttling sooner.

DVFS:
- Dynamic voltage and frequency scaling changes both performance and energy.
- Higher frequency usually requires higher voltage; dynamic power scales roughly with capacitance, activity, voltage squared, and frequency.
- A microarchitecture change can be evaluated at fixed frequency, fixed power, or iso-performance energy; those answer different questions.

Thermal throttling:
- Peak performance may last only until thermal limits force frequency reduction.
- Sustained performance depends on average power, workload phase behavior, package cooling, and scheduler policy.
- A power-hungry prefetcher or predictor can improve short-run IPC but hurt sustained performance if it raises thermal pressure.

Perf-per-watt:
- Useful metric for mobile and datacenter efficiency, but must be paired with absolute performance.
- A design can improve perf/W by saving power at the same performance, improving performance at the same power, or both.
- Use energy per task when comparing two designs that finish at different times.

Clock gating and power gating:
- Clock gating disables switching when a block is idle.
- Power gating cuts leakage but has wakeup latency and state-retention cost.
- Good model counters include active cycles, idle cycles, gated cycles, and access counts per structure.

SRAM/CAM access power:
- Large CAMs such as issue queues, store queues, TLBs, and wakeup logic are expensive because many entries compare in parallel.
- SRAM power depends on read/write count, wordline/bitline activity, banking, and port count.
- Gating, way prediction, banking, and hierarchical lookup reduce dynamic energy when they do not add harmful latency.

Prefetch power tradeoff:
- Prefetching can save miss latency but consumes bandwidth, MSHRs, cache-array accesses, and replacement capacity.
- Track prefetch accuracy, coverage, timeliness, pollution, dropped prefetches, and demand interference.
- Mobile-friendly prefetchers usually need throttling based on usefulness, bandwidth pressure, MSHR occupancy, and thermal/power state.

Interview framing:
- For Qualcomm, always discuss both the performance mechanism and the power mechanism: what toggles less, what toggles more, whether sustained thermals improve, and how to validate the tradeoff with counters.

### 12. Cache and Memory-System Corner Cases

VIPT aliasing:
- VIPT L1 caches are fast because index lookup can overlap with TLB lookup.
- If virtual index bits are not fully contained in the page offset, synonyms can place the same physical line into multiple sets.
- Page coloring or cache geometry constraints are common ways to avoid this.

Non-cacheable and MMIO accesses:
- MMIO should not be speculatively cached like normal memory.
- Device memory often requires stronger ordering, side-effect preservation, and no silent merging/reordering.
- Loads/stores to MMIO may need to bypass normal speculation, prefetching, and write combining.

Self-modifying code and instruction visibility:
- If software writes code through D$, the I$ may still contain stale instructions.
- `FENCE.I` or architecture-specific cache maintenance makes the instruction side observe the new code.
- Performance model should count the flush/refetch penalty if this path matters.

Unaligned and split-line accesses:
- An unaligned load/store may touch two cache lines or pages.
- Split-line accesses can require two tag/data accesses, two TLB translations, and more complex exception ordering.
- Atomics often require stricter alignment; misaligned atomics may trap or fall back to slow handling.

False sharing:
- Two cores write different words in the same cache line.
- Coherence sees line-level ownership transfers even though software data are logically independent.
- Symptoms include high invalidation traffic and poor scaling.

Inclusivity and exclusivity:
- Inclusive caches require upper-level lines to also exist in lower levels; lower-level eviction may invalidate upper levels.
- Exclusive caches avoid duplication and increase effective capacity but make fills/evictions more complex.
- Non-inclusive caches avoid strict guarantees and require directory/snoop filters to track presence.

Dirty eviction and deadlock risks:
- A cache miss can require victim writeback before refill.
- If writeback buffers, MSHRs, or interconnect credits are full, the cache can deadlock unless protocols reserve escape resources.
- Demand refills, writebacks, prefetches, and coherence probes need priority rules.

Replacement pathologies:
- Direct-mapped and low-associativity caches can thrash on regular strides.
- Pseudo-LRU may evict useful lines under cyclic access patterns.
- Prefetching can make replacement worse if prefetch usefulness is not tracked or throttled.

ECC/parity:
- Caches often protect tags/data with parity or ECC.
- Correctable errors may add latency or counters; uncorrectable errors can raise machine checks or poison data paths.

## Part 8 — Retire, Commit, ROB State, and Recovery

This section overlaps with backend commit, but keeps retire-specific interview questions in one place.

### 1. Instruction States in a ROB

Typical states:
- Not allocated: free ROB slot.
- Allocated / busy: instruction is in-flight and not complete.
- Issued: instruction has left the issue queue.
- Executed: result is ready or memory op has produced a completion state.
- Writeback complete: destination physical register or completion bit is updated.
- Exception/replay pending: instruction has a non-success completion state.
- Commit-ready: instruction and all older instructions are complete.
- Committed / retired: architectural state updated; ROB head can advance.
- Squashed: entry is younger than a redirect/recovery point.

RSD simplification:
- `ActiveList.sv` stores metadata and uses a compact execution-state bit for normal completion, plus a recovery register for the oldest exceptional/refetch state.
- Debug/reference logic retains full execution-state checking for verification.

### 2. ROB Pointer Movement

Tail pointer:
- Moves on rename/dispatch allocation.
- Must not overrun head.
- On recovery, younger speculative entries are removed by moving/recovering tail state.

Head pointer:
- Moves only at commit.
- Can move by up to commit width per cycle.
- Stops at the first not-finished instruction or at an instruction that triggers recovery/fault handling.

Commit width:
- A 2-wide commit core can retire up to two ops/instructions per cycle, but only if they form an oldest contiguous completed group.
- Multi-uop instruction commit requires tracking instruction boundaries.

### 3. Branch Misprediction: Commit-Time vs Early Recovery

Commit-time recovery:
- Detect or record the misprediction, but wait until the branch reaches ROB head before redirect/flush.
- Simpler precise-state reasoning.
- Worse performance because wrong-path fetch/execute continues longer.

Early recovery:
- When a branch resolves in execute/writeback, redirect frontend immediately and squash younger backend work using ROB age/range.
- Must prove that older unresolved exceptions still take priority.
- Needs checkpoints or recovery state for rename map, LSQ pointers, predictor history, and frontend queues.

Frontend-only early restart:
- Redirect fetch as soon as the correct PC is known.
- Temporarily block new wrong-path instructions from entering backend while older backend work drains or until recovery is safe.
- Reduces fetch bubble cost but still needs careful handling of backend resources and architectural side effects.

RSD anchor:
- RSD records refetch/recovery events from writeback and can start recovery before the op reaches commit for branch/refetch-style events.
- CSR-visible traps/faults wait for commit-stage handling to keep precise exception semantics.

### 4. Flush Rules

Flush on:
- Branch misprediction.
- Exception/fault/trap.
- Store-load forwarding failure or memory-order violation.
- FENCE.I refetch after cache flush.
- Interrupt entry.
- Atomic/fence serialization failure or unsupported operation, if implemented.

Flush range:
- `THIS_PC`: flush starting at the offending instruction and refetch it.
- `NEXT_PC`: let offending instruction commit/effect complete, flush younger, refetch next.
- `BRANCH_TARGET`: redirect to resolved target.
- CSR target: redirect to trap vector or `mepc`.

### 5. Review Questions

- Why does commit happen in order even when execution is out of order?
- What exactly moves head and tail pointers?
- Why can branch recovery often be early but exceptions wait until commit?
- What state is restored during recovery?
- How do stores interact with commit and memory visibility?

## Part 9 — Vector and SIMD

RSD note: the inspected RSD source does not show a full RISC-V Vector extension pipeline. This section is for external review and for discussing your prior vector/SIMD kernel optimization work.

### 1. SIMD vs RISC-V Vector

Fixed-width SIMD:
- Programmer/compiler targets a fixed register width such as 128/256/512 bits.
- Code may need separate versions for different widths.

RISC-V Vector:
- Vector length is implementation-defined through `VLEN`.
- Software uses `vsetvl` / `vsetvli` to choose `vl` based on remaining elements.
- Same binary can scale across different vector lengths.

Key RVV terms:
- `VLEN`: hardware vector register length in bits.
- `SEW`: selected element width.
- `LMUL`: register grouping multiplier.
- `vl`: active element count for current loop strip.
- `vtype`: encodes SEW, LMUL, tail policy, mask policy.
- Mask register: controls per-element predication.
- Tail policy: what happens to inactive tail elements.

### 2. Vector Memory Operations

Patterns:
- Unit-stride load/store: best bandwidth and simplest coalescing.
- Strided load/store: useful for regular non-contiguous layout.
- Indexed/gather/scatter: flexible but expensive, stresses memory ordering and cache/TLB.
- Segment loads/stores: useful for AoS-style structures.
- Fault-only-first loads: help vectorize loops with uncertain termination.

Performance questions:
- Are accesses aligned?
- Are they cache-line friendly?
- Do they cross pages often?
- Do they create bank conflicts?
- Is the bottleneck memory bandwidth, vector ALU throughput, or scalar loop overhead?

### 3. Chaining, Convoys, and Chimes

Chaining:
- A dependent vector instruction can start consuming elements as soon as the producer creates the first elements.
- It avoids waiting for an entire vector instruction to finish.
- Example: vector load produces element group 0, vector multiply consumes it, vector add follows, all overlapped as a pipeline.

Convoy:
- A group of vector instructions that can execute together without structural hazards.

Chime:
- Roughly one vector-length time step for a convoy.
- Old vector-performance models estimate runtime as number of chimes times vector length plus startup costs.

Modern modeling note:
- Real cores also need startup latency, memory latency, bank conflicts, issue bandwidth, mask overhead, and tail effects.

### 4. Kernel Optimization Topics

Min/max:
- Use vector reductions when possible.
- Handle tails with masks instead of scalar cleanup when efficient.
- Avoid horizontal reduction every iteration; reduce partial vectors then final-reduce.

FIR / BKFIR-style kernels:
- Exploit sliding-window reuse.
- Consider vector loads of samples and coefficients.
- Unroll taps to expose ILP.
- Use fused multiply-add if available.
- Watch alignment, coefficient layout, and cache reuse.

Matmul:
- Tile for L1/L2/cache reuse.
- Use vector registers as accumulators.
- Pack matrices to make inner loops unit-stride.
- Choose blocking based on vector length, register pressure, and cache capacity.

Memory-bound kernels:
- Prefetch if latency dominates and access pattern is predictable.
- Avoid gather/scatter unless data layout cannot be changed.
- Use non-temporal stores only when reuse is unlikely.

Library names to verify later:
- BLAS / CBLAS, OpenBLAS, Eigen, oneDNN, xNNPACK, Halide.
- RISC-V RVV intrinsic kernels and vendor math/DSP libraries.
- Qualcomm ecosystem names may include QNN / SNPE / Hexagon-oriented libraries, but we should verify which one matches your project before using it in interview answers.

### 5. Compiler, Intrinsics, and Scheduling Notes

Personal experience anchor:
- I optimized kernels such as BKFIR using compiler intrinsics rather than relying only on the auto-vectorizer.
- I worked closely with the compiler team, so I can discuss not only the algorithmic transformation but also how source structure affects the generated instruction stream.

Intrinsic-level optimization ideas:
- Keep hot data in different vector registers across loop iterations to avoid unnecessary reloads.
- Use register blocking / accumulator blocking so partial sums stay live in registers.
- Unroll enough to expose ILP, but not so much that register pressure causes spills.
- Put operations that map to fused instructions next to each other in the intrinsic source when possible. If the ISA/compiler supports fused multiply-add or other fused patterns, write the code so the compiler can emit the fused instruction or use the explicit fused intrinsic.
- Prefer unit-stride loads/stores and contiguous data layout. Change AoS to SoA or pack data when the kernel is bandwidth-bound.
- Use masks for tails and conditionals when that avoids scalar cleanup or branch overhead.
- For fixed-point/DSP-style kernels, be explicit about saturation, rounding, widening, narrowing, and overflow behavior.

Compiler scheduling notes:
- A compiler generally schedules instructions within a basic block, meaning a straight-line region bounded by control-flow instructions such as branches.
- Across branches, calls, memory operations with unknown aliasing, or exception-visible operations, the compiler may be conservative.
- If the loop body has frequent branches, converting control flow into predicated/select operations can expose more straight-line scheduling freedom.
- Ternary expressions may lower to a conditional select or predicated instruction sequence when profitable. Conceptually: taken-path operations are guarded by predicate `p`, and fall-through operations are guarded by `!p`; the exact lowering depends on target ISA, cost model, and side effects.
- Predication is not always free. It can increase instruction count or execute work from both paths, so it helps most when branches are unpredictable and both bodies are small.

Compiler-facing details to remember:
- Aliasing matters. Use `restrict`-style assumptions, `const`, and clear pointer separation when valid so the compiler can reorder and vectorize memory operations.
- Alignment matters. Communicate alignment through APIs, allocation, pragmas, or compiler builtins when valid.
- `volatile` blocks many useful optimizations and should not be used for normal benchmark data.
- Check generated assembly, not just source. Look for spills, reloads, missed fusions, scalarized vector ops, extra `vsetvl`, poor unrolling, and unexpected branches.
- Compiler flags matter: target ISA flags, vector-extension flags, optimization level, LTO, and math flags can change code generation. Be careful with fast-math-style flags because they can change numerical semantics.
- Use small directed kernels to isolate compiler/codegen issues before judging full application performance.

Microarchitecture connection:
- Intrinsics are a contract with both compiler and hardware. Good intrinsic code exposes ILP, avoids alias ambiguity, controls register pressure, and creates memory access patterns that the cache/TLB/vector unit can actually sustain.
- When discussing a kernel speedup, separate algorithmic improvement, compiler/codegen improvement, and microarchitecture effect.

### 6. Review Questions

- Why does RVV use strip mining?
- How does `LMUL` trade register capacity against wider operations?
- Why are gather/scatter operations harder to optimize than unit-stride loads?
- What is vector chaining and why does it help?
- How would you model a vectorized FIR kernel bottleneck?
- When should I use intrinsics instead of trusting auto-vectorization?
- How can source code structure help the compiler emit fused instructions?
- Why can predication help an unpredictable branch, and when can it hurt?
- What signs in generated assembly indicate register pressure or poor scheduling?

## Part 10 — Interrupt and Exception Implementation

To fill with RSD implementation evidence and interview explanation.

Topics to cover:
- Synchronous exception vs asynchronous interrupt.
- Precise exception point.
- Trap vector target selection.
- CSR state updates: `mepc`, `mcause`, `mtval`, `mstatus`.
- Pipeline drain or flush requirements.
- Interrupt priority and masking.

## Part 11 — FENCE and FENCE.I and ecall/ebreak/csr/sret/mret Implementation

To fill with RSD implementation evidence and interview explanation.

Topics to cover:
- Memory-ordering fence vs instruction-cache synchronization fence.
- Why `FENCE` serializes memory ordering.
- Why `FENCE.I` needs instruction-side visibility after data-side code writes.
- Cache flush, pipeline refetch, and store-buffer drain requirements.

## Part 12 — Atomic, LR/SC, and AMO Implementation

To fill with RSD implementation evidence and interview explanation.

Topics to cover:
- LR/SC reservation set and failure conditions.
- AMO read-modify-write atomicity.
- Coherence permission requirements for atomics.
- Store-buffer interaction.
- Memory-ordering acquire/release bits.
- RSD implementation status versus what a full RISC-V A-extension core would need.
