# Performance Modeling and C++ Review

Unified performance-modeling and simulator-C++ review notes for the Qualcomm second-round preparation.

This file has two major review blocks:

1. Performance modeling: Sparta/Olympia structure, scheduler/events, trace-driven modeling, reports, debug flow, and interview wording.
2. C++ coding: simulator-quality C++ fundamentals, callbacks, STL/data structures, bit manipulation, and microarchitecture coding practice.

## Part 1 — Performance Modeling Review

Source: `../riscv-perf-model-fengze/review.md`

### Goal

Build a structural understanding of the RISC-V performance model repo, with enough clarity to explain the framework, code organization, profiling/debug flow, and how it compares to a hand-written cycle model.

### Core Distinction

#### Sparta

Sparta is the generic simulation framework. It is not the CPU model itself.

It provides:

- A global simulated-time scheduler.
- A resource tree, such as `top.cpu.core0.fetch`.
- `Unit` and `ResourceTreeNode` abstractions for model components.
- Typed ports for communication between components.
- Events and event callbacks.
- Parameters from YAML and command-line options.
- Counters, reports, logs, PEvents, and pipeout collection.

Mental model:

```text
Sparta = simulator infrastructure + component wiring + timing/event/stats/debug framework
```

#### Olympia

Olympia is the actual RISC-V out-of-order CPU performance model built using Sparta.

It implements:

- Fetch / I-cache
- Decode / Mavis decoder integration
- Rename
- Dispatch
- Issue queues
- Execute pipes
- LSU
- D-cache
- MMU / TLB
- L2 / BIU / memory subsystem
- ROB retirement

Mental model:

```text
Olympia = RISC-V CPU microarchitecture model implemented on top of Sparta
```

### Code Walkthrough Notes

#### Step 1: `sim/main.cpp`

`main.cpp` is the executable entry point. It does not model CPU behavior directly.

Main responsibilities:

- Define command-line defaults.
- Parse workload, `-i` instruction limit, architecture config, report/log options, etc.
- Create the global `sparta::Scheduler`.
- Create `OlympiaSim`.
- Let `sparta::app::CommandLineSimulator` populate, run, and post-process the simulation.

Important pattern:


```cpp
sparta::Scheduler scheduler;
OlympiaSim sim(scheduler, num_cores, workload, ilimit, show_factories);

cls.populateSimulation(&sim);
cls.runSimulator(&sim);
cls.postProcess(&sim);
```

Mental model:

```text
main.cpp = command-line + scheduler + launch wrapper
OlympiaSim = concrete simulator that knows how to build Olympia
```

#### Step 2: `sim/OlympiaSim.cpp`

`OlympiaSim` tells Sparta how to build this specific simulator.

Important setup phases:

```cpp
buildTree_()
configureTree_()
bindTree_()
```

Mental model:

```text
buildTree_     = create components
configureTree_ = apply parameters
bindTree_      = connect ports
```

#### `addResourceFactory<olympia::CPUFactory>()`

Code:

```cpp
getResourceSet()->addResourceFactory<olympia::CPUFactory>();
```

The angle brackets are C++ template syntax. Here they pass a type, not a runtime value.

Meaning:

```text
Register Olympia's CPUFactory type with Sparta's resource registry.
```

Analogy:

```cpp
std::vector<int> v;
```

Here `<int>` tells `vector` what type it stores.

In Olympia:

```cpp
addResourceFactory<olympia::CPUFactory>();
```

tells Sparta what factory type to register.

#### `getCPUFactory_()`

Code shape:

```cpp
auto OlympiaSim::getCPUFactory_() -> olympia::CPUFactory*
```

This is trailing return type syntax. It means the same as:

```cpp
olympia::CPUFactory* OlympiaSim::getCPUFactory_()
```

Inside, it does:

```cpp
auto sparta_res_factory = getResourceSet()->getResourceFactory("cpu");
auto cpu_factory = dynamic_cast<olympia::CPUFactory*>(sparta_res_factory);
```

Meaning:

```text
Ask Sparta for the generic factory named "cpu".
Cast it to Olympia's concrete CPUFactory type.
```

Why cast? Because the registry returns a generic base pointer, but Olympia needs CPUFactory-specific methods like `setTopology()`, `buildTree()`, and `bindTree()`.

#### `buildTree_()`

`buildTree_()` starts the component hierarchy.

Important operations:

```cpp
auto cpu_factory = getCPUFactory_();
```

Gets the CPU factory.

```cpp
allocators_tn_.reset(new olympia::OlympiaAllocators(getRoot()));
```

Creates common allocators for frequent model objects such as instructions, memory access records, load/store records, and MSHR entries.

```cpp
sparta::ResourceTreeNode* cpu_tn = new sparta::ResourceTreeNode(
    getRoot(),
    "cpu",
    ...,
    "CPU Node",
    cpu_factory
);
```

Creates the top-level `cpu` node under the Sparta root.

Initial tree picture:

```text
root
  └── cpu
```

After `CPUFactory` builds the topology, it becomes more like:

```text
root
  └── cpu
      └── core0
          ├── fetch
          ├── icache
          ├── decode
          ├── rename
          ├── dispatch
          ├── execute
          ├── lsu
          ├── dcache
          ├── mmu / tlb
          ├── rob
          └── ...
```

#### Setup Flow Summary

Everything from `main.cpp` through `OlympiaSim`, `CPUFactory`, and `CPUTopology` is setup/elaboration work. No instruction has flowed through the modeled pipeline yet.

Responsibilities:

```text
main.cpp
  = launch simulator
  - parse command-line options
  - get workload path
  - get instruction limit
  - select architecture config
  - create sparta::Scheduler
  - create OlympiaSim
```

```text
OlympiaSim
  = top-level setup phases
  - register CPUFactory
  - create top-level cpu node
  - store workload/config into simulation state
  - apply instruction limit to ROB parameter
  - ask CPUFactory to build and bind CPU
```

```text
CPUFactory
  = instantiate model hierarchy
  - create topology object, usually CoreTopologySimple
  - build ResourceTreeNodes for units
  - replace * with core index, such as core* -> core0
  - attach resource factories to each unit
  - bind static ports between units
```

```text
CPUTopology
  = recipe for CPU blocks and wiring
  - unit list: fetch, decode, rename, dispatch, execute, LSU, caches, ROB, etc.
  - static port connections: fetch to decode, decode to rename, LSU to DCache, ROB to FlushManager, etc.
  - dynamic execute backend binding based on YAML architecture configs
```

RTL analogy:

```text
CPUTopology units        ~= module instances
CPUTopology connections  ~= top-level wires
CPUFactory buildTree     ~= elaboration
CPUFactory bindTree      ~= connecting ports
Scheduler                ~= simulator time engine
```

After setup:

```text
Fetch reads trace
  -> instructions flow through pipeline
  -> ROB retires instructions
```

### Scheduler And Events

The `sparta::Scheduler` owns simulated time. Units do not run because a top-level loop calls every stage manually. Instead, units schedule callbacks to happen at a specific simulated cycle or phase.

An event means:

```text
Call this function at a scheduled simulated time.
```

Example pattern:

```cpp
sparta::UniqueEvent<> ev_retire_{
    &unit_event_set_,
    "retire_insts",
    CREATE_SPARTA_HANDLER(ROB, retireInstructions_)
};
```

This means that when `ev_retire_` fires, Sparta calls:

```cpp
ROB::retireInstructions_()
```

Scheduling examples:

```cpp
ev_retire_.schedule(1);  // run one cycle later
ev_retire_.schedule(sparta::Clock::Cycle(0));  // run in the current cycle/phase
```

### Difference From My Previous Model

My previous performance model style was manually cycle-driven:

```cpp
void Core::tick() {
    commit.tick();
    writeback.tick();
    execute.tick();
    issue.tick();
    rename.tick();
    decode.tick();
    fetch.tick();

    pipeRegs.update();
}
```

That style uses a centralized global tick loop. Pipeline stages are often called backward so that later stages consume entries first and earlier stages can see freed space. Explicit pipeline-register classes separate current-cycle state from next-cycle state.

Sparta/Olympia is more event-driven and decentralized:

```text
Data arrives on a port
  -> input callback runs
  -> unit updates local state
  -> unit schedules an event if work is needed
  -> event fires at the right cycle
  -> unit sends data/credits to the next unit
```

Key contrast:

```text
Manual model:
  global tick loop calls every stage every cycle

Sparta/Olympia:
  units react to ports, credits, events, and scheduled callbacks
```

### What Replaces Pipeline Registers

Sparta/Olympia still models cycle timing, but the structures are expressed differently:

- Ports: communication between units, similar to typed wires/messages.
- Credits: backpressure and downstream capacity.
- Buffers/queues: local storage such as issue queues, ROB, replay buffers, and fetch queues.
- Events: latency and delayed work.
- `sparta::Pipeline`: explicit staged pipeline resource when the model needs stage-by-stage movement.

So the framework is not less cycle-aware. It just does not require one manually written `tick()` that calls every component.

#### Where Scheduler Appears In Olympia

- `sim/main.cpp`: creates the global `sparta::Scheduler scheduler`.
- `sim/OlympiaSim.cpp`: passes the scheduler into `sparta::app::Simulation`.
- Units create events, for example ROB retire, fetch, LSU issue, cache response.
- Events are scheduled into the global scheduler with calls like `schedule(0)`, `schedule(1)`, or `schedule(latency)`.
- `core/ROB.cpp` can stop the scheduler through `getScheduler()->stopRunning()` when the retire instruction limit is reached.

If Sparta source is installed, the relevant framework header to glance at is:

```cpp
sparta/kernel/Scheduler.hpp
```

For interview prep, do not deep-read scheduler internals. The important idea is that it stores pending events by simulated cycle/phase and dispatches their callbacks in deterministic order.

#### Which Sparta Repo To Clone

Sparta lives in the Sparcians MAP repository:

```text
https://github.com/sparcians/map
```

This Olympia repo does not vendor Sparta. It expects Sparta as an external dependency found by CMake.

For source inspection and compatibility with this checkout, prefer the version mentioned by the Olympia README:

```bash
git clone --recursive --branch map_v2.0.21 https://github.com/sparcians/map.git ~/map-sparta-v2.0.21
```

For latest stable MAP source, upstream currently recommends `map_v2.2`, but that is not necessarily the exact version this Olympia checkout was tested against.

#### Sparcians Ecosystem Map

Useful related repositories:

- `sparcians/map`: MAP framework. Contains Sparta and Helios/Argos.
- `sparcians/mavis`: RISC-V decoder library. Olympia uses Mavis under `mavis/`.
- `sparcians/stf_spec`: Simulation Trace Format specification.
- `sparcians/stf_lib`: C++ library for reading/writing STF traces. Olympia has this as a submodule.
- `sparcians/stf_tools`: command-line tools around STF traces.
- `sparcians/pegasus`: RISC-V functional simulator. Built on Sparta; useful for co-simulation, STF trace generation, and execution-driven simulator flows.
- `sparcians/simdb`: database/report infrastructure used by newer Sparta/MAP reporting flows.

For interview prep, priority order:

1. `map` / Sparta: know scheduler, ports, events, counters, reports, PEvents, pipeout.
2. `mavis`: know it provides instruction decode / uarch metadata to Olympia.
3. `stf_spec`, `stf_lib`, `stf_tools`: know STF is the trace format Olympia can consume.
4. `pegasus`: know it is the functional model side, useful for co-sim and trace generation.
5. `simdb`: nice-to-know reporting/database backend, lower priority.

Do not deep-read all repos before the interview. One-paragraph purpose and how it connects to Olympia is enough.

### Video Notes: RISC-V Perf-Model Talk

Source: https://www.youtube.com/watch?v=739lNpMWpQI  
Title: `RISC-V Perf-Model: An Open Source Cycle Accurate Performance Model...`  
Speakers: Knute Lingaard and Arup Chakraborty  
Length: 21:39  
Note: summary based on YouTube auto-generated captions.

#### Main Purpose

The talk introduces the RISC-V performance model as an open-source starting point for community-wide CPU and system performance modeling.

The motivation:

- Good microarchitecture design requires performance analysis.
- High-quality performance models are hard and time-consuming to build from scratch.
- The RISC-V community benefits from a shared framework, trace format, and example model.
- The goal is not to model one commercial CPU exactly, but to provide a reusable starting point for core, memory-system, interconnect, and SoC analysis.

#### Sparta Role

Sparta is presented as the infrastructure layer:

- C++ discrete-event simulation framework.
- Provides simulation instances, units/resources, topology, parameters, ports, events, counters, statistics, reports, logs, and notifications.
- Designed for modularity: components can be replaced, extracted, or unit-tested independently.
- Reports and instrumentation are considered central, not optional, because a performance model is only useful if it exposes what the microarchitecture is doing.

Interview wording:

> Sparta is the modeling framework; Olympia is the RISC-V performance model built on top of it.

#### Olympia / RISC-V Perf Model Role

The RISC-V perf model is an example C++ model using Sparta to model an out-of-order superscalar RISC-V core.

