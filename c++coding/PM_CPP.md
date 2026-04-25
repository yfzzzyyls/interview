# C/C++ Interview Practice

## Goal

Practice C/C++ coding for interviews in a structured, progressive way.

Build confidence and fluency in:

- C/C++ fundamentals (pointers, memory, STL)
- Core data structures (arrays, linked lists, stacks, trees, graphs)
- Algorithm patterns (two pointers, sliding window, binary search, BFS/DFS)
- Dynamic programming and backtracking
- Writing clean, correct, interview-quality code under time pressure

## Intention

Use an interviewer-style format instead of passive study.

Claude acts as the C/C++ coding interviewer and:

- asks one question at a time
- starts from easy, classic, fundamental problems
- increases difficulty gradually
- reviews the submitted answer like an interviewer
- points out correctness issues, edge cases, and complexity concerns
- gives follow-up questions when useful

The user writes the solution first. The goal is active practice, not immediate solution dumping.

## Methodology

1. Start with very simple problems.
2. Solve one problem at a time.
3. Review the answer for:
   - correctness (logic, edge cases)
   - time and space complexity
   - C/C++ style and idiom
   - interview quality
4. If needed, give a corrected version and explain the key issue briefly.
5. Move to the next question only after the current one is understood.

## Session Style

- Mode: interviewer mode
- Pace: step by step
- Initial difficulty: easy
- Question style: classic and fundamental C/C++ interview questions
- Primary language: C/C++

## Review Standard

Each answer should be judged by questions such as:

- Does it meet the exact requirement?
- Does it handle edge cases (empty input, single element, overflow)?
- What is the time and space complexity?
- Is there a simpler or more idiomatic way to write it?
- Would this answer be acceptable in a real interview?

When reviewing submitted code:

- first give a short summary of the current status
- then walk through the issues one by one
- after the summary, focus on one fix at a time until the current issue is resolved
- once the code is correct, also comment on whether it is already good as an interview answer
- if there is a cleaner, more standard, or more optimal solution, propose that improvement briefly
- if the submitted solution is already solid, simply say it is good instead of forcing extra optimization advice

## Folder Layout

- `01_arrays_strings/`
- `02_math_bit_manipulation/`
- `03_linked_list/`
- `04_stack_queue/`
- `05_hashmap/`
- `06_two_pointers/`
- `07_sliding_window/`
- `08_binary_search/`
- `09_tree_bst/`
- `10_graph/`
- `11_dynamic_programming/`
- `12_interval_matrix/`
- `13_backtracking_heap_trie/`

## File Convention

For each new question:

- create one `.cpp` file for the solution
- name the file descriptively, e.g., `lc88_merge_sorted_array.cpp`
- include a comment block at the top with the problem description and constraints
- expect the user to fill in the solution

## Working Agreement

- Keep the practice interactive.
- Do not skip straight to advanced problems.
- Prefer small, common problems before full design questions.
- Use mistakes as teaching points.
- Every review should start with a short summary, then continue with a one-by-one walkthrough of the issues.
- After a solution is correct, reviews should also mention whether it is already good or whether there is a better standard/optimized solution.
- Resume from this document if the session context is lost.

---

## Study Plan — Priority Order for Interview Prep

