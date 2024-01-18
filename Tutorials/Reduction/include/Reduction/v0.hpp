#pragma once

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
template<typename T, typename BinaryOperator>
class v0
{
public:
    v0(const BinaryOperator& host_op_in,
       const T               zero_elem_in,
       const std::span<size_t>,
       const std::span<size_t>)
        : host_op{host_op_in}, zero_elem{zero_elem_in}
    {}

    std::tuple<T, std::chrono::duration<float, std::milli>> operator()(std::span<const T> input,
                                                                       const std::size_t,
                                                                       const std::size_t)
    {
        std::chrono::high_resolution_clock::time_point start, end;

        start       = std::chrono::high_resolution_clock::now();
        auto result = std::reduce(std::execution::par_unseq,
                                  input.begin(),
                                  input.end(),
                                  zero_elem,
                                  host_op);
        end         = std::chrono::high_resolution_clock::now();

        return {result,
                std::chrono::duration_cast<std::chrono::duration<float, std::milli>>(end - start)};
    }

private:
    BinaryOperator host_op;
    T              zero_elem;
};
} // namespace reduction