Important limitations and framing:

- It is a template/example model, not a real commercial design.
- It is trace-driven, not execution-driven.
- It does not perform functional execution; it consumes a trace generated elsewhere.
- The speaker cautions that "accuracy" only makes sense relative to a target. The model is useful as infrastructure and a baseline, not as a magically accurate CPU.

#### Modeled Pipeline

The model is described as a typical superscalar OoO pipeline:

```text
in-order fetch/decode/rename/dispatch
  -> out-of-order execute
  -> in-order retire
```

The model already supports backpressure:

- Queue full conditions backpressure upstream stages.
- Dispatch routes instructions to the correct execution unit.
- Execution units can stall based on latency or busy state.
- Retirement is in order.

#### Current Model Status In The Talk

At the time of the talk, the repo was still new and many units were minimal or pass-through.

Available features mentioned:

- RV64GC-oriented model.
- Small core: 2-wide.
- Medium core: 3-wide.
- Big core: 8-wide.
- Sample Dhrystone trace.
- Ability to compare IPC and stall behavior across core configs.
- Fetches a fixed number of instructions per cycle.
- Decode identifies instruction types.
- Dispatch routes instructions to the proper execution unit.

#### Profiling And Reports

The talk emphasizes Sparta's reporting infrastructure:

- Cycle-by-cycle pipeline trace.
- Pipeline visualization.
- Full stats from beginning of simulation.
- Warmup/delayed stats.
- Time-series reports at chosen intervals.
- Multiple report formats: text, JSON, CSV.

This maps directly to commands in this repo such as:

```bash
./olympia -i1M traces/dhry_riscv.zstf --report-all report.out
```

and report definitions under `reports/`.

#### Sparta vs gem5

The Q&A compares Sparta/Olympia with gem5:

- gem5 is mature and execution-driven.
- The Sparta-based RISC-V model is more about modular performance-model infrastructure.
- Accuracy depends on what target you are trying to match.
- Sparta's value is modularity: components can be swapped or extracted. For example, if only LSU analysis matters, a modeler can replace or isolate the LSU while reusing the rest of the framework.

Interview wording:

> gem5 is a mature execution-driven simulator. Olympia is a Sparta-based, trace-driven model intended as a modular performance-modeling starting point. The key value is rapid microarchitecture exploration, instrumentation, and component replacement.

#### Trace And Branch Prediction Discussion

The model uses the STF trace library. Because it is trace-driven:

- The trace already contains the committed instruction stream.
- For branches, the next PC / target information can indicate taken vs not-taken behavior.
- Future branch prediction support can compare predicted direction with trace-observed direction.
- The model already has flushing support; the missing piece discussed was hooking up a branch predictor.

Important interview point:

> Trace-driven simulation can model timing on the known instruction stream, but wrong-path behavior and speculation fidelity are limited unless explicitly modeled.

#### Extensibility Message

A major theme is composability:

- Components built on the same Sparta framework can be connected more easily.
- CPU models, interconnect models, memory models, and other system components can share ports/concepts.
- The speakers mention prior experience where separate CPU and interconnect models could be connected quickly because they used the same framework conventions.

#### Takeaway For My Interview

This video supports the right framing:

- I should describe Olympia as ecosystem awareness, not personal deep expertise.
- I should emphasize Sparta concepts: event-driven simulation, modular units, ports, parameters, counters, reports, PEvents/pipeout.
- I should not overclaim accuracy. Say accuracy requires a target and correlation methodology.
- I should clearly distinguish trace-driven from execution-driven simulation.
- I can connect this to my RiVAI custom model story: custom execution-driven model gave tighter RTL correlation/control; Olympia/Sparta provides standardization and reusable infrastructure.

### Video Notes: CPU Development Using Olympia

Source: https://www.youtube.com/watch?v=Seu0FoXqkmw  
Title: `RISC-V CPU Development Using Olympia Performance Model - Knute Lingaard, MIPS`  
Speaker: Knute Lingaard  
Length: 27:28  
Date: 2024-10-31 upload  
Note: summary based on YouTube auto-generated captions.

#### Main Purpose

This talk is about using Olympia as a practical CPU development and tradeoff-analysis tool, not just as an example framework.

Knute frames performance models around several uses:

- Microarchitecture development and design-space exploration.
- Software tuning against a future or configurable hardware target.
- Correlation/debug support as RTL and model evolve together.

The key message: Olympia is useful because it exposes bottlenecks and lets the designer quickly change machine parameters, rerun workloads, and inspect where stalls moved.

#### What Olympia Is In This Talk

Olympia is described as:

- A C++ performance model.
- A RISC-V community model.
- Built on Sparta.
- Intended as an extensible starting point, not a final commercial CPU.
- A configurable superscalar/OoO-style CPU pipeline model.

The model is configurable across:

- machine widths between stages,
- queue and buffer sizes,
- pipeline depth,
- execution pipe mix,
- cache and memory hierarchy parameters,
- branch predictor API / frontend work under development.

#### Pipeline / Model Structure

The talk shows a basic Olympia CPU pipeline:

```text
fetch / branch prediction
  -> decode
  -> rename
  -> dispatch
  -> issue / execute
  -> LSU / cache
  -> retire
```

The frontend and branch prediction API are described as simple and still under development. Decode is backed by a strong framework for instruction/uarch information. The main value is not that the default model is perfect, but that it is a concrete configurable baseline.

#### Trace Flow

Olympia consumes STF traces generated by a functional model instrumented with the STF library.

Flow:

```text
binary/application
  -> functional model instrumented with STF writer
  -> STF instruction trace on disk
  -> Olympia timing model
  -> reports / pipeout / PEvents / plots
```

The STF trace represents the instruction stream that actually ran. The trace format can be extended with extra records, but the default model is still trace-driven.

#### Reports, PEvents, And Debug

The talk emphasizes that Olympia/Sparta can generate:

- full reports,
- triggered reports with a chosen time-zero or warmup point,
- snapshots,
- time-series reports,
- pipeout / Argos visualization,
- PEvents for comparison/correlation,
- text files that can be compared against RTL instrumentation.

Interview point:

> A performance model is only useful if it explains where cycles go. Olympia's value is not only timing simulation; it is the instrumentation around reports, PEvents, and pipeline visualization.

#### Tradeoff Example: Small Core To Medium Core

Knute walks through changing the architecture from a small core to a medium core:

- small core: narrower machine,
- medium core: wider machine and more execution pipelines.

The expected result is higher IPC, but the key lesson is not just "IPC improved." The useful workflow is:

```text
change architecture
  -> rerun same trace
  -> compare reports
  -> inspect stall counters
  -> identify which bottleneck moved
```

Example bottleneck movement from the talk:

- integer-busy stalls drop significantly after adding more integer resources,
- branch-busy stalls become visible,
- adding branch capacity can reduce that bottleneck,
- then LSU-busy becomes the next limiter.

This is the classic performance-analysis pattern: removing one bottleneck reveals the next one.

#### Directed Microbenchmark Example: LSU / DCache Timing

The most useful concrete example is a directed load microbenchmark:

- Create a JSON input with many loads to the same address.
- Configure TLB as always-hit.
- Configure L1 D-cache as always-hit.
- Expect roughly 1.0 IPC for a simple stream of independent loads.

Observed behavior:

- retirement had periodic bubbles,
- Argos/pipeout showed holes in the pipeline,
- this suggested a timing issue between LSU and DCache.

Root cause described:

- LSU sends a cache request and expects a response in the right pipeline timing window.
- DCache response timing/order was not aligned with the LSU pipeline expectation.
- There was also an assertion/checking gap.
- Reordering/fixing the relevant pipeline behavior removed the bubble and achieved the expected 1.0 IPC.

Interview point:

> This is a good example of using a performance model like RTL debug: create a tiny directed workload, set caches/TLBs to always-hit, establish an expected throughput, then use pipeout and counters to find timing bubbles.

#### Why This Matters

Knute emphasizes that small pipeline bubbles matter because they multiply across large workloads. A few lost cycles in a recurring path can become a large performance loss over billions of cycles.

The talk also connects performance model and RTL development:

- Use Olympia to explore intended microarchitecture behavior.
- Keep RTL and performance model aligned.
- Use PEvents / traces / instrumentation for comparison.
- Treat the model as a tool for deciding what the hardware should do and validating that the RTL follows that intent.

#### Takeaway For My Interview

This talk gives a strong answer for "how would you use a performance model?"

Use this structure:

```text
1. Start with a workload or directed trace.
2. Run baseline architecture.
3. Inspect IPC, stall counters, occupancy, pipeout/time-series.
4. Change one architectural parameter.
5. Rerun and compare.
6. Identify whether the bottleneck moved.
7. If behavior looks wrong, build a smaller directed test.
8. Use PEvents/pipeout/logs to root-cause timing or resource issues.
```

Good interview wording:

> Olympia's value is the workflow: parameterized architecture, repeatable traces, counters/reports, PEvents, and pipe visualization. You can do sensitivity sweeps, see where stalls move, then reduce a suspicious bottleneck into a directed microbenchmark. That is very similar to how I used performance models at RiVAI to identify LSU bottlenecks and validate design changes.

#### Follow-Up Tutorial Resources

Closest published tutorial/demo video found:

- `RISC-V Performance Modeling SIG Presentation February 10, 2023`
- Link: https://www.youtube.com/watch?v=Go_jgyULeB4
- Length: 52:03
- Description says it introduces Sparta as an event-driven microarchitectural simulation framework, introduces Olympia as an instruction-trace-driven performance model, discusses model status/future plans, and includes a basic performance-analysis demo if time permits.

Written tutorial:

- https://github-wiki-see.page/m/riscv-software-src/riscv-perf-model/wiki/Tutorial
- Covers trace generation, running Olympia, parameters, architecture configs, report generation, Dhrystone reports, Argos/pipeline visualization, and time-series analysis.

#### Trace-Driven Model Limitations

Trace-driven models are good for timing studies, but they do not fully verify functional correctness.

Core idea:

```text
The trace already gives the correct dynamic instruction stream.
The model mainly decides when each instruction moves, stalls, replays, and retires.
```

Code evidence in Olympia:

- STF trace creates each instruction and sets its PC from the trace in `core/InstGenerator.cpp`.
- STF memory accesses come from the trace and set `Inst::target_vaddr_`.
- JSON traces can also directly provide `vaddr`.
- ExecutePipe waits the modeled execution latency and marks destination registers ready; it does not compute architectural result values.
- ROB checks retirement program order, not data-value correctness.

Important implication:

```text
If an execution-driven model computes a wrong load value, that wrong value can affect
future branch targets or future memory addresses.

In Olympia trace-driven mode, future PCs and memory addresses are already in the
golden trace, so that kind of functional error usually does not naturally propagate.
```

So the model can appear functionally correct while still being timing-wrong.

Examples of timing errors that still matter:

- wrong ICache/DCache hit or miss behavior,
- wrong MSHR merge/replay behavior,
- wrong store-to-load forwarding timing,
- wrong memory-order violation replay,
- wrong branch misprediction penalty,
- wrong queue occupancy or backpressure,
- wrong retirement timing.

Fetch-specific limitation:

```text
The trace is per instruction, but hardware fetches instruction bytes/cache lines.
```

Olympia reconstructs block-level fetch by buffering trace instructions, grouping consecutive PCs in the same fetch block, and sending one ICache request for the group. On a miss, ICache sends a linefill request to L2, reloads the line, then replays the pending fetch request.

Code evidence:

- `Fetch::fetchInstruction_()` prefills `ibuf_` from the trace.
- It groups instructions by comparing `PC >> icache_block_shift_`.
- It creates one `MemoryAccessInfo` from the first PC and attaches the whole fetch group.
- `ICache::doArbitration_()` checks hit/miss, queues misses, and schedules a response/replay.

This models useful frontend timing:

- fetch bandwidth,
- fetch buffer occupancy,
- ICache hit/miss latency,
- credits/backpressure,
- linefill and replay timing.

But it is still approximate:

- not fetching raw instruction bytes,
- limited wrong-path ICache pollution,
- limited modeling of bytes fetched but never executed,
- incomplete support for instructions straddling fetch blocks.

Interview wording:

> Trace-driven modeling is powerful for timing studies because it gives a repeatable golden instruction stream, but functional correctness is mostly outsourced to the trace generator. Olympia reconstructs fetch-block and memory timing from that stream, so validation should focus on timing correctness: cache hit/miss behavior, replay, queue occupancy, branch penalties, and cycle-by-cycle correlation against RTL or directed tests.

#### Scheduling Phases And DAG Ordering

Events are not only ordered by simulated time. They are also ordered within a cycle.

Sparta uses scheduling phases so events in the same cycle can be separated into deterministic regions, such as receiving data, updating state, and flushing. This avoids ambiguous update-before-read behavior.

Code evidence:

- `map-sparta-v2.0.21/sparta/sparta/events/SchedulingPhases.hpp`
- `map-sparta-v2.0.21/sparta/src/DAG.cpp`

