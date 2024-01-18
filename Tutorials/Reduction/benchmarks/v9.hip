// Reduction
#include <Reduction/v9.hpp>
#include <bench_utils.hpp>

// Google Benchmark
#include <benchmark/benchmark.h>

// STL
#include <limits>

int main(int argc, char** argv)
{
    // Initialize Google Benchmark
    benchmark::Initialize(&argc, argv);

    // Initialize benchmarks
    reduction::select_device_or_exit(&argc, argv);
    reduction::add_common_benchmark_info();
    auto input_sizes = reduction::create_input_sizes();
    auto block_sizes = reduction::create_block_sizes();
    auto item_counts = reduction::create_items_per_threads();
    auto input       = reduction::create_input(input_sizes);

    // User-defined reduction
    auto          kernel_op = [] __device__(unsigned lhs, unsigned rhs) { return max(lhs, rhs); };
    reduction::v9 reduce{kernel_op, std::numeric_limits<unsigned>::min(), input_sizes, block_sizes};

    auto benchmarks = reduction::create_benchmarks(input_sizes, block_sizes, item_counts, input, reduce);
    benchmark::RunSpecifiedBenchmarks();

    return 0;
}
