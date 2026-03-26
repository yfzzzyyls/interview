// LC 1 - Two Sum
// Difficulty: Easy
//
// Given an array of integers `nums` and an integer `target`,
// return the indices of the two numbers such that they add up to `target`.
//
// - You may assume that each input has exactly one solution.
// - You may not use the same element twice.
// - You can return the answer in any order.
//
// Example 1:
//   Input: nums = [2, 7, 11, 15], target = 9
//   Output: [0, 1]    (because nums[0] + nums[1] == 9)
//
// Example 2:
//   Input: nums = [3, 2, 4], target = 6
//   Output: [1, 2]
//
// Constraints:
//   - 2 <= nums.length <= 10^4
//   - -10^9 <= nums[i] <= 10^9
//   - Only one valid answer exists.
//
// Follow-up: Can you come up with an algorithm that is less than O(n^2) time?

#include <stdio.h>
#include <stdlib.h>

// Return an array of 2 indices. Caller must free the result.
// *returnSize is set to 2.
int* twoSum(int* nums, int numsSize, int target, int* returnSize) {
    // your solution here
    int* result = (int*)malloc(numsSize * sizeof(int));
    int count = 0;
    for (int i = 0; i < numsSize; i++){
        for (int j = 1; i < numSize; i++){
            if (nums[i] + nums[j] == target)
                result[count] = (i <= j) ? i : j;
                result[count + 1] = (i > j) ? i : j;
        }
    }
    return result;
}

int main() {
    int returnSize;

    int nums1[] = {2, 7, 11, 15};
    int* res1 = twoSum(nums1, 4, 9, &returnSize);
    printf("[%d, %d]\n", res1[0], res1[1]); // [0, 1]
    free(res1);

    int nums2[] = {3, 2, 4};
    int* res2 = twoSum(nums2, 3, 6, &returnSize);
    printf("[%d, %d]\n", res2[0], res2[1]); // [1, 2]
    free(res2);

    int nums3[] = {3, 3};
    int* res3 = twoSum(nums3, 2, 6, &returnSize);
    printf("[%d, %d]\n", res3[0], res3[1]); // [0, 1]
    free(res3);

    printf("PASS\n");
    return 0;
}
