#include <cassert>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <vector>

struct StoreEntry {
    bool address_known = false;
    std::uint64_t address = 0;
    int value = 0;
};

enum class LoadForwardKind {
    NoForward,
    Forwarded,
    BlockedByUnknownStore
};

struct LoadForwardResult {
    LoadForwardKind kind = LoadForwardKind::NoForward;
    int value = 0;
};

class StoreQueue {
public:
    explicit StoreQueue(std::size_t capacity) : capacity_(capacity) {
        assert(capacity > 0);
    }

    bool push_known(std::uint64_t address, int value) {
        // Steps:
        // 1. If the store queue is full, reject the store.
        // 2. Append a known-address store as the youngest store.
        if (entries_.size() == capacity_) {
            return false;
        }

        entries_.push_back(StoreEntry{true, address, value});
        return true;
    }

    bool push_unknown(int value) {
        // Steps:
        // 1. If the store queue is full, reject the store.
        // 2. Append a store whose address is not known yet.
        if (entries_.size() == capacity_) {
            return false;
        }

        entries_.push_back(StoreEntry{false, 0, value});
        return true;
    }

    bool resolve_oldest_unknown(std::uint64_t address) {
        // Steps:
        // 1. Find the oldest store with unknown address.
        // 2. Fill in its address.
        for (auto& entry : entries_) {
            if (!entry.address_known) {
                entry.address_known = true;
                entry.address = address;
                return true;
            }
        }

        return false;
    }

    LoadForwardResult forward_load(std::uint64_t address) const {
        // Steps:
        // 1. Search older stores from youngest to oldest.
        // 2. If a newer unknown-address store is found first, block.
        // 3. If a known address matches, forward its value.
        // 4. If nothing matches, load can go to cache.
        for (auto it = entries_.rbegin(); it != entries_.rend(); ++it) {
            if (!it->address_known) {
                return {LoadForwardKind::BlockedByUnknownStore, 0};
            }
            if (it->address == address) {
                return {LoadForwardKind::Forwarded, it->value};
            }
        }

        return {LoadForwardKind::NoForward, 0};
    }

    bool commit_oldest() {
        // Steps:
        // 1. If empty, nothing can commit.
        // 2. Remove the oldest store from the front.
        if (entries_.empty()) {
            return false;
        }

        entries_.erase(entries_.begin());
        return true;
    }

    std::size_t size() const {
        return entries_.size();
    }

private:
    std::size_t capacity_;
    std::vector<StoreEntry> entries_;
};

int main() {
    StoreQueue sq(3);

    LoadForwardResult result = sq.forward_load(100);
    assert(result.kind == LoadForwardKind::NoForward);

    assert(sq.push_known(100, 42));
    result = sq.forward_load(100);
    assert(result.kind == LoadForwardKind::Forwarded);
    assert(result.value == 42);

    assert(sq.push_unknown(77));
    result = sq.forward_load(100);
    assert(result.kind == LoadForwardKind::BlockedByUnknownStore);

    assert(sq.resolve_oldest_unknown(200));
    result = sq.forward_load(100);
    assert(result.kind == LoadForwardKind::Forwarded);
    assert(result.value == 42);

    assert(sq.push_known(100, 99));
    result = sq.forward_load(100);
    assert(result.kind == LoadForwardKind::Forwarded);
    assert(result.value == 99);

    assert(!sq.push_known(300, 1));
    assert(sq.commit_oldest());
    assert(sq.push_known(300, 1));
    assert(sq.size() == 3);

    std::cout << "store_queue_forwarding tests passed\n";
    return 0;
}
