#include <cassert>
#include <cstddef>
#include <iostream>
#include <vector>

class RingBuffer {
public:
    explicit RingBuffer(std::size_t capacity)
        : buffer_(capacity), head_(0), tail_(0), count_(0) {
        assert(capacity > 0);
    }

    bool push(int value) {
        if (full()) {
            return false;
        }

        buffer_[tail_] = value;
        tail_ = (tail_ + 1) % buffer_.size();
        count_++;
        return true;
    }

    bool pop() {
        if (empty()) {
            return false;
        }

        head_ = (head_ + 1) % buffer_.size();
        count_--;
        return true;
    }

    int front() const {
        // Assume caller checks !empty().
        return buffer_[head_];
    }

    bool empty() const {
        assert(count_ != 0 || head_ == tail_);
        return count_ == 0;
    }

    bool full() const {
        assert(count_ <= buffer_.size());
        assert((head_ == tail_) || count_ != buffer_.size());
        return count_ == buffer_.size();
    }

    std::size_t size() const {
        return count_;
    }

private:
    std::vector<int> buffer_;
    std::size_t head_;
    std::size_t tail_;
    std::size_t count_;
};

int main() {
    RingBuffer rb(3);

    // Expected behavior:
    // push 10, 20, 30 succeed.
    // push 40 fails because the buffer is full.
    // front is 10.
    // pop removes 10.
    // front becomes 20.
    // push 40 succeeds and wraps tail around.

    assert(rb.empty());
    assert(!rb.full());
    assert(rb.size() == 0);

    assert(rb.push(10));
    assert(!rb.empty());
    assert(!rb.full());
    assert(rb.size() == 1);
    assert(rb.front() == 10);

    assert(rb.push(20));
    assert(rb.push(30));
    assert(rb.full());
    assert(rb.size() == 3);
    assert(rb.front() == 10);

    assert(!rb.push(40));
    assert(rb.full());
    assert(rb.front() == 10);

    assert(rb.pop());
    assert(!rb.full());
    assert(rb.size() == 2);
    assert(rb.front() == 20);

    assert(rb.push(40));
    assert(rb.full());
    assert(rb.size() == 3);
    assert(rb.front() == 20);

    assert(rb.pop());
    assert(rb.front() == 30);
    assert(rb.pop());
    assert(rb.front() == 40);
    assert(rb.pop());
    assert(rb.empty());
    assert(rb.size() == 0);
    assert(!rb.pop());

    RingBuffer single_slot(1);
    assert(single_slot.empty());
    assert(!single_slot.full());
    assert(single_slot.push(7));
    assert(single_slot.full());
    assert(single_slot.front() == 7);
    assert(!single_slot.push(8));
    assert(single_slot.pop());
    assert(single_slot.empty());
    assert(!single_slot.pop());

    std::cout << "ring_buffer tests passed\n";
    return 0;
}