Exact phase order from the Sparta DAG initialization:

```text
Trigger -> Update -> PortUpdate -> Flush -> Collection -> Tick -> PostTick
```

Important correction:

```text
Flush is before Tick in Sparta's built-in phase order.
```

So if a callback is explicitly scheduled in `SchedulingPhase::Flush`, it runs before normal `SchedulingPhase::Tick` callbacks in that same cycle, unless the events are in different cycles because of delivery delay.

Phase meaning:

```text
Trigger
  Internal framework phase.

Update
  Resource updates happen first. Similar to making registered/pipeline state visible
  before the next logic phase consumes it.

PortUpdate
  Delayed inter-unit messages arrive. Registered port handlers are called.

Flush
  Pipeline flush/control recovery work. Wrong-path entries can be removed and
  already-scheduled later work can be cancelled.

Collection
  Pipeline/resource state is sampled for visualization/reporting.

Tick
  Main model behavior. Sparta comments describe this as the phase where most
  operations or combinational logic occur.

PostTick
  Late events after all Tick events.
```

Inter-unit message means data sent between modeled blocks through Sparta ports:

```text
Fetch DataOutPort -> ICache DataInPort
Decode credits -> Fetch credit port
ROB flush signal -> Fetch/Decode/Rename/Dispatch/Execute/LSU flush ports
```

Hardware analogy:

```text
valid + payload wires between modules
```

Sparta analogy:

```text
typed port send + scheduled receiver callback
```

Why this order:

```text
Update first:
  make resource state current.

PortUpdate next:
  deliver delayed inter-unit messages.

Flush before Tick:
  apply kill/redirect before normal same-cycle behavior uses wrong-path state.

Collection before Tick:
  sample pipeline/resource state at a defined point for debugging/visualization.

Tick:
  run normal component behavior using updated state and delivered inputs.

PostTick:
  run cleanup or late-cycle work after normal behavior.
```

Hardware comparison:

```text
Hardware does not literally have named phases like Flush and Tick.
The analogy is priority logic: flush/kill/redirect has priority over normal valid propagation.
Sparta models that priority by putting Flush before Tick in the same simulated cycle.
```

Example problem phases help avoid:

```text
Cycle 100:
  Event A writes state X.
  Event B reads state X.

Without deterministic ordering, the result depends on callback order.
With phases / ordering, the model defines which one happens first.
```

Sparta can also build DAG ordering between events. The idea is to preserve deterministic dependency order between related events in the same cycle. This is useful in a component model where many units schedule zero-cycle work into the same simulated tick.

Interview wording:

> Sparta scheduling is not just a timestamp queue. Events are ordered by simulated time, scheduling phase, and dependency/DAG order. That matters for cycle models because same-cycle events can otherwise create race-like ambiguity, similar to update-before-read problems in a hand-written tick model.

#### Port Delay And Same-Cycle Phases

Sparta port declarations include a scheduling phase and often a delivery delay.

Example:

```cpp
sparta::DataInPort<uint32_t> in_fetch_queue_credits_{
    &unit_port_set_,
    "in_fetch_queue_credits",
    sparta::SchedulingPhase::Tick,
    0
};
```

The final `0` is the port delivery delay:

```text
sender sends at cycle 10
  -> receiver callback may run at cycle 10
```

Example with delay 1:

```cpp
sparta::DataInPort<MemoryAccessInfoPtr> in_icache_fetch_resp_{
    &unit_port_set_,
    "in_icache_fetch_resp",
    sparta::SchedulingPhase::Tick,
    1
};
```

Meaning:

```text
sender sends at cycle 10
  -> receiver callback runs at cycle 11
```

So a port send is not just a direct function call. It can schedule delivery through the scheduler with a defined phase and delay.

Same-cycle work is ordered by more than cycle number:

```text
(cycle, phase, dependency/order)
```

For example, normal pipeline work may use `Tick`, while flush/redirect delivery may use `Flush`.

Safe interview wording:

> Sparta separates normal tick work and flush/control-recovery work into different scheduling phases, so same-cycle behavior is deterministic. In this Sparta version, the DAG phase order is Trigger, Update, PortUpdate, Flush, Collection, Tick, PostTick. That means a same-cycle Flush-phase callback is ordered before normal Tick-phase callbacks.

The dependency/DAG structure is effectively established during setup when units, ports, and event relationships are built. Runtime dynamically chooses which events are active in a given cycle, but ordering rules are already defined.

#### Event Queue Shape

The scheduler is not just one simple FIFO. Conceptually it is closer to:

```text
time bucket / tick quantum
  -> scheduling phase or group
    -> list/vector of events
```

Simplified picture:

```text
cycle 100:
  group 0: event A, event B
  group 1: event C

cycle 101:
  group 0: event D
```

So the scheduler behaves like a priority queue of callbacks indexed by simulated time, phase/group, and deterministic event order.

#### Callback Syntax Refresher

A callback is a function registered now and called later by another object.

Plain C++ example:

```cpp
#include <functional>
#include <iostream>

void callLater(std::function<void()> cb) {
    cb();
}

void hello() {
    std::cout << "hello\n";
}

int main() {
    callLater(hello);
}
```

Class member callback using a lambda:

```cpp
class DCache {
public:
    void handleRequest() {
        std::cout << "handle request\n";
    }
};

DCache dcache;

auto cb = [&dcache]() {
    dcache.handleRequest();
};

cb();
```

Sparta event callback pattern:

```cpp
sparta::UniqueEvent<> ev_retire_{
    &unit_event_set_,
    "retire_insts",
    CREATE_SPARTA_HANDLER(ROB, retireInstructions_)
};
```

Meaning:

```text
When this event fires, call ROB::retireInstructions_().
```

Sparta port callback with data:

```cpp
in_lsu_lookup_req_.registerConsumerHandler(
    CREATE_SPARTA_HANDLER_WITH_DATA(
        DCache,
        receiveMemReqFromLSU_,
        MemoryAccessInfoPtr
    )
);
```

Meaning:

```text
When data arrives on this port, call:
DCache::receiveMemReqFromLSU_(MemoryAccessInfoPtr req)
```

#### Simple Callback Examples

No-argument callback:

```cpp
#include <iostream>
#include <functional>

void runLater(std::function<void()> callback) {
    callback();
}

void sayHello() {
    std::cout << "hello\n";
}

int main() {
    runLater(sayHello);
}
```

Callback with input parameter:

```cpp
#include <iostream>
#include <functional>

void sendCredit(std::function<void(int)> callback) {
    callback(8);
}

class Fetch {
public:
    void receiveCredit(int credits) {
        std::cout << "received credits = " << credits << "\n";
    }
};

int main() {
    Fetch fetch;

    sendCredit([&fetch](int credits) {
        fetch.receiveCredit(credits);
    });
}
```

Conceptual Sparta equivalent:

```cpp
in_fetch_queue_credits_.registerConsumerHandler(
    CREATE_SPARTA_HANDLER_WITH_DATA(Fetch, receiveFetchQueueCredits_, uint32_t)
);
```

is like:

```cpp
register_callback([this](uint32_t credits) {
    this->receiveFetchQueueCredits_(credits);
});
```

#### Simple Delayed Callback / Event Scheduling

Core idea:

```text
event = callback + target cycle
```

Toy event scheduler:

```cpp
#include <iostream>
#include <functional>
#include <queue>

struct Event {
    int cycle;
    std::function<void()> callback;
};

int main() {
    int current_cycle = 0;
    std::queue<Event> event_queue;

    event_queue.push({
        3,
        []() {
            std::cout << "cache response returns\n";
        }
    });

    while (current_cycle <= 5) {
        if (!event_queue.empty() && event_queue.front().cycle == current_cycle) {
            event_queue.front().callback();
            event_queue.pop();
        }

        current_cycle++;
    }
}
```

Sparta equivalent:

```cpp
ev_respond_.preparePayload(req)->schedule(cache_latency_);
```

Meaning:

```text
Call the response callback after cache_latency simulated cycles.
```

#### C++ Syntax To Review Later

This repo uses several C++ constructs that are worth reviewing systematically after the structural walkthrough.

Backlog:

- Function pointer vs member-function pointer.
- Template syntax, especially explicit template arguments.
- Macro expansion and token stringification with `#`.
- Constructor initializer lists.
- `std::unique_ptr`, `std::shared_ptr`, and Sparta shared pointers.
- References such as `const T &`.
- Lambdas and captures.
- `auto`, `decltype`, and type aliases.

Current example to revisit:

```cpp
#define CREATE_SPARTA_HANDLER_WITH_DATA(clname, meth, dataT) \
    sparta::SpartaHandler::from_member_1<clname, &clname::meth, dataT> \
        (this, #clname"::"#meth"("#dataT")")
```

Example expansion:

```cpp
CREATE_SPARTA_HANDLER_WITH_DATA(DCache, receiveReq_, MemoryAccessInfoPtr)
```

becomes conceptually:

```cpp
sparta::SpartaHandler::from_member_1<
    DCache,
    &DCache::receiveReq_,
    MemoryAccessInfoPtr
>(
    this,
    "DCache::receiveReq_(MemoryAccessInfoPtr)"
)
```

Key points:

- `&DCache::receiveReq_` is a pointer to a member function, not a call.
- `this` is the current object instance to call the member function on.
- `#clname`, `#meth`, and `#dataT` turn macro tokens into strings.
- The debug string is for readability; the real callable target is the member-function pointer.

### Interview Wording

Use this phrasing:

> My previous model was more manually cycle-driven: the core tick called pipeline stages in reverse order and used explicit pipeline-register classes to separate current and next state. Sparta/Olympia is more event-driven. The global scheduler owns simulated time, and each unit registers callbacks on ports or events. A unit schedules local events when data, credits, or responses arrive. So the timing model is still cycle-accurate, but control is decentralized through ports, events, buffers, and counters instead of one hand-written backward pipeline loop.

### Olympia One-Minute Structural Summary

Olympia is built in layers:

1. Sparta framework:
   - Provides tree hierarchy, parameters, ports, events, scheduler, counters, reports, PEvents, and pipeout.
   - Model units are Sparta `Unit`s connected by ports.

2. Olympia simulator wrapper:
   - `main.cpp` parses CLI/config.
   - `OlympiaSim.cpp` builds, configures, and binds the tree.
   - `CPUFactory.cpp` and `CPUTopology.cpp` instantiate CPU/core units and connect ports.

3. Trace-driven instruction source:
   - Fetch uses `InstGenerator`.
   - JSON/STF trace gives the dynamic instruction stream.
   - Mavis decodes instructions and attaches uarch metadata.

4. Pipeline model:
   - Fetch groups trace instructions into ICache block requests.
   - Decode mostly queues/generated uops because decode already happened through Mavis.
   - Rename maps ARF to PRF and manages freelist/scoreboard.
   - Dispatch sends ops to IssueQueue, LSU, and ROB.
   - IssueQueue waits on scoreboard readiness.
   - ExecutePipe models latency and wakes dependents.
   - ROB retires in order.

5. Memory system:
   - LSU has separate issue/replay/store-buffer logic.
   - DCache/ICache use `CacheFuncModel`.
   - L2 arbitrates I/D misses.
   - BIU/MSS model lower-memory service with simple fixed latency.

6. Debug/profiling:
   - Counters/reports show aggregate bottlenecks.
   - PEvents and pipeout show per-instruction timing.
   - YAML arch files enable sensitivity sweeps.

Interview wording:

> Olympia is a trace-driven, Sparta-based RISC-V performance model. Sparta gives the simulation infrastructure: event scheduler, unit hierarchy, ports, parameters, counters, and reports. Olympia defines the CPU microarchitecture on top: fetch, decode, rename, dispatch, issue, execute, ROB, LSU, caches, L2, and memory-service models. The dynamic instruction stream comes from JSON/STF traces, Mavis decodes instructions and attaches uarch metadata, and the model estimates timing through configurable pipeline resources and event scheduling. Its strength is fast, repeatable architecture exploration and profiling; its weakness is limited wrong-path and functional correctness fidelity compared with execution-driven simulation.

## Part 2 — C++ Coding and Simulator-C++ Review

Source: C++ coding prep notes previously kept as `c++coding/PM_CPP.md`.

### Performance Modeling C++ Prep — Qualcomm CPU Performance Modeling

#### Role-Specific Coding Assumption

This is not primarily a LeetCode interview. For a CPU performance modeling role, C++ questions are most likely to test whether I can write and reason about simulator-quality C++:

- data structures for queues, buffers, caches, predictors, MSHRs, and LSU state;
- object lifetime and ownership in a long-running simulator;
- callback/event-driven code;
- clean APIs for configurable microarchitecture models;
- correctness under edge cases, not just passing a toy example.

The job description emphasizes C/C++, CPU architecture blocks, writing and maintaining CPU architectural performance model features, workload bottleneck analysis, and self-guided design-alternative studies. The interviewer background we have prepared for is LSU/performance-modeling heavy, so C++ basics should be practiced through microarchitecture examples whenever possible.

