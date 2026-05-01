#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

struct CacheLine {
    bool valid = false;
    std::uint64_t tag = 0;
};

class DirectMappedCache {
public:
    DirectMappedCache(std::size_t num_lines, std::size_t line_size)
        : lines_(num_lines), line_size_(line_size) {
        assert(num_lines > 0);
        assert(line_size > 0);
    }

    bool access(std::uint64_t address) {
        std::uint64_t line_addr = address / line_size_;
        std::size_t index = line_addr % lines_.size();
        std::uint64_t tag = line_addr / lines_.size();

        CacheLine& line = lines_[index];

        if (line.valid && line.tag == tag) {
            return true;
        }

        line.valid = true;
        line.tag = tag;
        return false;
    }


private:
    std::vector<CacheLine> lines_;
    std::size_t line_size_;
};

int main() {
    DirectMappedCache cache(4, 64);

    assert(!cache.access(0));    // miss, fills index 0
    assert(cache.access(0));     // hit
    assert(!cache.access(256));  // miss, conflicts with address 0
    assert(!cache.access(0));    // miss again, because 256 evicted it

    std::cout << "direct_mapped_cache tests passed\n";
    return 0;
}
