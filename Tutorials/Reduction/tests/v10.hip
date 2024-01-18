// Reduction
#include <Reduction/v0.hpp>
#include <Reduction/v10.hpp>
#include <test_utils.hpp>

// Google Test
#include <gtest/gtest.h>

// STL
#include <limits>

int main(int argc, char** argv)
{
    // Initialize Google Test
    testing::InitGoogleTest(&argc, argv);

    // Initialize tests
    reduction::select_device_or_exit(&argc, argv);
    auto block_sizes = reduction::create_block_sizes();
    auto input_sizes = reduction::create_input_sizes();
    auto item_counts = reduction::create_items_per_threads();
    auto input       = reduction::create_input(input_sizes);

    // User-defined reduction
    auto          host_op = [] __host__(unsigned lhs, unsigned rhs) { return std::max(lhs, rhs); };
    reduction::v0 ref{host_op, std::numeric_limits<unsigned>::min(), input_sizes, block_sizes};
    auto          kernel_op = [] __device__(unsigned lhs, unsigned rhs) { return max(lhs, rhs); };
    reduction::v10 reduce{kernel_op, std::numeric_limits<unsigned>::min(), input_sizes, block_sizes};

    reduction::register_tests(input_sizes, block_sizes, item_counts, input, reduce, ref);

    return RUN_ALL_TESTS();
}
