#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

struct CacheLine {
    bool valid = false;
    std::uint64_t tag = 0;
    std::size_t last_used = 0;
};

class SetAssociativeCache {
public:
    SetAssociativeCache(std::size_t num_sets,
                        std::size_t num_ways,
                        std::size_t line_size)
        : lines_(num_sets * num_ways),
          num_sets_(num_sets),
          num_ways_(num_ways),
          line_size_(line_size),
          access_counter_(0) {
        assert(num_sets > 0);
        assert(num_ways > 0);
        assert(line_size > 0);
    }

    bool access(std::uint64_t address) {
        std::uint64_t line_addr = address / line_size_;
        std::size_t set_index = line_addr % num_sets_;
        std::uint64_t tag = line_addr / num_sets_;

        for (std::size_t way = 0; way < num_ways_; ++way) {
            std::size_t vector_index = set_index * num_ways_ + way;
            CacheLine& line = lines_[vector_index];

            if (line.valid && line.tag == tag) {
                access_counter_++;
                line.last_used = access_counter_;
                return true;
            }
        }

        CacheLine* victim = nullptr;

        for (std::size_t way = 0; way < num_ways_; ++way) {
            std::size_t vector_index = set_index * num_ways_ + way;
            CacheLine& line = lines_[vector_index];

            if (!line.valid) {
                victim = &line;
                break;
            }

            if (victim == nullptr || line.last_used < victim->last_used) {
                victim = &line;
            }
        }

        assert(victim != nullptr);

        access_counter_++;
        victim->valid = true;
        victim->tag = tag;
        victim->last_used = access_counter_;

        return false;
    }

private:
    std::vector<CacheLine> lines_;
    std::size_t num_sets_;
    std::size_t num_ways_;
    std::size_t line_size_;
    std::size_t access_counter_;
};

int main() {
    SetAssociativeCache cache(2, 2, 64);

    assert(!cache.access(0));    // set 0, tag 0 miss
    assert(cache.access(0));     // hit
    assert(!cache.access(128));  // set 0, tag 1 miss, same set, different way
    assert(cache.access(0));     // still hit because set is 2-way
    assert(!cache.access(256));  // set 0, tag 2 miss, evicts LRU way
    assert(!cache.access(128));  // 128 was evicted
    assert(!cache.access(0));    // 128 miss filled again, so 0 was evicted
    assert(cache.access(128));   // 128 should now be present

    std::cout << "set_associative_cache tests passed\n";
    return 0;
}
