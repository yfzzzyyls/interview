#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

struct MSHREntry {
    bool valid = false;
    std::uint64_t line_addr = 0;
    std::size_t merged_requests = 0;
};

class MSHRTable {
public:
    MSHRTable(std::size_t capacity, std::size_t line_size)
        : entries_(capacity), line_size_(line_size), count_(0) {
        assert(capacity > 0);
        assert(line_size > 0);
    }

    bool allocate_or_merge(std::uint64_t address) {
        std::uint64_t line_addr = address / line_size_;

        for (auto& entry : entries_) {
            if (entry.valid && entry.line_addr == line_addr) {
                entry.merged_requests++;
                return true;
            }
        }

        if (count_ == entries_.size()) {
            return false;
        }

        for (auto& entry : entries_) {
            if (!entry.valid) {
                entry.valid = true;
                entry.line_addr = line_addr;
                entry.merged_requests = 1;
                count_++;
                return true;
            }
        }

        return false;
    }


    bool complete(std::uint64_t address) {
        std::uint64_t line_addr = address / line_size_;

        for (auto& entry : entries_) {
            if (entry.valid && entry.line_addr == line_addr) {
                entry.valid = false;
                entry.line_addr = 0;
                entry.merged_requests = 0;
                count_--;
                return true;
            }
        }

        return false;
    }


    std::size_t size() const {
        return count_;
    }

private:
    std::vector<MSHREntry> entries_;
    std::size_t line_size_;
    std::size_t count_;
};

int main() {
    MSHRTable table(2, 64);

    assert(table.size() == 0);

    assert(table.allocate_or_merge(0));    // allocate line 0
    assert(table.size() == 1);

    assert(table.allocate_or_merge(8));    // merge into line 0
    assert(table.size() == 1);

    assert(table.allocate_or_merge(64));   // allocate line 1
    assert(table.size() == 2);

    assert(!table.allocate_or_merge(128)); // table full
    assert(table.complete(0));             // complete line 0
    assert(table.size() == 1);

    assert(table.allocate_or_merge(128));  // now line 2 can allocate
    assert(table.size() == 2);

    assert(!table.complete(192));          // line 3 was never allocated

    std::cout << "mshr_table tests passed\n";
    return 0;
}
