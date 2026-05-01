#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

struct MSHREntry {
    bool valid = false;
    bool data_ready = false;
};

struct ReplayEntry {
    bool valid = false;
    std::uint64_t address = 0;
    std::size_t mshr_id = 0;
};

class LoadReplayBuffer {
public:
    explicit LoadReplayBuffer(std::size_t capacity)
        : entries_(capacity), count_(0), selected_valid_(false), selected_index_(0) {
        assert(capacity > 0);
    }

    bool push(std::uint64_t address, std::size_t mshr_id) {
        // Steps:
        // 1. If the replay buffer is full, reject the load.
        // 2. Find an invalid entry.
        // 3. Store the load address and the MSHR ID it waits on.
        if (count_ == entries_.size()) {
            return false;
        }

        for (auto& entry : entries_) {
            if (!entry.valid) {
                entry.valid = true;
                entry.address = address;
                entry.mshr_id = mshr_id;
                count_++;
                return true;
            }
        }

        return false;
    }

    bool pick_ready(const std::vector<MSHREntry>& mshrs, std::uint64_t& address) {
        // Steps:
        // 1. Scan replay entries in age order.
        // 2. For each valid entry, check the MSHR it depends on.
        // 3. Ready means the MSHR is gone or its data is ready.
        // 4. Remember the selected entry so pop_ready() can remove it.
        selected_valid_ = false;

        for (std::size_t i = 0; i < entries_.size(); ++i) {
            ReplayEntry& entry = entries_[i];
            if (!entry.valid) {
                continue;
            }

            assert(entry.mshr_id < mshrs.size());
            const MSHREntry& mshr = mshrs[entry.mshr_id];
            if (!mshr.valid || mshr.data_ready) {
                selected_valid_ = true;
                selected_index_ = i;
                address = entry.address;
                return true;
            }
        }

        return false;
    }

    void pop_ready() {
        // Steps:
        // 1. Require that pick_ready() selected an entry.
        // 2. Invalidate that replay entry.
        // 3. Decrement occupancy.
        assert(selected_valid_);
        assert(entries_[selected_index_].valid);

        entries_[selected_index_] = ReplayEntry{};
        count_--;
        selected_valid_ = false;
    }

    std::size_t size() const {
        return count_;
    }

private:
    std::vector<ReplayEntry> entries_;
    std::size_t count_;
    bool selected_valid_;
    std::size_t selected_index_;
};

int main() {
    std::vector<MSHREntry> mshrs(2);
    mshrs[0].valid = true;
    mshrs[1].valid = true;

    LoadReplayBuffer lrb(2);

    assert(lrb.push(0, 0));
    assert(lrb.push(64, 1));
    assert(!lrb.push(128, 0));
    assert(lrb.size() == 2);

    std::uint64_t address = 0;
    assert(!lrb.pick_ready(mshrs, address));

    mshrs[1].data_ready = true;
    assert(lrb.pick_ready(mshrs, address));
    assert(address == 64);
    lrb.pop_ready();
    assert(lrb.size() == 1);

    mshrs[0].valid = false;
    assert(lrb.pick_ready(mshrs, address));
    assert(address == 0);
    lrb.pop_ready();
    assert(lrb.size() == 0);

    std::cout << "load_replay_buffer tests passed\n";
    return 0;
}
