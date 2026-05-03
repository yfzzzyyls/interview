#include <cassert>
#include <cstdint>
#include <functional>
#include <iostream>
#include <queue>
#include <utility>
#include <vector>

struct Event {
    std::uint64_t cycle = 0;
    std::uint64_t sequence = 0;
    std::function<void()> action;
};

struct EventLater {
    bool operator()(const Event& lhs, const Event& rhs) const {
        if (lhs.cycle != rhs.cycle) {
            return lhs.cycle > rhs.cycle;
        }
        return lhs.sequence > rhs.sequence;
    }
};

class EventQueue {
public:
    EventQueue() : current_cycle_(0), next_sequence_(0) {}

    void schedule(std::uint64_t delay, std::function<void()> action) {
        // Steps:
        // 1. Convert relative delay to absolute target cycle.
        // 2. Add a sequence number for stable same-cycle order.
        // 3. Push into a min-priority queue ordered by cycle.
        events_.push(Event{current_cycle_ + delay, next_sequence_++, std::move(action)});
    }

    bool run_next() {
        // Steps:
        // 1. If no events are pending, return false.
        // 2. Pop earliest event.
        // 3. Advance simulation time to that event's cycle.
        // 4. Execute the event action.
        if (events_.empty()) {
            return false;
        }

        Event event = events_.top();
        events_.pop();
        current_cycle_ = event.cycle;
        event.action();
        return true;
    }

    void run_until_empty() {
        while (run_next()) {
        }
    }

    std::uint64_t now() const {
        return current_cycle_;
    }

    std::size_t size() const {
        return events_.size();
    }

private:
    std::uint64_t current_cycle_;
    std::uint64_t next_sequence_;
    std::priority_queue<Event, std::vector<Event>, EventLater> events_;
};

int main() {
    EventQueue queue;
    std::vector<int> order;
    int value = 0;

    queue.schedule(5, [&] {
        order.push_back(5);
        value += 5;
    });
    queue.schedule(2, [&] {
        order.push_back(2);
        value += 2;
    });
    queue.schedule(2, [&] {
        order.push_back(20);
        value += 20;
    });

    assert(queue.size() == 3);
    assert(queue.run_next());
    assert(queue.now() == 2);
    assert(order == std::vector<int>({2}));

    queue.run_until_empty();
    assert(queue.now() == 5);
    assert((order == std::vector<int>{2, 20, 5}));
    assert(value == 27);
    assert(!queue.run_next());

    std::cout << "event_queue tests passed\n";
    return 0;
}
