#include <array>
#include <cassert>
#include <cstddef>
#include <iostream>
#include <optional>
#include <utility>
#include <vector>

struct Instruction {
    int id = 0;
    int remaining_memory_stall_cycles = 0;
};

class FiveStagePipeline {
public:
    explicit FiveStagePipeline(std::vector<Instruction> program)
        : program_(std::move(program)), pc_(0), cycle_(0), retired_(0) {}

    bool step() {
        // Steps:
        // 1. Retire instruction in writeback.
        // 2. If memory stage is stalled, decrement its remaining wait and freeze younger stages.
        // 3. Otherwise shift W <- M <- X <- D <- F.
        // 4. Fetch the next instruction if program input remains.
        if (done()) {
            return false;
        }

        cycle_++;

        if (pipe_[Writeback]) {
            retired_++;
            pipe_[Writeback].reset();
        }

        bool memory_stall = false;
        if (pipe_[Memory] && pipe_[Memory]->remaining_memory_stall_cycles > 0) {
            pipe_[Memory]->remaining_memory_stall_cycles--;
            memory_stall = true;
        }

        if (!memory_stall) {
            pipe_[Writeback] = pipe_[Memory];
            pipe_[Memory] = pipe_[Execute];
            pipe_[Execute] = pipe_[Decode];
            pipe_[Decode] = pipe_[Fetch];

            if (pc_ < program_.size()) {
                pipe_[Fetch] = program_[pc_++];
            }
            else {
                pipe_[Fetch].reset();
            }
        }

        return true;
    }

    void run() {
        while (step()) {
        }
    }

    bool done() const {
        if (retired_ != program_.size()) {
            return false;
        }
        for (const auto& stage : pipe_) {
            if (stage) {
                return false;
            }
        }
        return true;
    }

    std::size_t cycle() const {
        return cycle_;
    }

    std::size_t retired() const {
        return retired_;
    }

private:
    static constexpr std::size_t Fetch = 0;
    static constexpr std::size_t Decode = 1;
    static constexpr std::size_t Execute = 2;
    static constexpr std::size_t Memory = 3;
    static constexpr std::size_t Writeback = 4;

    std::vector<Instruction> program_;
    std::size_t pc_;
    std::size_t cycle_;
    std::size_t retired_;
    std::array<std::optional<Instruction>, 5> pipe_{};
};

int main() {
    FiveStagePipeline no_stall({
        Instruction{1, 0},
        Instruction{2, 0},
        Instruction{3, 0},
    });
    no_stall.run();
    assert(no_stall.retired() == 3);
    assert(no_stall.cycle() == 8);

    FiveStagePipeline with_miss({
        Instruction{1, 0},
        Instruction{2, 2},
        Instruction{3, 0},
    });
    with_miss.run();
    assert(with_miss.retired() == 3);
    assert(with_miss.cycle() == 10);

    std::cout << "simple_pipeline_simulator tests passed\n";
    return 0;
}