#### Part 1 — C++ Basics Refresh, 45-60 Min

Goal: answer these crisply, then connect them to performance-modeling code.

##### A. Object Size, Alignment, and Memory Layout

Expected questions:

- What does `sizeof` return for a struct with mixed field types?
- Why can `sizeof(struct)` be larger than the sum of its fields?
- How does alignment/padding affect arrays of structs?
- What is the size of a pointer on a 64-bit machine?
- What is the difference between `sizeof(array)` and `sizeof(pointer)`?
- What happens to object size when a class has one or more virtual functions?
- Why might a simulator prefer structure-of-arrays over array-of-structures for large traces or counters?

What interviewer is testing:

- Low-level memory layout intuition.
- Whether I can avoid accidental memory bloat in large simulation structures.
- Whether I understand why cache/model data layout matters.

Microarch connection:

- Cache lines, ROB entries, MSHR entries, load/store queue entries, and trace records may be stored in large vectors. Padding and ownership choices can matter.

Practice examples:

```cpp
struct B {
    char c;
    double d;
    int x;
}; // typically 24 bytes

struct C {
    char c;
    int x;
    double d;
}; // typically 16 bytes

struct D {
    double d;
    int x;
    char c;
}; // typically 16 bytes
```

Key lesson:

- A 64-bit machine does not mean every field is padded to 64 bits.
- Each type has its own size and alignment: `char` usually 1 byte, `int` usually 4 bytes, `double` usually 8 bytes.
- Padding depends on the current byte offset. For each field, check whether the current offset satisfies that field's alignment requirement; if not, insert padding.
- The total struct size is padded to a multiple of the largest alignment requirement in the struct. This tail padding matters for arrays of structs, so every array element starts at a correctly aligned address.
- Field order can reduce padding. `B` wastes 7 bytes before `double` and 4 bytes at the end, so it becomes 24 bytes. `C` places `int` before `double`, so it becomes 16 bytes.
- `D` is also 16 bytes: `double` starts at offset 0, `int` at offset 8, `char` at offset 12, then 3 bytes of tail padding make the whole struct a multiple of 8.

Virtual function size examples:

```cpp
struct F {
    int x;
    virtual void foo() {}
}; // typically 16 bytes on a 64-bit machine

struct G {
    int x;
    virtual void foo() {}
    virtual void bar() {}
}; // typically also 16 bytes on a 64-bit machine
```

Key lesson:

- Member function code is not stored inside every object.
- A class with one or more virtual functions usually gives each object one hidden `vptr`.
- The `vptr` points to a class-level `vtable`, which stores function addresses for the virtual functions.
- Adding the first virtual function usually adds one hidden pointer to each object.
- Adding more virtual functions usually does not add more per-object pointers; it adds more entries to the shared vtable.
- For `F`: hidden `vptr` is usually 8 bytes, `int x` is 4 bytes, and 4 bytes of padding make the object 16 bytes.
- For `G`: there is still usually only one `vptr`, so the object is also typically 16 bytes.

Dynamic dispatch mental model:

```cpp
struct Base {
    virtual void foo() {}
    virtual void bar() {}
};

struct Derived : Base {
    void foo() override {}
};
```

Conceptual vtables:

```text
Base vtable:
  slot 0 -> Base::foo
  slot 1 -> Base::bar

Derived vtable:
  slot 0 -> Derived::foo
  slot 1 -> Base::bar
```

When calling `p->foo()` through a `Base*`, the compiler already knows that `foo` is slot 0. At runtime, the object's hidden `vptr` points to the actual class vtable, so the dispatch is conceptually:

```text
object -> vptr -> actual class vtable -> slot 0 -> function implementation
```

The runtime does not search for the class. The `vptr` identifies the actual runtime type's vtable, and the compile-time slot index identifies which virtual function to call.

##### B. `const`, References, and Pointers

Expected questions:

- What is the difference between `const int* p`, `int* const p`, and `const int* const p`?
- When should I pass by value vs `const T&` vs pointer?
- What does it mean for a member function to be `const`?
- Can a `const` member function modify a field? What is `mutable`?
- What is the difference between reference and pointer?
- Can a reference be null? Can it be reseated?

What interviewer is testing:

- API discipline.
- Avoiding unnecessary copies of large model objects.
- Clear ownership vs non-ownership signaling.

Microarch connection:

- A simulator often passes instruction records, memory requests, and cache entries around. Use `const T&` for read-only inspection, pointer/smart pointer when lifetime or nullability matters.

Practice examples:

```cpp
const int* p1;
int* const p2 = nullptr;
const int* const p3 = nullptr;
```

Key lesson:

- `const int* p1` means pointer to const int. The pointer can move, but the value cannot be modified through `p1`.
- `int* const p2` means const pointer to int. The pointer cannot move, but the value can be modified through `p2`.
- `const int* const p3` means const pointer to const int. The pointer cannot move, and the value cannot be modified through `p3`.
- If `const` is before the `*`, the pointed-to data is const.
- If `const` is after the `*`, the pointer itself is const.

References vs pointers:

```cpp
int a = 10;
int& r = a;
int* p = &a;
```

- `r` is a reference to `a`; it is an alias for the same object.
- Updating `r` updates `a`, and updating `a` is visible through `r`.
- A reference normally cannot be null and cannot be reseated after initialization.
- `p` is a pointer storing the address of `a`.
- A pointer can be null, can be reseated to another address, and must be dereferenced with `*p` to access the value.

Reference assignment example:

```cpp
int a = 10;
int b = 20;

int& r = a;
r = b;
```

Result:

```text
a = 20
b = 20
r = 20
```

Key lesson: `r = b` does not reseat `r` to refer to `b`. It assigns the value of `b` into the object that `r` already aliases, which is `a`.

Pointer reseating example:

```cpp
int a = 10;
int b = 20;

int* p = &a;
p = &b;
*p = 30;
```

Result:

```text
a = 10
b = 30
*p = 30
```

Key lesson: assigning to a pointer changes where it points. Dereferencing the pointer with `*p` modifies the pointed-to object.

Pass-by-value vs reference vs pointer:

```cpp
void f1(int x) {
    x = 100;
}

void f2(int& x) {
    x = 100;
}

void f3(int* x) {
    *x = 100;
}
```

If `a`, `b`, and `c` all start as `1`, then after `f1(a)`, `f2(b)`, and `f3(&c)`:

```text
a = 1
b = 100
c = 100
```

Key lesson: pass-by-value modifies only a local copy. Pass-by-reference modifies the caller's object. Passing a pointer also allows modifying the caller's object through `*x`.

Choosing `const T&`, `T&`, and `T*`:

```cpp
struct Inst {
    uint64_t pc;
    uint32_t opcode;
    uint64_t src1;
    uint64_t src2;
};

void readOnly(const Inst& inst); // no copy, cannot modify
void update(Inst& inst);         // no copy, can modify caller's object
void maybeNull(Inst* inst);      // can modify and can represent nullptr
```

Key lesson:

- Use `const T&` when the function only reads a non-trivial object and copying would be wasteful.
- Use `T&` when the object is required and the function intentionally mutates it.
- Use `T*` when `nullptr` is a meaningful state, when reseating is needed, or when the API wants explicit address/ownership semantics.
- In a performance model, instruction records, memory requests, and cache metadata are often passed by `const&` in read-only hot paths to avoid unnecessary copies.

##### C. `static`

Expected questions:

- What is a local static variable?
- What is a static class member?
- What is a static member function?
- What is the difference between static storage duration and stack/heap lifetime?
- What does `static` at file scope mean in C++?
- What are initialization-order risks for static/global objects?

What interviewer is testing:

- Lifetime and shared-state understanding.
- Whether I avoid hidden global state in simulator code.

Microarch connection:

- Static tables can be useful for opcode metadata or replacement-policy lookup, but simulator state like counters, queues, and predictors should usually be instance state.

Practice examples:

```cpp
void f() {
    static int count = 0;
    count++;
    std::cout << count << "\n";
}
```

Calling `f()` three times prints:

```text
1
2
3
```

Key lesson:

- A local static variable is initialized once and keeps its value across function calls.
- It has static lifetime, but local scope: only the function can access the name.
- Without `static`, a normal local variable is re-created on every function call.

Static class member example:

```cpp
struct Counter {
    static int total;
    int local;

    Counter() {
        total++;
        local = 0;
    }
};

int Counter::total = 0;
```

Key lesson:

- `Counter::total` belongs to the class, not to each object.
- All `Counter` objects share one `total`.
- Each object has its own `local`.
- `static` data members do not contribute to `sizeof(Counter)`.
- Constructor/function code also does not contribute to `sizeof(Counter)`; code lives in the program text section.

Size examples:

```cpp
struct Counter {
    static int total;
    int local;
}; // typically sizeof(Counter) == 4

struct Counter2 {
    static int total;
    int local;
    virtual void foo() {}
}; // typically sizeof(Counter2) == 16 on a 64-bit machine
```

Key lesson:

- `Counter` is typically 4 bytes because only `local` is stored in each object.
- `Counter2` is typically 16 bytes because the virtual function causes a hidden 8-byte `vptr`, plus 4-byte `local`, plus 4 bytes of padding.
- The static member `total` is stored separately in both cases.

Static member function example:

```cpp
struct Foo {
    static int count;
    int x;

    static void reset() {
        count = 0; // OK
        // x = 0;  // Error
    }
};
```

Key lesson:

- A static member function has no `this` pointer.
- It can access static class state directly.
- It cannot access non-static object fields unless an object is passed in.
- A non-static member function can access both `count` and `x`, because it has `this`.

##### D. Virtual Functions, Vtable, and Polymorphism

Expected questions:

- What is a virtual function?
- What is a vtable/vptr conceptually?
- Why should a base class with virtual functions usually have a virtual destructor?
- What is object slicing?
- Difference between function overloading and overriding?
- When would I use an abstract base class?

What interviewer is testing:

- Ability to design simulator components with clean interfaces.
- Avoiding lifetime bugs through base pointers.

Microarch connection:

- Replacement policies, branch predictors, trace readers, and cache models are natural polymorphic interfaces.

Virtual destructor:

```cpp
struct Base {
    ~Base() {
        std::cout << "Base destructor\n";
    }
};

struct Derived : Base {
    ~Derived() {
        std::cout << "Derived destructor\n";
    }
};

Base* p = new Derived();
delete p; // problem: Base destructor is not virtual
```

Key lesson:

- Deleting a derived object through a base pointer requires a virtual base destructor.
- Without a virtual destructor, behavior is undefined; in practice, the derived destructor may be skipped.
- Fix:

```cpp
struct Base {
    virtual ~Base() = default;
};
```

Constructor/destructor order:

```cpp
struct Base {
    Base() { std::cout << "Base ctor\n"; }
    virtual ~Base() { std::cout << "Base dtor\n"; }
};

struct Derived : Base {
    Derived() { std::cout << "Derived ctor\n"; }
    ~Derived() { std::cout << "Derived dtor\n"; }
};

Base* p = new Derived();
delete p;
```

Print order:

```text
Base ctor
Derived ctor
Derived dtor
Base dtor
```

Key lesson:

- Constructors run from base to derived.
- Destructors run in reverse order, from derived to base.
- The base part must exist before the derived constructor runs.
- The derived destructor runs first while the base part is still valid.

Object slicing:

```cpp
struct Base {
    virtual void foo() {
        std::cout << "Base\n";
    }
};

struct Derived : Base {
    int extra = 42;
    void foo() override {
        std::cout << "Derived\n";
    }
};

void callByValue(Base b) {
    b.foo();
}

Derived d;
callByValue(d); // prints Base
```

Key lesson:

- Passing a derived object by value to a base parameter slices off the derived part.
- The parameter becomes a real `Base` object, so virtual dispatch uses the base vtable.
- For polymorphic objects, pass by reference or pointer:

```cpp
void callByRef(Base& b) {
    b.foo(); // prints Derived when passed a Derived object
}
```

Pure virtual vs non-pure virtual:

```cpp
struct ReplacementPolicy {
    virtual int chooseVictim() = 0;
};
```

Key lesson:

- `= 0` means pure virtual.
- A class with a pure virtual function is abstract and cannot be instantiated directly.
- Derived classes must implement the pure virtual function to become concrete.
- `override` is optional but strongly recommended because it catches signature mismatches.

```cpp
struct LRU : ReplacementPolicy {
    int chooseVictim() override {
        return 0;
    }
};
```

Non-pure virtual:

```cpp
struct Predictor {
    virtual bool predict(uint64_t pc) {
        return false;
    }
};
```

Key lesson:

- A non-pure virtual function has a default implementation.
- Derived classes may override it but do not have to.
- If a virtual function is declared but not pure and not defined anywhere, code that needs it can fail at link time.

Overloading vs overriding:

```cpp
struct Base {
    virtual void run(int x) {
        std::cout << "Base int\n";
    }
};

struct Derived : Base {
    void run(double x) {
        std::cout << "Derived double\n";
    }
};

Base* p = new Derived();
p->run(1); // prints Base int
```

