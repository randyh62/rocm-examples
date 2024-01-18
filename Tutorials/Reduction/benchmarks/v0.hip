// Reduction
#include <Reduction/v0.hpp>
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
    auto input_sizes = reduction::create_input_sizes();
    auto block_sizes = std::vector<std::size_t>{0};
    auto input       = reduction::create_input(input_sizes);

    // User-defined reduction
    auto kernel_op = [] __host__(unsigned lhs, unsigned rhs) { return std::max(lhs, rhs); };
    reduction::v0 reduce{kernel_op, std::numeric_limits<unsigned>::min(), input_sizes, block_sizes};

    auto benchmarks = reduction::create_benchmarks(input_sizes, block_sizes, input, reduce);
    benchmark::RunSpecifiedBenchmarks();

    return 0;
}