Problems sourced from [LeetCode Top Interview 150](https://leetcode.com/studyplan/top-interview-150/). Organized by topic, ordered easy → medium → hard within each section. Problems the user has already solved are marked with ✅.

### Phase 1 — Fundamentals (do these first)

These are the bread and butter. If you only have a few hours, focus here.

#### 01 — Arrays & Strings

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 88 | Merge Sorted Array | Easy | ✅ |
| 🔴 | 27 | Remove Element | Easy | ✅ |
| 🔴 | 26 | Remove Duplicates from Sorted Array | Easy | ✅ |
| 🔴 | 169 | Majority Element | Easy | ✅ |
| 🔴 | 121 | Best Time to Buy and Sell Stock | Easy | ✅ |
| 🔴 | 13 | Roman to Integer | Easy | ✅ |
| 🔴 | 58 | Length of Last Word | Easy | ✅ |
| 🔴 | 14 | Longest Common Prefix | Easy | ✅ |
| 🔴 | 28 | Find the Index of First Occurrence | Easy | ✅ |
| 🔴 | 238 | Product of Array Except Self | Medium | ✅ |
| 🔴 | 55 | Jump Game | Medium | ✅ |
| 🟡 | 189 | Rotate Array | Medium | |
| 🟡 | 80 | Remove Duplicates from Sorted Array II | Medium | |
| 🟡 | 45 | Jump Game II | Medium | |
| 🟡 | 134 | Gas Station | Medium | |
| 🟡 | 151 | Reverse Words in a String | Medium | |
| 🟡 | 6 | Zigzag Conversion | Medium | ✅ |
| 🟢 | 274 | H-Index | Medium | |
| 🟢 | 380 | Insert Delete GetRandom O(1) | Medium | |
| 🟢 | 42 | Trapping Rain Water | Hard | |
| 🟢 | 135 | Candy | Hard | |
| 🟢 | 68 | Text Justification | Hard | |

#### 02 — Math & Bit Manipulation

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 9 | Palindrome Number | Easy | ✅ |
| 🔴 | 66 | Plus One | Easy | ✅ |
| 🔴 | 69 | Sqrt(x) | Easy | ✅ |
| 🔴 | 136 | Single Number | Easy | ✅ |
| 🔴 | 191 | Number of 1 Bits | Easy | ✅ |
| 🔴 | 190 | Reverse Bits | Easy | ✅ |
| 🟡 | 67 | Add Binary | Easy | |
| 🟡 | 137 | Single Number II | Medium | |
| 🟡 | 50 | Pow(x, n) | Medium | |
| 🟡 | 172 | Factorial Trailing Zeroes | Medium | |
| 🟢 | 201 | Bitwise AND of Numbers Range | Medium | |
| 🟢 | 149 | Max Points on a Line | Hard | |

#### 05 — Hashmap

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 383 | Ransom Note | Easy | ✅ |
| 🔴 | 205 | Isomorphic Strings | Easy | ✅ |
| 🔴 | 1 | Two Sum | Easy | |
| 🔴 | 242 | Valid Anagram | Easy | |
| 🔴 | 49 | Group Anagrams | Medium | ✅ |
| 🟡 | 290 | Word Pattern | Easy | |
| 🟡 | 202 | Happy Number | Easy | |
| 🟡 | 219 | Contains Duplicate II | Easy | |
| 🟡 | 128 | Longest Consecutive Sequence | Medium | ✅ |

### Phase 2 — Core Patterns (high ROI techniques)

These patterns show up repeatedly. Master the technique, not just individual problems.

#### 06 — Two Pointers

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 125 | Valid Palindrome | Easy | ✅ |
| 🔴 | 392 | Is Subsequence | Easy | ✅ |
| 🔴 | 167 | Two Sum II | Medium | |
| 🔴 | 11 | Container With Most Water | Medium | ✅ |
| 🔴 | 15 | 3Sum | Medium | ✅ |

#### 07 — Sliding Window

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 209 | Minimum Size Subarray Sum | Medium | ✅ |
| 🔴 | 3 | Longest Substring Without Repeating Characters | Medium | ✅ |
| 🟡 | 30 | Substring with Concatenation of All Words | Hard | |
| 🟡 | 76 | Minimum Window Substring | Hard | |

#### 08 — Binary Search

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 35 | Search Insert Position | Easy | ✅ |
| 🔴 | 74 | Search a 2D Matrix | Medium | |
| 🔴 | 162 | Find Peak Element | Medium | ✅ |
| 🔴 | 33 | Search in Rotated Sorted Array | Medium | ✅ |
| 🟡 | 34 | Find First and Last Position | Medium | |
| 🟡 | 153 | Find Minimum in Rotated Sorted Array | Medium | |
| 🟢 | 4 | Median of Two Sorted Arrays | Hard | |

#### 04 — Stack & Queue

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 20 | Valid Parentheses | Easy | ✅ |
| 🔴 | 150 | Evaluate Reverse Polish Notation | Medium | ✅ |
| 🟡 | 155 | Min Stack | Medium | |
| 🟡 | 71 | Simplify Path | Medium | |
| 🟢 | 224 | Basic Calculator | Hard | |

### Phase 3 — Data Structures (linked lists, trees, graphs)

#### 03 — Linked List

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 141 | Linked List Cycle | Easy | ✅ |
| 🔴 | 21 | Merge Two Sorted Lists | Easy | ✅ |
| 🔴 | 2 | Add Two Numbers | Medium | ✅ |
| 🔴 | 92 | Reverse Linked List II | Medium | ✅ |
| 🟡 | 19 | Remove Nth Node From End of List | Medium | |
| 🟡 | 82 | Remove Duplicates from Sorted List II | Medium | |
| 🟡 | 61 | Rotate List | Medium | |
| 🟡 | 86 | Partition List | Medium | |
| 🟡 | 138 | Copy List with Random Pointer | Medium | |
| 🟢 | 25 | Reverse Nodes in k-Group | Hard | |
| 🟢 | 146 | LRU Cache | Medium | |

#### 09 — Tree & BST

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 104 | Maximum Depth of Binary Tree | Easy | ✅ |
| 🔴 | 100 | Same Tree | Easy | ✅ |
| 🔴 | 226 | Invert Binary Tree | Easy | |
| 🔴 | 101 | Symmetric Tree | Easy | |
| 🔴 | 112 | Path Sum | Easy | |
| 🔴 | 102 | Binary Tree Level Order Traversal | Medium | ✅ |
| 🔴 | 98 | Validate Binary Search Tree | Medium | ✅ |
| 🔴 | 236 | Lowest Common Ancestor | Medium | ✅ |
| 🔴 | 108 | Convert Sorted Array to BST | Easy | ✅ |
| 🟡 | 530 | Minimum Absolute Difference in BST | Easy | ✅ |
| 🟡 | 637 | Average of Levels in Binary Tree | Easy | ✅ |
| 🟡 | 105 | Construct BT from Preorder and Inorder | Medium | |
| 🟡 | 114 | Flatten Binary Tree to Linked List | Medium | |
| 🟡 | 199 | Binary Tree Right Side View | Medium | |
| 🟡 | 129 | Sum Root to Leaf Numbers | Medium | |
| 🟡 | 222 | Count Complete Tree Nodes | Easy | |
| 🟡 | 173 | Binary Search Tree Iterator | Medium | |
| 🟢 | 124 | Binary Tree Maximum Path Sum | Hard | |

#### 10 — Graph

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 200 | Number of Islands | Medium | ✅ |
| 🔴 | 433 | Minimum Genetic Mutation | Medium | ✅ |
| 🟡 | 130 | Surrounded Regions | Medium | |
| 🟡 | 133 | Clone Graph | Medium | |
| 🟡 | 207 | Course Schedule | Medium | |
| 🟡 | 210 | Course Schedule II | Medium | |
| 🟢 | 127 | Word Ladder | Hard | |

### Phase 4 — Advanced (if time allows)

#### 11 — Dynamic Programming

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 70 | Climbing Stairs | Easy | ✅ |
| 🔴 | 198 | House Robber | Medium | ✅ |
| 🔴 | 53 | Maximum Subarray (Kadane's) | Medium | ✅ |
| 🟡 | 322 | Coin Change | Medium | |
| 🟡 | 139 | Word Break | Medium | |
| 🟡 | 300 | Longest Increasing Subsequence | Medium | |
| 🟡 | 64 | Minimum Path Sum | Medium | |
| 🟡 | 120 | Triangle | Medium | |
| 🟡 | 5 | Longest Palindromic Substring | Medium | |
| 🟡 | 72 | Edit Distance | Medium | |
| 🟡 | 918 | Maximum Sum Circular Subarray | Medium | |
| 🟢 | 97 | Interleaving String | Medium | |
| 🟢 | 221 | Maximal Square | Medium | |
| 🟢 | 63 | Unique Paths II | Medium | |

#### 12 — Interval & Matrix

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 228 | Summary Ranges | Easy | ✅ |
| 🔴 | 56 | Merge Intervals | Medium | ✅ |
| 🔴 | 57 | Insert Interval | Medium | ✅ |
| 🔴 | 48 | Rotate Image | Medium | ✅ |
| 🔴 | 73 | Set Matrix Zeroes | Medium | ✅ |
| 🔴 | 36 | Valid Sudoku | Medium | ✅ |
| 🟡 | 452 | Minimum Number of Arrows | Medium | |
| 🟡 | 54 | Spiral Matrix | Medium | |
| 🟡 | 289 | Game of Life | Medium | |

#### 13 — Backtracking, Heap & Trie

| Priority | LC# | Problem | Difficulty | Status |
|----------|-----|---------|------------|--------|
| 🔴 | 22 | Generate Parentheses | Medium | ✅ |
| 🔴 | 215 | Kth Largest Element in Array | Medium | ✅ |
| 🔴 | 208 | Implement Trie | Medium | ✅ |
| 🟡 | 46 | Permutations | Medium | |
| 🟡 | 39 | Combination Sum | Medium | |
| 🟡 | 77 | Combinations | Medium | |
| 🟡 | 17 | Letter Combinations of Phone Number | Medium | |
| 🟡 | 79 | Word Search | Medium | |
| 🟡 | 148 | Sort List | Medium | |
| 🟡 | 23 | Merge k Sorted Lists | Hard | |
| 🟡 | 211 | Design Add and Search Words | Medium | |
| 🟢 | 52 | N-Queens II | Hard | ✅ |
| 🟢 | 295 | Find Median from Data Stream | Hard | |
| 🟢 | 212 | Word Search II | Hard | |

---

## Priority Legend

- 🔴 **Must do** — very high frequency in interviews, do these first
- 🟡 **Should do** — common patterns, do if time allows
- 🟢 **Nice to have** — less common or harder, skip under time pressure

## Night-Before Strategy

If you only have a few hours:

1. **Review your ✅ solved problems** — re-read solutions, make sure you can reproduce them
2. **Do 2-3 unsolved 🔴 problems** from Phase 1-2 — focus on Two Sum, Two Sum II, Min Stack
3. **Review patterns** — make sure you can recognize when to use two pointers, sliding window, binary search, BFS/DFS
4. **Practice talking through your approach** — interviewers care about communication as much as code

## C/C++ Interview Tips

- Always clarify input constraints before coding
- State your approach and complexity before writing code
- Handle edge cases: empty input, single element, overflow, null pointers
- Use `const` references for read-only parameters
- Know STL basics: `vector`, `unordered_map`, `stack`, `queue`, `priority_queue`, `sort`
- Know when to use `new`/`delete` vs stack allocation vs smart pointers
- If stuck, start with brute force and optimize

## EDA Tools on This Server

- Compile C++: `g++ -std=c++17 -o solution solution.cpp && ./solution`