Key lesson:

- Overriding requires the same function signature.
- `Derived::run(double)` does not override `Base::run(int)`.
- Calls through a base pointer dispatch only through the virtual interface declared in the base class.
- `override` would catch this mismatch if used.

##### E. Constructors, Destructors, RAII, Rule of 3/5/0

Expected questions:

- What is RAII?
- Constructor initializer list vs assignment inside constructor body?
- When do I need a destructor?
- What are copy constructor and copy assignment?
- What are move constructor and move assignment?
- What is the Rule of 3 / Rule of 5 / Rule of 0?

What interviewer is testing:

- Whether I can write reliable C++ without leaks.
- Whether I understand object lifetime under container movement/copying.

Microarch connection:

- Simulator objects own buffers, files, counters, and resources. RAII is the clean way to manage trace readers, output files, and dynamically allocated structures.

RAII:

RAII means Resource Acquisition Is Initialization.

Key lesson:

- Tie resource lifetime to object lifetime.
- Acquire the resource in the constructor.
- Release the resource in the destructor.
- This prevents leaks on early return or exceptions.

Bad cleanup example:

```cpp
void runSim() {
    FILE* fp = fopen("trace.txt", "r");

    if (someError()) {
        return; // bug: fclose(fp) is skipped
    }

    fclose(fp);
}
```

RAII-style fix:

```cpp
void runSim() {
    std::ifstream file("trace.txt");

    if (someError()) {
        return; // OK: file closes when leaving scope
    }
}
```

Mutex example:

```cpp
std::mutex m;
int counter = 0;

void work() {
    std::lock_guard<std::mutex> lock(m);
    counter++;
} // lock_guard destructor unlocks m
```

Key lesson:

- `std::mutex m` is the shared lock object.
- `std::lock_guard<std::mutex> lock(m)` locks the mutex for the current lexical scope.
- Each thread creates its own `lock_guard`, but they contend for the same mutex.
- Without RAII, early return can skip `unlock()` and leave the mutex locked.

Rule of 3 / 5 / 0:

```cpp
class Buffer {
public:
    Buffer(size_t n) {
        size_ = n;
        data_ = new int[n];
    }

    ~Buffer() {
        delete[] data_;
    }

private:
    size_t size_;
    int* data_;
};
```

Problem:

```cpp
Buffer a(10);
Buffer b = a; // default copy is shallow
```

Key lesson:

- The compiler-generated copy constructor copies the pointer value, not the owned array.
- Both objects point to the same heap allocation.
- Both destructors later call `delete[]` on the same pointer, causing double free.

Copy assignment problem:

```cpp
Buffer a(10);
Buffer b(20);
b = a;
```

Key lesson:

- Default assignment shallow-copies `a.data_` into `b.data_`.
- `b` leaks its old allocation.
- Then `a` and `b` share the same allocation, causing double free later.

Deep copy:

```cpp
Buffer(const Buffer& other) {
    size_ = other.size_;
    data_ = new int[size_];
    for (size_t i = 0; i < size_; i++) {
        data_[i] = other.data_[i];
    }
}
```

Move constructor:

```cpp
Buffer(Buffer&& other) {
    size_ = other.size_;
    data_ = other.data_;
    other.size_ = 0;
    other.data_ = nullptr;
}
```

Key lesson:

- Copy duplicates the owned resource.
- Move transfers ownership of the resource from an expiring object.
- Rule of 3: if I define destructor, copy constructor, or copy assignment, I likely need all three.
- Rule of 5: for movable resource-owning classes, also define move constructor and move assignment.
- Rule of 0: prefer standard RAII containers so I do not manually define any of them.

Rule of 0 version:

```cpp
class Buffer {
public:
    Buffer(size_t n) : data_(n) {}

private:
    std::vector<int> data_;
};
```

Key lesson:

- `Buffer(size_t n) : data_(n) {}` uses a constructor initializer list.
- `data_(n)` constructs the vector with `n` elements.
- `std::vector` owns memory and handles destructor, copy, and move correctly.

Smart pointers:

```cpp
auto l1 = std::make_unique<Cache>();
auto inst = std::make_shared<Inst>();
```

Key lesson:

- `std::unique_ptr<T>` means single ownership. It cannot be copied, only moved.
- `std::shared_ptr<T>` means shared ownership. Copying it increments the reference count.
- The object owned by a `shared_ptr` is destroyed when the last owning `shared_ptr` goes away.
- Use `unique_ptr` by default for clear ownership, such as a core owning a cache.
- Use `shared_ptr` only when shared lifetime is real, such as ROB/IQ/LSQ all referring to the same instruction object.

`make_unique` syntax:

```cpp
auto l1 = std::make_unique<Cache>(64, 4, 64);
```

Key lesson:

- Angle brackets specify the type to create: `Cache`.
- Parentheses pass constructor arguments: `64, 4, 64`.
- Return type is `std::unique_ptr<Cache>`.

Ownership examples:

```cpp
std::unique_ptr<Cache> a = std::make_unique<Cache>();
std::unique_ptr<Cache> b = std::move(a);
```

After move:

```text
b owns the Cache
a is valid but empty
a.get() == nullptr
```

Non-owning raw pointer:

```cpp
std::unique_ptr<Cache> a = std::make_unique<Cache>();
Cache* raw = a.get();
```

Key lesson:

- `a` owns the `Cache`.
- `raw` observes the object but must not delete it.
- `.get()` returns a non-owning raw pointer.

Shared pointer reference count:

```cpp
std::shared_ptr<Inst> a = std::make_shared<Inst>();
std::shared_ptr<Inst> b = a;
std::shared_ptr<Inst> c = b;
b.reset();
```

Key lesson:

- The object is not destroyed after `b.reset()` because `a` and `c` still own it.
- Conceptually the reference count goes from 3 to 2.

##### F. Smart Pointers and Ownership

Expected questions:

- When should I use `std::unique_ptr`?
- When should I use `std::shared_ptr`?
- What is the cost/risk of `shared_ptr`?
- What is a dangling pointer?
- What is a memory leak?
- Why avoid raw owning pointers?

What interviewer is testing:

- Ownership clarity.
- Whether I can write production C++ rather than contest-style C++ only.

Microarch connection:

- Instructions and memory requests may be referenced by several queues at once. Shared ownership can be convenient, but it must be intentional.

##### G. STL Containers and Iterator Invalidation

Expected questions:

- `vector` vs `deque` vs `list`: when to use each?
- What is iterator invalidation?
- What happens to pointers/references when `vector` grows?
- `map` vs `unordered_map`?
- `priority_queue` vs `queue`?
- How would you implement an LRU cache in C++?
- How would you implement a ring buffer?

What interviewer is testing:

- Data-structure choice and complexity.
- Whether I can build simulator queues cleanly.

Microarch connection:

- `vector` is good for dense storage and sweeps.
- `deque` is useful for push/pop at both ends with stable-ish references.
- `list + unordered_map` is classic for LRU.
- Ring buffers map naturally to hardware queues.

Container choices for performance models:

- Cache sets with fixed ways: `std::vector<CacheLine>` or `std::vector<std::vector<CacheLine>>`.
  - Dense indexed structure; flat vector `lines[set * ways + way]` is often efficient.
- ROB-like FIFO: vector-backed ring buffer or `std::deque`.
  - Fixed hardware capacity maps well to `std::vector<Entry>` plus head/tail/count.
- LRU replacement: `std::list<Key> + std::unordered_map<Key, iterator>`.
  - List tracks recency order. Hash map gives fast key-to-list-node lookup.
- Branch predictor table: `std::vector<Counter>`.
  - Dense table indexed by PC-derived bits.
- MSHR line-address lookup: `std::unordered_map<LineAddr, MSHREntry>` or vector plus scan.
  - Hash map is good for fast same-line merge lookup; vector is better if modeling finite-entry CAM behavior.

`std::list` and `std::unordered_map` for LRU:

```cpp
std::list<uint64_t> lru;
std::unordered_map<uint64_t, std::list<uint64_t>::iterator> pos;
```

Key lesson:

- `std::list` is a doubly linked list. It supports O(1) erase if I already have an iterator, and O(1) push/pop at front/back.
- `std::unordered_map` is a hash table mapping key to value. It gives average O(1) lookup but does not maintain sorted key order.
- `std::map` is ordered by key and usually implemented as a tree, with O(log n) lookup.
- For LRU, sorted key order is useless; recency order is maintained by the list.

LRU hit example:

```cpp
auto it = pos.find(addr);
if (it != pos.end()) {
    lru.erase(it->second);
    lru.push_front(addr);
    pos[addr] = lru.begin();
}
```

Key lesson:

- `pos.find(addr)` returns an iterator to a hash-map entry.
- A map entry has `first` and `second`: `first` is the key, `second` is the value.
- Here `it->first` is the address, and `it->second` is a list iterator pointing to that address's node in the LRU list.
- After erasing the old node and pushing a new front node, update the map to point to `lru.begin()`.

Hardware CAM modeling:

```cpp
for (auto& e : entries) {
    if (e.valid && e.tag == search_tag) {
        // match
    }
}
```

Key lesson:

- Hardware CAM compares a search key against many entries in parallel.
- In a performance model, `std::vector<Entry>` plus an explicit scan is often more hardware-faithful than `unordered_map`.
- Scanning preserves finite entries, age ordering, comparator activity, replacement priority, and timing behavior.
- `unordered_map` is useful as a functional shortcut or acceleration structure, but it hides comparator behavior.
- `auto& e` uses a reference to the real vector entry, avoiding copy and allowing modification.
- Use `const auto& e` for read-only scans.

`std::queue`:

- `std::queue` is a container adapter for pure FIFO behavior.
- It supports `push`, `pop`, `front`, `empty`, and `size`.
- It does not support iteration or random access.
- It is fine for simple request/response FIFOs.
- It is usually not enough for ROB/IQ/LSQ because those need scanning, indexing, wakeup, flush, or middle-entry updates.

Issue queue container choice:

- Prefer `std::vector<IQEntry>` and explicit scan/select.
- `std::priority_queue` is tempting by name, but less suitable because readiness changes after insertion and arbitrary flush/invalidation is common.
- `priority_queue` is useful when priority is mostly fixed at insertion, such as an event queue ordered by cycle.

Iterator and pointer invalidation:

```cpp
std::vector<int> v = {1, 2, 3};
int* p = &v[0];
v.push_back(4);
```

Key lesson:

- `std::vector` stores elements contiguously.
- `push_back` can reallocate if size exceeds capacity.
- Reallocation invalidates pointers, references, and iterators to vector elements.
- `reserve(n)` preallocates capacity for at least `n` elements, but does not create elements.
- `resize(n)` changes the vector size and creates/destroys elements.

Erase invalidation:

```cpp
std::vector<int> v = {1, 2, 3, 4};
int* p = &v[2];
v.erase(v.begin());
```

Key lesson:

- Erasing from a vector shifts later elements left.
- Pointers/references/iterators at or after the erase point are invalidated.
- For fixed hardware structures, use fixed-size vector storage and avoid erase/reallocation.
- For ROB/IQ/LSQ, indices or index-plus-generation handles are often safer than raw pointers because entries are reused after retire/flush.

Vector-backed ring buffer for ROB:

```cpp
std::vector<ROBEntry> rob(capacity);
size_t head = 0;
size_t tail = 0;
size_t count = 0;
```

Key lesson:

- A vector-backed ring buffer gives stable indexed storage and hardware-like fixed capacity.
- Use head/tail/count for allocation and retirement.
- This keeps STL-managed storage while modeling hardware ring behavior.

##### H. Lambdas, Callbacks, and Function Pointers

Expected questions:

- What is a callback?
- Function pointer vs `std::function` vs lambda?
- How does lambda capture by value vs reference work?
- What is a member-function pointer?
- What can go wrong if a callback captures a reference to a local variable?
- How would you implement a tiny event queue with delayed callbacks?

What interviewer is testing:

- Comfort with event-driven simulator code.
- Ability to reason about delayed execution and object lifetime.

Microarch connection:

- Sparta-style modeling is callback/event driven. Ports deliver payloads to handlers, and events schedule callbacks at future simulated cycles.

Lambda basics:

```cpp
auto sayHello = []() {
    std::cout << "hello\n";
};

sayHello();
```

Key lesson:

- A lambda is an inline anonymous callable object.
- It can be stored in a variable, passed to a function, stored in `std::function`, stored in a container, or used by STL algorithms.
- Conceptually, the compiler turns a lambda into a small class with `operator()`.

Lambda syntax:

```cpp
[capture_list](parameter_list) {
    function_body
}
```

Example:

```cpp
[addr]() {
    onCacheResponse(addr);
}
```

Meaning:

- capture `addr`;
- take no arguments when called;
- run body `{ onCacheResponse(addr); }`.

Callback wrapper:

```cpp
void onCacheResponse(uint64_t addr) {
    std::cout << "cache response for addr 0x"
              << std::hex << addr << "\n";
}

void runLater(std::function<void()> cb) {
    cb();
}

uint64_t addr = 0x1000;

runLater([addr]() {
    onCacheResponse(addr);
});
```

