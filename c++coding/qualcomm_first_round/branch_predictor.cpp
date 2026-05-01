#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

class TwoBitBranchPredictor {
public:
    explicit TwoBitBranchPredictor(std::size_t entries)
        : counters_(entries, 1) {
        assert(entries > 0);
    }

    bool predict(std::uint64_t pc) const {
        // Steps:
        // 1. Hash/index the PC into the counter table.
        // 2. Predict taken for states 2 and 3.
        return counters_[index(pc)] >= 2;
    }

    void update(std::uint64_t pc, bool taken) {
        // Steps:
        // 1. Find the PC's counter.
        // 2. Increment toward strongly taken on taken.
        // 3. Decrement toward strongly not-taken on not-taken.
        std::uint8_t& counter = counters_[index(pc)];
        if (taken) {
            if (counter < 3) {
                counter++;
            }
        }
        else {
            if (counter > 0) {
                counter--;
            }
        }
    }

    std::uint8_t counter_for_test(std::uint64_t pc) const {
        return counters_[index(pc)];
    }

private:
    std::size_t index(std::uint64_t pc) const {
        return (pc >> 2) % counters_.size();
    }

    std::vector<std::uint8_t> counters_;
};

int main() {
    TwoBitBranchPredictor predictor(16);
    constexpr std::uint64_t pc = 0x100;

    assert(!predictor.predict(pc));
    assert(predictor.counter_for_test(pc) == 1);

    predictor.update(pc, true);
    assert(predictor.predict(pc));
    assert(predictor.counter_for_test(pc) == 2);

    predictor.update(pc, true);
    assert(predictor.predict(pc));
    assert(predictor.counter_for_test(pc) == 3);

    predictor.update(pc, false);
    assert(predictor.predict(pc));
    assert(predictor.counter_for_test(pc) == 2);

    predictor.update(pc, false);
    assert(!predictor.predict(pc));
    assert(predictor.counter_for_test(pc) == 1);

    predictor.update(pc, false);
    assert(!predictor.predict(pc));
    assert(predictor.counter_for_test(pc) == 0);

    std::cout << "branch_predictor tests passed\n";
    return 0;
}
