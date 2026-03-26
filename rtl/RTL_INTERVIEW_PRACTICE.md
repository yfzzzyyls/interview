# RTL Interview Practice

## Goal

Practice RTL coding for interviews in a structured, step-by-step way.

The focus is to build confidence and fluency in:

- basic combinational RTL
- bit manipulation
- vectors, slicing, concatenation, replication
- masking, set/clear/toggle operations
- muxes, encoders, decoders
- sequential RTL such as counters, shift registers, and edge detection
- later, FSMs and other common interview-style building blocks

## Intention

Use an interviewer-style format instead of passive study.

Codex acts as the RTL coding interviewer and:

- asks one question at a time
- starts from easy, classic, fundamental problems
- increases difficulty gradually
- reviews the submitted answer like an interviewer
- points out correctness issues, style issues, and synthesis concerns
- gives follow-up questions when useful

The user writes the RTL solution first. The goal is active practice, not immediate solution dumping.

## Methodology

1. Start with very simple problems.
2. Solve one problem at a time.
3. For each question, write both the RTL solution and a small basic-functionality testbench.
4. Review the answer for:
   - correctness
   - synthesizability
   - clarity
   - interview quality
5. If needed, give a corrected version and explain the key issue briefly.
6. Move to the next question only after the current one is understood.

## Session Style

- Mode: interviewer mode
- Pace: step by step
- Initial difficulty: easy
- Question style: classic and fundamental RTL interview questions
- Primary language: Verilog/SystemVerilog RTL

## Folder Layout

- `01_bit_manipulation`
- `02_combinational_logic`
- `03_mux_encoder_decoder`
- `04_arithmetic_datapath`
- `05_sequential_basics`
- `06_counters_shift_registers`
- `07_fsm_control`
- `08_memory_fifo`
- `09_clock_domain_crossing`
- `10_bus_protocols_handshaking`
- `11_pipeline_design`
- `12_low_power`

Questions should be saved in the folder that best matches the underlying concept.

## File Convention

For each new question:

- create one `.sv` file for the RTL solution
- write the RTL using SystemVerilog syntax
- when useful, provide the design module definition with parameter placeholders so parameterized RTL style is practiced over time
- name the RTL file as `xxx.sv`
- create one empty companion testbench file named `xxx_tb.sv` in the same directory
- expect the interviewee to fill in `xxx_tb.sv` with a small testbench that checks basic functionality

## Review Standard

Each answer should be judged by questions such as:

- Does it meet the exact requirement?
- Is it combinational or sequential as intended?
- Is the code synthesizable?
- Is there a simpler or clearer way to write it?
- Would this answer be acceptable in a real interview?

When reviewing submitted RTL or testbench code:

- first give a short summary of the current status
- then walk through the issues one by one
- after the summary, focus on one fix at a time until the current issue is resolved
- once the code is correct, also comment on whether it is already good as an interview answer
- if there is a cleaner, more standard, more scalable, or more idiomatic solution, propose that improvement briefly
- if the submitted solution is already solid, simply say it is good instead of forcing extra optimization advice

## Expected Early Topics

- swap bits or nibbles
- extract or assign specific bit ranges
- reverse bit order
- set, clear, or toggle selected bits
- create simple masks
- build small muxes and decoders
- write priority logic carefully

## Working Agreement

- Keep the practice interactive.
- Do not skip straight to advanced problems.
- Prefer small, common problems before full design questions.
- Use mistakes as teaching points.
- Each new question should come with both `xxx.sv` and an empty `xxx_tb.sv` file.
- Future problems should gradually practice parameterized module definitions where appropriate.
- New `.sv` problem files should include a short in-file comment block describing the required behavior so the design intent is visible in the source.
- Every review should start with a short summary, then continue with a one-by-one walkthrough of the issues.
- After a solution is correct, reviews should also mention whether it is already good or whether there is a better standard/optimized solution.
- Resume from this document if the session context is lost.

## EDA Tools on This Server

- VCS: `vcs -full64 -sverilog <files> -o <simv_name> && ./<simv_name>`