Key lesson:

- `runLater` takes a callback as an argument.
- The lambda is the callback object passed into `runLater`.
- `std::function<void()>` means the callback takes no arguments and returns nothing.
- The lambda captures `addr` so the callback carries its own saved context.
- This wraps a function that needs an argument into a no-argument callback.

Delayed event example:

```cpp
struct Event {
    int ready_cycle;
    std::function<void()> cb;
};

std::vector<Event> events;
int cycle = 0;
uint64_t addr = 0x1000;

events.push_back({
    cycle + 2,
    [addr]() {
        onCacheResponse(addr);
    }
});

for (cycle = 1; cycle <= 3; cycle++) {
    for (auto& ev : events) {
        if (ev.ready_cycle == cycle) {
            ev.cb();
        }
    }
}
```

Key lesson:

- The event stores `ready_cycle` and a callback.
- At the target cycle, the scheduler calls `ev.cb()`.
- The scheduler does not know about `addr`; the lambda stores `addr` internally.

Capture by value vs reference:

```cpp
int x = 10;

auto cb1 = [x]() {
    std::cout << x << "\n";
};

auto cb2 = [&x]() {
    std::cout << x << "\n";
};

x = 20;

cb1(); // prints 10
cb2(); // prints 20
```

Key lesson:

- `[x]` captures by value: stores a snapshot.
- `[&x]` captures by reference: uses the original variable.
- Reference capture is dangerous for delayed callbacks if the referenced local variable dies before the callback runs.

Dangerous delayed reference capture:

```cpp
void sendRequest(Scheduler& sched) {
    uint64_t addr = 0x1000;

    sched.schedule(5, [&addr]() {
        onCacheResponse(addr);
    });
}
```

Key lesson:

- `addr` is local to `sendRequest`.
- The callback runs after `sendRequest` returns.
- `[&addr]` leaves a dangling reference.
- Fix by capturing by value:

```cpp
sched.schedule(5, [addr]() {
    onCacheResponse(addr);
});
```

Member-function callback:

```cpp
Fetch fetch;
Scheduler sched;
uint64_t addr = 0x1000;

sched.schedule(3, [&fetch, addr]() {
    fetch.receiveCacheResponse(addr);
});
```

Key lesson:

- `receiveCacheResponse` is a non-static member function, so it must be called on a specific object.
- Capture `fetch` by reference to use the real simulator unit, not a copy.
- Capture `addr` by value because it is small request metadata needed later.
- Capturing `fetch` by reference is safe only if `fetch` outlives the callback.

Capturing `this`:

```cpp
class Fetch {
public:
    void sendRequest(Scheduler& sched, uint64_t addr) {
        sched.schedule(3, [this, addr]() {
            receiveCacheResponse(addr);
        });
    }

    void receiveCacheResponse(uint64_t addr) {
        std::cout << "response 0x" << std::hex << addr << "\n";
    }
};
```

Key lesson:

- `[this, addr]` captures the current object pointer and a copy of `addr`.
- Inside the lambda, `receiveCacheResponse(addr)` means `this->receiveCacheResponse(addr)`.
- This is equivalent in spirit to capturing `&fetch` outside the class.
- Capturing `this` is safe only if the object is still alive when the callback runs.

Static member handler:

```cpp
class Fetch {
public:
    static void receiveCacheResponse(uint64_t addr) {
        std::cout << "response 0x" << std::hex << addr << "\n";
    }
};

sched.schedule(3, [addr]() {
    Fetch::receiveCacheResponse(addr);
});
```

Key lesson:

- Static member functions belong to the class, not an object.
- They can be called with `ClassName::function`.
- They have no `this` pointer.
- They cannot directly access non-static object state.
- Simulator handlers are usually non-static because they update unit state.

##### I. Templates, Macros, and Type Aliases

Expected questions:

- What is a template function/class?
- What is the meaning of `std::vector<int>` and `Foo<T>` syntax?
- What does `using Alias = ...` do?
- What is a macro?
- What does `#x` do inside a macro?
- What is the difference between compile-time and runtime polymorphism?

What interviewer is testing:

- Whether I can read framework-heavy C++ code.

Microarch connection:

- Sparta/Olympia uses templates, type aliases, and handler macros heavily. I do not need to be a template metaprogramming expert, but I need to read and explain the syntax.

##### J. Integer Types, Bit Manipulation, and Address Decoding

Expected questions:

- Signed vs unsigned pitfalls?
- What is `size_t`?
- How do shifts behave?
- How do you compute cache index/tag/block offset?
- How do you align an address down to cache-line boundary?
- How do you test if a number is power of two?
- How do you build a bit mask?

What interviewer is testing:

- Low-level correctness in cache/predictor/address code.

Microarch connection:

- Cache model, branch predictor, MSHR, store-to-load forwarding, and trace parsing all need address/bit manipulation.

Cache address decode:

For:

```text
line size = 64 bytes
number of sets = 128
address = 0x12345678
```

Key lesson:

- 64-byte line means 6 offset bits: bits `[5:0]`.
- 128 sets means 7 index bits: bits `[12:6]`.
- Tag starts at bit 13: bits `[31:13]` for a 32-bit address.

```cpp
uint64_t addr = 0x12345678;

uint64_t offset = addr & ((1ULL << 6) - 1);
uint64_t index  = (addr >> 6) & ((1ULL << 7) - 1);
uint64_t tag    = addr >> (6 + 7);
```

Align address down to cache-line base:

```cpp
uint64_t line_addr = addr & ~(line_size - 1);
```

For power-of-two line size, this clears the low offset bits.

Power-of-two check:

```cpp
bool isPowerOfTwo(uint64_t x) {
    return x != 0 && (x & (x - 1)) == 0;
}
```

Key lesson:

- A power-of-two number has exactly one bit set.
- `x & (x - 1)` clears the lowest set bit.
- The `x != 0` guard is required because zero is not a power of two.

Low-bit mask generation:

```cpp
uint64_t lowMask(unsigned n) {
    if (n == 0) {
        return 0;
    }
    if (n >= 64) {
        return ~0ULL;
    }
    return (1ULL << n) - 1;
}
```

Key lesson:

- Basic formula is `(1ULL << n) - 1`.
- Use `1ULL`, not `1`, to force unsigned 64-bit arithmetic.
- Handle `n == 64` separately because shifting a 64-bit integer by 64 is undefined.

Signed vs unsigned shift:

```cpp
int addr = 0x80000000;
int tag = addr >> 13; // risky
```

Key lesson:

- If the sign bit is set, signed `int` may be negative.
- Right-shifting a negative signed integer may sign-extend with leading 1s.
- For addresses and bit fields, use fixed-width unsigned types:

```cpp
uint64_t addr = 0x80000000ULL;
uint64_t tag = addr >> 13;
```

##### K. Performance and Complexity

Expected questions:

- What is the complexity of `unordered_map` lookup?
- What is the worst case?
- What is the complexity of inserting into a vector middle?
- Why can excessive copying hurt a simulator?
- How would you profile slow C++ code?

What interviewer is testing:

- Whether I can write simulator code that stays fast enough for long traces.

Microarch connection:

- Performance models must be accurate enough and also fast enough to run large workloads. Data-structure cost matters.

Avoid unnecessary copies:

```cpp
struct Inst {
    uint64_t pc;
    uint32_t opcode;
    std::vector<uint64_t> deps;
};

void process(std::vector<Inst> insts) {
    for (auto inst : insts) {
        // analyze inst
    }
}
```

Problem:

- `process(std::vector<Inst> insts)` copies the whole vector at function entry.
- `for (auto inst : insts)` copies each `Inst` again.
- Since `Inst` contains a `std::vector`, each instruction copy can also copy heap-managed dependency data.

Read-only fix:

```cpp
void process(const std::vector<Inst>& insts) {
    for (const auto& inst : insts) {
        // analyze inst
    }
}
```

Mutation fix:

```cpp
void process(std::vector<Inst>& insts) {
    for (auto& inst : insts) {
        // modify inst
    }
}
```

Reserve capacity:

```cpp
std::vector<Inst> trace;
trace.reserve(num_insts);

for (int i = 0; i < num_insts; i++) {
    trace.push_back(readInst());
}
```

Key lesson:

- `reserve(num_insts)` preallocates capacity but keeps size at 0.
- This avoids repeated reallocations and element moves/copies while loading a trace.
- `resize(num_insts)` creates elements and changes size; it is not the same as reserve.

`push_back` vs `emplace_back`:

```cpp
trace.push_back(Inst{pc, opcode});
trace.emplace_back(pc, opcode);
```

Key lesson:

- `Inst{pc, opcode}` creates a temporary `Inst` object.
- `push_back` inserts an existing object.
- `emplace_back(pc, opcode)` constructs the `Inst` directly inside the vector using constructor arguments.
- For simple movable types, the difference may be small. For complex or non-copyable objects, `emplace_back` is useful.

Hash map complexity:

- `std::unordered_map` is a key-value container implemented as a hash table.
- Logically it maps one key to one value.
- Internally it uses buckets. A hash function maps the key to a bucket, then the map searches nodes in that bucket.
- Each node stores a key-value pair, conceptually `std::pair<const Key, Value>`.
- `find(key)` returns an iterator to the matching key-value pair.
- `it->first` is the key, and `it->second` is the value.

Complexity:

- Average lookup is O(1) when the hash function spreads keys well and buckets stay short.
- Worst-case lookup is O(n) if many keys collide into the same bucket.
- More buckets reduce collisions but use more memory and can hurt locality.
- Use `reserve()` when expected size is known to reduce rehashing.

Big-O basics:

- O(1): constant time. Runtime does not grow with input size.
- O(n): linear time. Work grows proportional to number of elements.
- O(nm): nested loops over two independent dimensions.
- O(n^2): nested loops where both dimensions scale with `n`.
- O(log n): repeated doubling/halving, such as binary search.
- O(n log n): linear outer work with logarithmic inner work.

Examples:

```cpp
for (int i = 0; i < n; i++) {
    work();
} // O(n)

for (int i = 0; i < n; i++) {
    for (int j = 0; j < 4; j++) {
        work();
    }
} // O(n), because 4 is constant

for (int i = 0; i < n; i++) {
    for (int j = 0; j < m; j++) {
        work();
    }
} // O(nm)

int i = 1;
while (i < n) {
    i *= 2;
} // O(log n)
```

Container complexity examples:

```cpp
std::vector<int> v;
for (int i = 0; i < n; i++) {
    v.insert(v.begin(), i);
} // O(n^2)
```

Key lesson:

- A single `vector::insert(v.begin())` is O(current size) because vector shifts existing elements.
- Repeating it `n` times gives `0 + 1 + ... + n-1 = O(n^2)`.

```cpp
std::deque<int> q;
for (int i = 0; i < n; i++) {
    q.push_front(i);
} // O(n)
```

Key lesson:

- `deque::push_front` is amortized O(1), so `n` pushes are O(n).
- Container choice changes hidden work.

Microarchitecture complexity framing:

```cpp
for (int i = 0; i < issue_width; i++) {
    selectOneReadyInst();
}
```

If `issue_width = 4` and the issue queue has 64 entries, the fixed-configuration work is bounded by a constant. More generally:

```text
O(issue_width * queue_size)
```

If issue width is fixed, this simplifies to O(queue_size). In simulator hot paths, constants still matter because this work runs every simulated cycle.

##### L. Concurrency Basics, Lower Priority

Expected questions:

- What is a data race?
- What does `std::mutex` do?
- What is `std::lock_guard`?
- How would you implement a thread-safe queue?
- What is atomic vs mutex?

What interviewer is testing:

- Basic systems fluency.

Microarch connection:

- Lower probability for this interview unless he chooses a generic C++ systems question. Know the surface, do not over-invest.

#### Part 1 Practice Order

1. `sizeof` / alignment / padding examples.
2. `const`, references, pointers.
3. `static` and object lifetime.
4. virtual functions / vtable / destructor.
5. RAII and smart pointers.
6. STL container selection and iterator invalidation.
7. callbacks/lambdas/event queue.
8. bit manipulation for cache index/tag/offset.

#### Part 2 — C++ Basics Coding Blocks, 90-120 Min

Goal: rebuild C++ coding fluency from syntax and fundamentals before solving interview-style problems. These blocks should be small, compiled, and easy to explain line by line.

Recommended location:

- `/home/fy2243/interview/c++coding/basics/`

Coding blocks, in order:

1. `01_compile_io_types.cpp`
   - Practice: `main()`, headers, `std::cout`, `std::cin`, fixed-width integer types, `sizeof`, signed vs unsigned.
   - Done when: can compile/run from command line and explain each type choice.

2. `02_control_flow_functions.cpp`
   - Practice: `if`, `switch`, loops, helper functions, pass-by-value return values.
   - Done when: code is split into small functions and handles basic edge cases.

