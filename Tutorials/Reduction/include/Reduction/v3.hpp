#pragma once

// Configuration constants
#define HIP_TEMPLATE_KERNEL_LAUNCH

// Reduction
#include <hip_utils.hpp>

// HIP API
#include <hip/hip_runtime.h>

// STL
#include <algorithm>
#include <chrono>
#include <cstddef>
#include <cstdlib>
#include <execution>
#include <iostream>
#include <iterator>
#include <random>
#include <span>
#include <utility>
#include <vector>

namespace reduction
{
template<typename T, typename F>
class v3
{
public:
    v3(const F&                kernel_op_in,
       const T                 zero_elem_in,
       const std::span<size_t> input_sizes_in,
       const std::span<size_t> block_sizes_in)
        : kernel_op{kernel_op_in}
        , zero_elem{zero_elem_in}
        , input_sizes{input_sizes_in}
        , block_sizes{block_sizes_in}
    {
        // Pessimistically allocate front buffer based on the largest input and the back buffer smallest reduction factor
        auto smallest_factor = *std::min_element(block_sizes_in.begin(), block_sizes_in.end());
        auto largest_size    = *std::max_element(input_sizes.begin(), input_sizes.end());
        HIP_CHECK(hipMalloc((void**)&front, sizeof(T) * largest_size));
        HIP_CHECK(hipMalloc((void**)&back, new_size(smallest_factor, largest_size) * sizeof(T)));
        origi_front = front;
        origi_back  = back;
    }

    ~v3()
    {
        HIP_CHECK(hipFree(front));
        HIP_CHECK(hipFree(back));
    }

    std::tuple<T, std::chrono::duration<float, std::milli>> operator()(std::span<const T> input,
                                                                       const std::size_t block_size,
                                                                       const std::size_t)
    {
        auto factor = block_size;
        HIP_CHECK(hipMemcpy(front, input.data(), input.size() * sizeof(T), hipMemcpyHostToDevice));

        hipEvent_t start, end;

        HIP_CHECK(hipEventCreate(&start));
        HIP_CHECK(hipEventCreate(&end));
        HIP_CHECK(hipEventRecord(start, 0));
        std::size_t curr = input.size();
        while (curr > 1)
        {
            hipLaunchKernelGGL(kernel,
                               dim3(new_size(factor, curr)),
                               dim3(block_size),
                               block_size * sizeof(T),
                               hipStreamDefault,
                               front,
                               back,
                               kernel_op,
                               zero_elem,
                               curr);
            hip::check(hipGetLastError(), "hipKernelLaunchGGL");

            curr = new_size(factor, curr);
            if (curr > 1)
                std::swap(front, back);
        }
        HIP_CHECK(hipEventRecord(end, 0));
        HIP_CHECK(hipEventSynchronize(end));

        T result;
        HIP_CHECK(hipMemcpy(&result, back, sizeof(T), hipMemcpyDeviceToHost));

        float elapsed_mseconds;
        HIP_CHECK(hipEventElapsedTime(&elapsed_mseconds, start, end));

        HIP_CHECK(hipEventDestroy(end));
        HIP_CHECK(hipEventDestroy(start));

        front = origi_front;
        back  = origi_back;

        return {result, std::chrono::duration<float, std::milli>{elapsed_mseconds}};
    }

private:
    F                      kernel_op;
    T                      zero_elem;
    std::span<std::size_t> input_sizes, block_sizes;
    T*                     front;
    T*                     back;
    T*                     origi_front;
    T*                     origi_back;

    std::size_t new_size(const std::size_t factor, const std::size_t actual)
    {
        return actual / factor + (actual % factor == 0 ? 0 : 1);
    }

    __global__ static void kernel(T* front, T* back, F op, T zero_elem, uint32_t front_size)
    {
        extern __shared__ T shared[];

        auto read_global_safe
            = [&](const uint32_t i) { return i < front_size ? front[i] : zero_elem; };

        const uint32_t tid = threadIdx.x,
                       bid = blockIdx.x,
                       gid = bid * blockDim.x + tid;

        // Read input from front buffer to shared
        shared[tid] = read_global_safe(gid);
        __syncthreads();

        // Shared reduction
        for (uint32_t i = blockDim.x / 2; i != 0; i /= 2)
        {
            if (tid < i)
                shared[tid] = op(shared[tid], shared[tid + i]);
            __syncthreads();
        }

        // Write result from shared to back buffer
        if (tid == 0)
            back[bid] = shared[0];
    }
};
} // namespace reduction