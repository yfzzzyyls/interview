// Part 2 / Block 1: Compile, I/O, and Basic Types
//
// Goal:
// Practice writing a complete C++ program from scratch:
// - headers
// - main()
// - console output
// - integer and floating-point types
// - sizeof()
// - signed vs unsigned behavior
//
// Tasks:
//
// 1. Add the headers you need.
//
// 2. Write a main() function.
//
// 3. Print a short label saying this is Block 1.
//
// 4. Declare several variables:
//    - int
//    - unsigned int
//    - long long
//    - unsigned long long
//    - float
//    - double
//    - bool
//    - char
//
// 5. Print each variable's value and sizeof(variable).
//
// 6. Create one signed integer with value -1.
//    Create one unsigned integer with value 1.
//    Compare them carefully and print the result.
//    Then explain in a comment why the result may be surprising.
//
// 7. Create one address-like value using an unsigned integer type.
//    Example concept: an address, cache line address, or byte offset.
//    Print the value in decimal and hexadecimal.
//
// 8. Add at least two small comments explaining:
//    - why unsigned types are common for addresses and bit manipulation
//    - why signed/unsigned mixing can be dangerous
//
// 9. Compile with:
//    g++ -std=c++17 -Wall -Wextra -pedantic 01_compile_io_types.cpp -o 01_compile_io_types
//
// 10. Run it and check that there are no warnings.

#include <iostream>
#include <cstdint>

void block1() {
    std::cout << "This is Block 1\n";
}

int main() {
    block1();

    int a = 100;
    unsigned int ua = 200u;
    long long ll = -9000000000LL;
    unsigned long long ull = 9000000000ULL;
    float f = 3.14f;
    double d = 3.141592653589793;
    bool b = true;
    char c = 'k';

    std::cout << "int value = " << a << ", size = " << sizeof(a) << "\n";
    std::cout << "unsigned int value = " << ua << ", size = " << sizeof(ua) << "\n";
    std::cout << "long long value = " << ll << ", size = " << sizeof(ll) << "\n";
    std::cout << "unsigned long long value = " << ull << ", size = " << sizeof(ull) << "\n";
    std::cout << "float value = " << f << ", size = " << sizeof(f) << "\n";
    std::cout << "double value = " << d << ", size = " << sizeof(d) << "\n";
    std::cout << "bool value = " << b << ", size = " << sizeof(b) << "\n";
    std::cout << "char value = " << c << ", size = " << sizeof(c) << "\n";

    int signed_value = -1;
    unsigned int unsigned_value = 1u;

    std::cout << std::boolalpha;
    std::cout << "safe signed comparison: "
              << (static_cast<int>(unsigned_value) > signed_value) << "\n";

    // Mixing signed and unsigned is dangerous because negative signed values
    // are converted to large unsigned values before comparison.
    std::cout << "comparison after unsigned conversion: "
              << (unsigned_value > static_cast<unsigned int>(signed_value)) << "\n";

    // Unsigned types are common for addresses and bit manipulation because
    // addresses are non-negative bit patterns, not signed arithmetic values.
    std::uint32_t addr = 0x80000000u;
    std::cout << "addr decimal = " << std::dec << addr << "\n";
    std::cout << "addr hex = 0x" << std::hex << addr << std::dec << "\n";

    return 0;
}