3. `03_arrays_vectors_strings.cpp`
   - Practice: C arrays vs `std::vector`, `std::string`, indexing, bounds, range-for loops.
   - Done when: can implement simple scan/search/reverse operations without iterator mistakes.

4. `04_pointers_references_const.cpp`
   - Practice: raw pointers, references, `nullptr`, `const T&`, `T&`, pointer-to-const vs const-pointer.
   - Done when: can explain which functions mutate caller state and which only inspect it.

5. `05_structs_classes_constructors.cpp`
   - Practice: `struct` vs `class`, constructors, initializer lists, member functions, `const` member functions.
   - Done when: can build a small `Instruction` or `CacheLine` type and print/update it cleanly.

6. `06_memory_lifetime_raii.cpp`
   - Practice: stack vs heap lifetime, `std::vector` ownership, `std::unique_ptr`, destructor behavior.
   - Done when: no manual owning `new/delete` is needed and ownership is clear.

7. `07_stl_container_basics.cpp`
   - Practice: `vector`, `deque`, `queue`, `stack`, `unordered_map`, `map`, `set`, `priority_queue`.
   - Done when: can state the operation complexity and one correct use case for each container.

8. `08_iterators_and_invalidations.cpp`
   - Practice: iterators, references, `erase`, `push_back`, `reserve`, `resize`, invalidation examples.
   - Done when: can explain why a saved pointer/iterator becomes invalid after vector growth or erase.

9. `09_bit_manipulation_address_decode.cpp`
   - Practice: masks, shifts, alignment, power-of-two checks, cache offset/index/tag extraction.
   - Done when: can decode an address for configurable line size and set count using unsigned types.

10. `10_small_test_harness.cpp`
    - Practice: `assert`, simple table-driven tests, expected vs actual output, edge-case checklist.
    - Done when: every basics file has at least a tiny self-checking `main()`.

Practice rule:

- Keep each block under 20-30 minutes.
- Compile every file with `g++ -std=c++17 -Wall -Wextra -pedantic`.
- After each block, write a three-line review: one syntax issue, one edge case, one interview sentence.

Interview framing:

- These are not the final target, but they remove friction.
- The goal is to stop losing time on C++ syntax when the real question is about simulator structures, cache behavior, or LSU modeling.

#### Part 3 — Warmup Coding, 60-90 Min

Goal: regain C++ fluency before microarchitecture-specific problems. These should be quick, clean, and compiled with small tests.

Recommended location:

- `/home/fy2243/interview/c++coding/warmup/`

Problems, in order:

1. `two_sum.cpp`
   - Practice: arrays, loops, `unordered_map` or sorted two-pointer version.
   - Done when: handles duplicate values, no-solution case, and reports complexity.

2. `three_sum.cpp`
   - Practice: sort + two pointers, duplicate skipping.
   - Done when: avoids duplicate triplets and explains `O(n^2)`.

3. `reverse_bits_count_bits.cpp`
   - Practice: shifts, masks, unsigned integers.
   - Done when: can explain why unsigned types are safer for bit operations.

4. `merge_sorted_arrays.cpp`
   - Practice: two pointers, in-place merge from the back.
   - Done when: handles empty arrays and repeated values.

5. `ring_buffer.cpp`
   - Practice: fixed-capacity queue, wraparound, full/empty state.
   - Done when: push/pop/front all work across wraparound.

6. `lru_cache.cpp`
   - Practice: `list + unordered_map`, iterator validity, capacity eviction.
   - Done when: `get` promotes to MRU, `put` updates existing keys, and eviction is correct.

Interview framing:

- These are not the main interview target, but they remove syntax friction.
- Keep each solution under 25-35 minutes.
- After each one, write down one bug, one edge case, and final complexity.

#### Part 4 — Microarchitecture Coding, Highest Priority

Goal: practice the coding problems most aligned with CPU performance modeling. These are more important than generic LeetCode.

Recommended location:

- `/home/fy2243/interview/c++coding/microarch/`

Do these in this order:

1. `set_associative_cache.cpp`
   - Implement configurable sets, ways, line size, and replacement policy.
   - Minimum policies: LRU first; FIFO or random optional.
   - API target: `access(uint64_t addr)` returns hit/miss and updates stats.
   - Must handle: tag/index/offset decode, line alignment, replacement, hit rate report.
   - Interview reason: very likely for a CPU perf-modeling role; directly tests cache modeling and C++ data structures.

2. `store_to_load_forwarding.cpp`
   - Model an older store queue and a younger load request.
   - Cases:
     - full overlap: forward value;
     - partial overlap: stall/replay;
     - no older matching store: miss/no forward.
   - Must handle: address, size, age ordering, byte overlap.
   - Interview reason: highly relevant to LSU modeling and Adarsh's likely specialty.

3. `branch_predictor_sim.cpp`
   - Implement 2-bit saturating counter predictor.
   - Add gshare if time allows.
   - Input: small trace of `PC, taken`.
   - Output: prediction count, misprediction count, misprediction rate.
   - Must handle: index extraction, counter update, initial state.

4. `mshr_model.cpp`
   - Implement allocate, merge same cache line, reject when full, complete refill.
   - Must handle: line address matching, outstanding miss limit, multiple waiting requests.
   - Interview reason: common cache-modeling structure; tests state-machine discipline.

5. `wakeup_select_issue_queue.cpp`
   - Model issue queue entries with source readiness and age.
   - Select up to `issue_width` ready entries per cycle.
   - Must handle: wakeup by physical register tag, oldest-ready selection, removal after issue.
   - Interview reason: lower probability, but useful if he probes general OoO modeling.

Microarch coding rule:

- Always start with the model contract before coding:
  - What state is stored?
  - What is the per-cycle or per-access API?
  - What are the invariants?

#### Simulator-Style Warmup Checklist and Interview Key Points

Completed warmup files:

1. `warmup/ring_buffer.cpp`
2. `warmup/lru_cache.cpp`
3. `warmup/direct_mapped_cache.cpp`
4. `warmup/set_associative_cache.cpp`
5. `warmup/mshr_table.cpp`
6. `warmup/load_replay_buffer.cpp`
7. `warmup/event_queue.cpp`
8. `warmup/branch_predictor.cpp`
9. `warmup/store_queue_forwarding.cpp`
10. `warmup/rob_active_list.cpp`
11. `warmup/simple_pipeline_simulator.cpp`

Key interview points:

- Ring buffer:
  - `head` is next read, `tail` is next write, `count` disambiguates full vs empty.
  - `head == tail` can mean either empty or full depending on `count`.
  - Fixed-size vector plus wraparound is natural for ROB/fetch/replay queues.

- LRU cache:
  - `unordered_map` gives key lookup; `list` maintains recency order.
  - Store `key -> list iterator` so promotion to MRU is O(1).
  - `unordered_map::operator[]` can insert accidentally; use `find()` for read-only lookup.

- Direct-mapped cache:
  - `line_addr = addr / line_size`.
  - `index = line_addr % num_lines`.
  - `tag = line_addr / num_lines`.
  - Hit requires both `valid` and matching `tag`.

- Set-associative cache:
  - `set_index = line_addr % num_sets`; ways are searched inside the selected set.
  - Associativity does not add address bits; it changes how many candidate lines exist per set.
  - Flat vector layout uses `set * num_ways + way`.
  - Replacement can be modeled with timestamps for true LRU or tree bits for pseudo-LRU.

- MSHR table:
  - MSHR tracks outstanding cache misses by cache-line address, not byte address.
  - Same-line misses should merge or wait on the existing MSHR.
  - Real hardware does not use callbacks; loads compare against MSHR state and store/replay an MSHR ID.
  - On response, fill path writes/refills L1, dependent loads replay or forward, then MSHR is freed.

- Load replay buffer:
  - Replay entries store original load info plus a wait reason and often an `mshr_id`.
  - Replay logic scans valid entries, checks readiness, and selects a ready entry, often oldest first.
  - Readiness can mean MSHR gone, MSHR data-ready, older store resolved, or retry delay expired.

- Event queue:
  - Simulator events are ordered by target cycle.
  - `priority_queue` is a good fit when priority is fixed at insertion.
  - Real hardware has wires/FSMs; callbacks are a simulator abstraction for delayed behavior.

- Branch predictor:
  - 2-bit saturating counter states: strong/weak not-taken and weak/strong taken.
  - Predict taken for states 2 and 3; update saturates at 0 and 3.
  - PC indexing usually drops low alignment bits, e.g. `pc >> 2`.

- Store queue / forwarding:
  - Search older stores from youngest to oldest.
  - Forward from the youngest older store with a matching known address.
  - Unknown older store addresses may block the load because aliasing is not yet known.

- ROB / active list:
  - Allocate at tail, mark complete out of order, retire only from complete head.
  - Flush invalidates younger entries and moves tail.
  - Indices are usually better than raw pointers because entries are reused.

- Simple pipeline:
  - Model stages, valid bits, stalls, bubbles, and retirement separately.
  - A stall freezes younger stages and lets older stages proceed only if the model allows it.
  - State update order matters: compute next state from current state, then commit it.
  - What stats are reported?
- For each implementation, include a tiny `main()` test rather than relying on memory.

#### Part 5 — Callback Practice

Goal: remove C++ callback syntax weakness before discussing Sparta/Olympia-style event-driven simulation.

Recommended location:

- `/home/fy2243/interview/c++coding/callbacks/`

Create one small file:

- `callback_practice.cpp`

Cover these examples:

1. Raw function pointer
   - `void (*cb)(int)`
   - Use case: simple C-style callback.

2. Member-function pointer
   - `void (Class::*)(int)`
   - Use case: calling a method through an object instance.

3. Lambda callback
   - capture by value and by reference.
   - Must know lifetime risk of reference capture.

4. `std::function`
   - Store different callable types behind one interface.
   - Use case: event queue stores callbacks uniformly.

5. Event queue with delayed callback
   - Store `{cycle, callback}` entries.
   - Pop events whose scheduled cycle equals current cycle.
   - Use this to simulate "cache response returns 5 cycles later."

Interview framing:

- Callback syntax is not the goal by itself.
- The goal is to explain event-driven simulation clearly:
  - schedule a callback now;
  - execute it later at simulated cycle `N`;
  - use payloads to model delayed messages like cache responses or wakeup events.

#### Part 6 — C++ Through Microarchitecture Examples

Goal: connect C++ basics to CPU modeling examples after syntax is refreshed.

Mapping:

- `sizeof` / padding -> cache metadata entry size, MSHR entry size, trace record size.
- `const T&` -> inspect instruction or memory request without copying.
- `static` -> opcode metadata table vs risky hidden global simulator state.
- virtual function -> replacement-policy interface or branch-predictor interface.
- `unique_ptr` -> single owner of a model component or event object.
- `shared_ptr` -> instruction object referenced by multiple queues; use carefully.
- `vector` -> cache sets, counters, dense predictor tables.
- `deque` / ring buffer -> ROB, fetch queue, replay queue.
- `list + unordered_map` -> LRU policy.
- bit operations -> cache tag/index/offset, line alignment, predictor indexing.
- callback -> delayed cache response or scheduled pipeline event.

Practice format:

- For each C++ concept, prepare a 30-45 second answer.
- Each answer should contain:
  - definition;
  - one code-level example;
  - one microarchitecture modeling example.

#### Status Log

- 2026-04-25: Planned Part 1 C++ basics refresh for performance-modeling interview.
- 2026-04-25: Added warmup coding, microarchitecture coding, callback practice, and C++-through-microarchitecture example plan.

### Goal

Practice C/C++ coding for interviews in a structured, progressive way.

Build confidence and fluency in:

- C/C++ fundamentals (pointers, memory, STL)
- Core data structures (arrays, linked lists, stacks, trees, graphs)
- Algorithm patterns (two pointers, sliding window, binary search, BFS/DFS)
- Dynamic programming and backtracking
- Writing clean, correct, interview-quality code under time pressure

### Intention

Use an interviewer-style format instead of passive study.

Claude acts as the C/C++ coding interviewer and:

- asks one question at a time
- starts from easy, classic, fundamental problems
- increases difficulty gradually
- reviews the submitted answer like an interviewer
- points out correctness issues, edge cases, and complexity concerns
- gives follow-up questions when useful

The user writes the solution first. The goal is active practice, not immediate solution dumping.

### Methodology

1. Start with very simple problems.
2. Solve one problem at a time.
3. Review the answer for:
   - correctness (logic, edge cases)
   - time and space complexity
   - C/C++ style and idiom
   - interview quality
4. If needed, give a corrected version and explain the key issue briefly.
5. Move to the next question only after the current one is understood.

### Session Style

- Mode: interviewer mode
- Pace: step by step
- Initial difficulty: easy
- Question style: classic and fundamental C/C++ interview questions
- Primary language: C/C++

### Review Standard

Each answer should be judged by questions such as:

- Does it meet the exact requirement?
- Does it handle edge cases (empty input, single element, overflow)?
- What is the time and space complexity?
- Is there a simpler or more idiomatic way to write it?
- Would this answer be acceptable in a real interview?

When reviewing submitted code:

