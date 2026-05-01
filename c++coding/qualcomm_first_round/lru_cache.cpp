#include <cassert>
#include <cstddef>
#include <list>
#include <iostream>
#include <unordered_map>

class LRUCache {
public:
    explicit LRUCache(std::size_t capacity)
        : capacity_(capacity) {
        assert(capacity > 0);
    }

    bool get(int key, int& value) {
        auto value_it = values_.find(key);
        if (value_it == values_.end()) {
            return false;
        }

        value = value_it->second;
        mark_most_recent(key);
        return true;
    }

    void put(int key, int value) {
        auto value_it = values_.find(key);
        if (value_it != values_.end()) {
            value_it->second = value;
            mark_most_recent(key);
            return;
        }

        if (values_.size() == capacity_) {
            int lru_key = recent_address_.back();
            recent_address_.pop_back();
            values_.erase(lru_key);
            position_.erase(lru_key);
        }

        recent_address_.push_front(key);
        values_[key] = value;
        position_[key] = recent_address_.begin();
    }

    std::size_t size() const {
        return values_.size();
    }

private:
    void mark_most_recent(int key) {
        auto position_it = position_.find(key);
        assert(position_it != position_.end());

        recent_address_.erase(position_it->second);
        recent_address_.push_front(key);
        position_it->second = recent_address_.begin();
    }

    std::size_t capacity_;
    std::list<int> recent_address_;
    std::unordered_map<int, int> values_;
    std::unordered_map<int, std::list<int>::iterator> position_;

};

int main() {
    LRUCache cache(2);

    int value = 0;

    cache.put(1, 10);
    cache.put(2, 20);

    assert(cache.get(1, value));
    assert(value == 10);

    cache.put(3, 30);

    assert(!cache.get(2, value));
    assert(cache.get(1, value));
    assert(value == 10);
    assert(cache.get(3, value));
    assert(value == 30);

    std::cout << "lru_cache tests passed\n";
    return 0;
}
