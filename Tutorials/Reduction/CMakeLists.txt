cmake_minimum_required(VERSION 3.21)
cmake_policy(VERSION 3.21...3.27)
enable_testing()

project(Reduction LANGUAGES HIP)

option(REDUCTION_BUILD_TESTING "Build Reduction tests" ON)
option(REDUCTION_BUILD_BENCHMARKS "Build Reduction benchmarks" ON)
option(REDUCTION_BUILD_EXAMPLES "Build Reduction examples" ON)

add_library(Reduction IMPORTED INTERFACE)

target_include_directories(Reduction
  INTERFACE
    include
)

if(REDUCTION_BUILD_TESTING)
  enable_language(CXX) # GTest::GTest depends on Threads::Threads
  add_subdirectory(tests)
endif()

if(REDUCTION_BUILD_BENCHMARKS)
  enable_language(CXX) # benchmark::benchmark depends on Threads::Threads
  add_subdirectory(benchmarks)
endif()

if(REDUCTION_BUILD_EXAMPLES)
  enable_language(CXX) # TBB::tbb depends on Threads::Threads
  add_subdirectory(examples)
endif()