- first give a short summary of the current status
- then walk through the issues one by one
- after the summary, focus on one fix at a time until the current issue is resolved
- once the code is correct, also comment on whether it is already good as an interview answer
- if there is a cleaner, more standard, or more optimal solution, propose that improvement briefly
- if the submitted solution is already solid, simply say it is good instead of forcing extra optimization advice

### Folder Layout

- `01_arrays_strings/`
- `02_math_bit_manipulation/`
- `03_linked_list/`
- `04_stack_queue/`
- `05_hashmap/`
- `06_two_pointers/`
- `07_sliding_window/`
- `08_binary_search/`
- `09_tree_bst/`
- `10_graph/`
- `11_dynamic_programming/`
- `12_interval_matrix/`
- `13_backtracking_heap_trie/`

### File Convention

For each new question:

- create one `.cpp` file for the solution
- name the file descriptively, e.g., `lc88_merge_sorted_array.cpp`
- include a comment block at the top with the problem description and constraints
- expect the user to fill in the solution

### Working Agreement

- Keep the practice interactive.
- Do not skip straight to advanced problems.
- Prefer small, common problems before full design questions.
- Use mistakes as teaching points.
- Every review should start with a short summary, then continue with a one-by-one walkthrough of the issues.
- After a solution is correct, reviews should also mention whether it is already good or whether there is a better standard/optimized solution.
- Resume from this document if the session context is lost.

---

### Study Plan — Priority Order for Interview Prep

Problems sourced from [LeetCode Top Interview 150](https://leetcode.com/studyplan/top-interview-150/). Organized by topic, ordered easy → medium → hard within each section. Problems the user has already solved are marked with ✅.

#### Phase 1 — Fundamentals (do these first)

These are the bread and butter. If you only have a few hours, focus here.

##### 01 — Arrays & Strings

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 88 | Merge Sorted Array | Easy | ✅ |
| 🔴 | 27 | Remove Element | Easy | ✅ |
| 🔴 | 26 | Remove Duplicates from Sorted Array | Easy | ✅ |
| 🔴 | 169 | Majority Element | Easy | ✅ |
| 🔴 | 121 | Best Time to Buy and Sell Stock | Easy | ✅ |
| 🔴 | 13 | Roman to Integer | Easy | ✅ |
| 🔴 | 58 | Length of Last Word | Easy | ✅ |
| 🔴 | 14 | Longest Common Prefix | Easy | ✅ |
| 🔴 | 28 | Find the Index of First Occurrence | Easy | ✅ |
| 🔴 | 238 | Product of Array Except Self | Medium | ✅ |
| 🔴 | 55 | Jump Game | Medium | ✅ |
| 🟡 | 189 | Rotate Array | Medium | |
| 🟡 | 80 | Remove Duplicates from Sorted Array II | Medium | |
| 🟡 | 45 | Jump Game II | Medium | |
| 🟡 | 134 | Gas Station | Medium | |
| 🟡 | 151 | Reverse Words in a String | Medium | |
| 🟡 | 6 | Zigzag Conversion | Medium | ✅ |
| 🟢 | 274 | H-Index | Medium | |
| 🟢 | 380 | Insert Delete GetRandom O(1) | Medium | |
| 🟢 | 42 | Trapping Rain Water | Hard | |
| 🟢 | 135 | Candy | Hard | |
| 🟢 | 68 | Text Justification | Hard | |

##### 02 — Math & Bit Manipulation

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 9 | Palindrome Number | Easy | ✅ |
| 🔴 | 66 | Plus One | Easy | ✅ |
| 🔴 | 69 | Sqrt(x) | Easy | ✅ |
| 🔴 | 136 | Single Number | Easy | ✅ |
| 🔴 | 191 | Number of 1 Bits | Easy | ✅ |
| 🔴 | 190 | Reverse Bits | Easy | ✅ |
| 🟡 | 67 | Add Binary | Easy | |
| 🟡 | 137 | Single Number II | Medium | |
| 🟡 | 50 | Pow(x, n) | Medium | |
| 🟡 | 172 | Factorial Trailing Zeroes | Medium | |
| 🟢 | 201 | Bitwise AND of Numbers Range | Medium | |
| 🟢 | 149 | Max Points on a Line | Hard | |

##### 05 — Hashmap

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 383 | Ransom Note | Easy | ✅ |
| 🔴 | 205 | Isomorphic Strings | Easy | ✅ |
| 🔴 | 1 | Two Sum | Easy | |
| 🔴 | 242 | Valid Anagram | Easy | |
| 🔴 | 49 | Group Anagrams | Medium | ✅ |
| 🟡 | 290 | Word Pattern | Easy | |
| 🟡 | 202 | Happy Number | Easy | |
| 🟡 | 219 | Contains Duplicate II | Easy | |
| 🟡 | 128 | Longest Consecutive Sequence | Medium | ✅ |

#### Phase 2 — Core Patterns (high ROI techniques)

These patterns show up repeatedly. Master the technique, not just individual problems.

##### 06 — Two Pointers

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 125 | Valid Palindrome | Easy | ✅ |
| 🔴 | 392 | Is Subsequence | Easy | ✅ |
| 🔴 | 167 | Two Sum II | Medium | |
| 🔴 | 11 | Container With Most Water | Medium | ✅ |
| 🔴 | 15 | 3Sum | Medium | ✅ |

##### 07 — Sliding Window

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 209 | Minimum Size Subarray Sum | Medium | ✅ |
| 🔴 | 3 | Longest Substring Without Repeating Characters | Medium | ✅ |
| 🟡 | 30 | Substring with Concatenation of All Words | Hard | |
| 🟡 | 76 | Minimum Window Substring | Hard | |

##### 08 — Binary Search

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 35 | Search Insert Position | Easy | ✅ |
| 🔴 | 74 | Search a 2D Matrix | Medium | |
| 🔴 | 162 | Find Peak Element | Medium | ✅ |
| 🔴 | 33 | Search in Rotated Sorted Array | Medium | ✅ |
| 🟡 | 34 | Find First and Last Position | Medium | |
| 🟡 | 153 | Find Minimum in Rotated Sorted Array | Medium | |
| 🟢 | 4 | Median of Two Sorted Arrays | Hard | |

##### 04 — Stack & Queue

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 20 | Valid Parentheses | Easy | ✅ |
| 🔴 | 150 | Evaluate Reverse Polish Notation | Medium | ✅ |
| 🟡 | 155 | Min Stack | Medium | |
| 🟡 | 71 | Simplify Path | Medium | |
| 🟢 | 224 | Basic Calculator | Hard | |

#### Phase 3 — Data Structures (linked lists, trees, graphs)

##### 03 — Linked List

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 141 | Linked List Cycle | Easy | ✅ |
| 🔴 | 21 | Merge Two Sorted Lists | Easy | ✅ |
| 🔴 | 2 | Add Two Numbers | Medium | ✅ |
| 🔴 | 92 | Reverse Linked List II | Medium | ✅ |
| 🟡 | 19 | Remove Nth Node From End of List | Medium | |
| 🟡 | 82 | Remove Duplicates from Sorted List II | Medium | |
| 🟡 | 61 | Rotate List | Medium | |
| 🟡 | 86 | Partition List | Medium | |
| 🟡 | 138 | Copy List with Random Pointer | Medium | |
| 🟢 | 25 | Reverse Nodes in k-Group | Hard | |
| 🟢 | 146 | LRU Cache | Medium | |

##### 09 — Tree & BST

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 104 | Maximum Depth of Binary Tree | Easy | ✅ |
| 🔴 | 100 | Same Tree | Easy | ✅ |
| 🔴 | 226 | Invert Binary Tree | Easy | |
| 🔴 | 101 | Symmetric Tree | Easy | |
| 🔴 | 112 | Path Sum | Easy | |
| 🔴 | 102 | Binary Tree Level Order Traversal | Medium | ✅ |
| 🔴 | 98 | Validate Binary Search Tree | Medium | ✅ |
| 🔴 | 236 | Lowest Common Ancestor | Medium | ✅ |
| 🔴 | 108 | Convert Sorted Array to BST | Easy | ✅ |
| 🟡 | 530 | Minimum Absolute Difference in BST | Easy | ✅ |
| 🟡 | 637 | Average of Levels in Binary Tree | Easy | ✅ |
| 🟡 | 105 | Construct BT from Preorder and Inorder | Medium | |
| 🟡 | 114 | Flatten Binary Tree to Linked List | Medium | |
| 🟡 | 199 | Binary Tree Right Side View | Medium | |
| 🟡 | 129 | Sum Root to Leaf Numbers | Medium | |
| 🟡 | 222 | Count Complete Tree Nodes | Easy | |
| 🟡 | 173 | Binary Search Tree Iterator | Medium | |
| 🟢 | 124 | Binary Tree Maximum Path Sum | Hard | |

##### 10 — Graph

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 200 | Number of Islands | Medium | ✅ |
| 🔴 | 433 | Minimum Genetic Mutation | Medium | ✅ |
| 🟡 | 130 | Surrounded Regions | Medium | |
| 🟡 | 133 | Clone Graph | Medium | |
| 🟡 | 207 | Course Schedule | Medium | |
| 🟡 | 210 | Course Schedule II | Medium | |
| 🟢 | 127 | Word Ladder | Hard | |

#### Phase 4 — Advanced (if time allows)

##### 11 — Dynamic Programming

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 70 | Climbing Stairs | Easy | ✅ |
| 🔴 | 198 | House Robber | Medium | ✅ |
| 🔴 | 53 | Maximum Subarray (Kadane's) | Medium | ✅ |
| 🟡 | 322 | Coin Change | Medium | |
| 🟡 | 139 | Word Break | Medium | |
| 🟡 | 300 | Longest Increasing Subsequence | Medium | |
| 🟡 | 64 | Minimum Path Sum | Medium | |
| 🟡 | 120 | Triangle | Medium | |
| 🟡 | 5 | Longest Palindromic Substring | Medium | |
| 🟡 | 72 | Edit Distance | Medium | |
| 🟡 | 918 | Maximum Sum Circular Subarray | Medium | |
| 🟢 | 97 | Interleaving String | Medium | |
| 🟢 | 221 | Maximal Square | Medium | |
| 🟢 | 63 | Unique Paths II | Medium | |

##### 12 — Interval & Matrix

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 228 | Summary Ranges | Easy | ✅ |
| 🔴 | 56 | Merge Intervals | Medium | ✅ |
| 🔴 | 57 | Insert Interval | Medium | ✅ |
| 🔴 | 48 | Rotate Image | Medium | ✅ |
| 🔴 | 73 | Set Matrix Zeroes | Medium | ✅ |
| 🔴 | 36 | Valid Sudoku | Medium | ✅ |
| 🟡 | 452 | Minimum Number of Arrows | Medium | |
| 🟡 | 54 | Spiral Matrix | Medium | |
| 🟡 | 289 | Game of Life | Medium | |

##### 13 — Backtracking, Heap & Trie

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 22 | Generate Parentheses | Medium | ✅ |
| 🔴 | 215 | Kth Largest Element in Array | Medium | ✅ |
| 🔴 | 208 | Implement Trie | Medium | ✅ |
| 🟡 | 46 | Permutations | Medium | |
| 🟡 | 39 | Combination Sum | Medium | |
| 🟡 | 77 | Combinations | Medium | |
| 🟡 | 17 | Letter Combinations of Phone Number | Medium | |
| 🟡 | 79 | Word Search | Medium | |
| 🟡 | 148 | Sort List | Medium | |
| 🟡 | 23 | Merge k Sorted Lists | Hard | |
| 🟡 | 211 | Design Add and Search Words | Medium | |
| 🟢 | 52 | N-Queens II | Hard | ✅ |
| 🟢 | 295 | Find Median from Data Stream | Hard | |
| 🟢 | 212 | Word Search II | Hard | |

---

### Priority Legend

- 🔴 **Must do** — very high frequency in interviews, do these first
- 🟡 **Should do** — common patterns, do if time allows
- 🟢 **Nice to have** — less common or harder, skip under time pressure

### Night-Before Strategy

If you only have a few hours:

1. **Review your ✅ solved problems** — re-read solutions, make sure you can reproduce them
2. **Do 2-3 unsolved 🔴 problems** from Phase 1-2 — focus on Two Sum, Two Sum II, Min Stack
3. **Review patterns** — make sure you can recognize when to use two pointers, sliding window, binary search, BFS/DFS
4. **Practice talking through your approach** — interviewers care about communication as much as code

### C/C++ Interview Tips

- Always clarify input constraints before coding
- State your approach and complexity before writing code
- Handle edge cases: empty input, single element, overflow, null pointers
- Use `const` references for read-only parameters
- Know STL basics: `vector`, `unordered_map`, `stack`, `queue`, `priority_queue`, `sort`
- Know when to use `new`/`delete` vs stack allocation vs smart pointers
- If stuck, start with brute force and optimize

### EDA Tools on This Server

- Compile C++: `g++ -std=c++17 -o solution solution.cpp && ./solution`
