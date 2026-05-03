#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

struct ROBEntry {
    bool valid = false;
    bool complete = false;
    std::uint64_t instruction_id = 0;
};

class ReorderBuffer {
public:
    explicit ReorderBuffer(std::size_t capacity)
        : entries_(capacity), head_(0), tail_(0), count_(0) {
        assert(capacity > 0);
    }

    bool allocate(std::uint64_t instruction_id, std::size_t& rob_id) {
        // Steps:
        // 1. If full, allocation fails.
        // 2. Write a new incomplete entry at tail.
        // 3. Return the allocated ROB index.
        // 4. Advance tail with wraparound.
        if (count_ == entries_.size()) {
            return false;
        }

        rob_id = tail_;
        entries_[tail_] = ROBEntry{true, false, instruction_id};
        tail_ = next(tail_);
        count_++;
        return true;
    }

    bool mark_complete(std::size_t rob_id) {
        // Steps:
        // 1. Check that the index is currently active.
        // 2. Mark that ROB entry complete.
        if (!is_active(rob_id)) {
            return false;
        }

        entries_[rob_id].complete = true;
        return true;
    }

    bool retire(std::uint64_t& instruction_id) {
        // Steps:
        // 1. Only the head entry can retire.
        // 2. If head is incomplete, retirement stalls.
        // 3. If complete, remove it and advance head.
        if (count_ == 0 || !entries_[head_].complete) {
            return false;
        }

        instruction_id = entries_[head_].instruction_id;
        entries_[head_] = ROBEntry{};
        head_ = next(head_);
        count_--;
        return true;
    }

    bool flush_younger_than(std::size_t rob_id) {
        // Steps:
        // 1. Keep entries from head through rob_id.
        // 2. Invalidate all younger entries after rob_id.
        // 3. Move tail to the slot after rob_id.
        if (!is_active(rob_id)) {
            return false;
        }

        std::size_t idx = next(rob_id);
        while (idx != tail_) {
            if (entries_[idx].valid) {
                entries_[idx] = ROBEntry{};
                count_--;
            }
            idx = next(idx);
        }

        tail_ = next(rob_id);
        return true;
    }

    std::size_t size() const {
        return count_;
    }

private:
    std::size_t next(std::size_t index) const {
        return (index + 1) % entries_.size();
    }

    bool is_active(std::size_t rob_id) const {
        std::size_t idx = head_;
        for (std::size_t i = 0; i < count_; ++i) {
            if (idx == rob_id && entries_[idx].valid) {
                return true;
            }
            idx = next(idx);
        }
        return false;
    }

    std::vector<ROBEntry> entries_;
    std::size_t head_;
    std::size_t tail_;
    std::size_t count_;
};

int main() {
    ReorderBuffer rob(3);

    std::size_t id0 = 0;
    std::size_t id1 = 0;
    std::size_t id2 = 0;
    std::size_t id3 = 0;
    std::uint64_t retired = 0;

    assert(rob.allocate(10, id0));
    assert(rob.allocate(20, id1));
    assert(rob.allocate(30, id2));
    assert(!rob.allocate(40, id3));

    assert(rob.mark_complete(id1));
    assert(!rob.retire(retired));

    assert(rob.mark_complete(id0));
    assert(rob.retire(retired));
    assert(retired == 10);

    assert(rob.allocate(40, id3));
    assert(rob.mark_complete(id2));
    assert(rob.mark_complete(id3));

    assert(rob.retire(retired));
    assert(retired == 20);
    assert(rob.retire(retired));
    assert(retired == 30);
    assert(rob.retire(retired));
    assert(retired == 40);
    assert(!rob.retire(retired));

    ReorderBuffer flush_rob(4);
    std::size_t a = 0;
    std::size_t b = 0;
    std::size_t c = 0;
    std::size_t d = 0;
    assert(flush_rob.allocate(1, a));
    assert(flush_rob.allocate(2, b));
    assert(flush_rob.allocate(3, c));
    assert(flush_rob.flush_younger_than(b));
    assert(flush_rob.size() == 2);
    assert(!flush_rob.mark_complete(c));
    assert(flush_rob.allocate(4, d));

    assert(flush_rob.mark_complete(a));
    assert(flush_rob.mark_complete(b));
    assert(flush_rob.mark_complete(d));
    assert(flush_rob.retire(retired));
    assert(retired == 1);
    assert(flush_rob.retire(retired));
    assert(retired == 2);
    assert(flush_rob.retire(retired));
    assert(retired == 4);

    std::cout << "rob_active_list tests passed\n";
    return 0;
}
