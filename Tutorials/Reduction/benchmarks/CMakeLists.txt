set(GPU_RUNTIME HIP CACHE STRING "Switches between HIP and CUDA")
set(GPU_RUNTIMES HIP CUDA)
set_property(CACHE GPU_RUNTIME PROPERTY STRINGS ${GPU_RUNTIMES})

if(GPU_RUNTIME STREQUAL HIP)
  cmake_minimum_required(VERSION 3.21)
  cmake_policy(VERSION 3.21...3.27)
else()
  cmake_minimum_required(VERSION 3.8)
  cmake_policy(VERSION 3.8...3.27)
endif()

# libstdc++ Parallel STL on Ubuntu 20.04 requires explicit linking to TBB
if(CMAKE_HOST_APPLE)
  # TODO: The macro name used to detect TBB dependence differs on MacOS
  set(STL_DEPENDS_ON_TBB ON)
else()
  include(CMakePrintHelpers)
  include(CheckCXXSymbolExists)
  set(CMAKE_REQUIRED_FLAGS "-std=c++17")
  check_cxx_symbol_exists(
      __PSTL_PAR_BACKEND_TBB "cstddef" STL_DEPENDS_ON_TBB0)
  if (NOT STL_DEPENDS_ON_TBB0)
      check_cxx_symbol_exists(
          _PSTL_PAR_BACKEND_TBB "cstddef" STL_DEPENDS_ON_TBB1)
  endif ()
endif()
if (STL_DEPENDS_ON_TBB0 OR STL_DEPENDS_ON_TBB1)
  find_package(TBB REQUIRED)
endif()

find_package(benchmark CONFIG QUIET)
if(NOT TARGET benchmark::benchmark)
  message(STATUS "Google Benchmark not found. Fetching...")
  option(BENCHMARK_ENABLE_TESTING "Enable testing of the benchmark library." OFF)
  option(BENCHMARK_ENABLE_INSTALL "Enable installation of benchmark." OFF)
  include(FetchContent)
  FetchContent_Declare(
    googlebench
    GIT_REPOSITORY https://github.com/google/benchmark.git
    GIT_TAG        v1.6.1
  )
  FetchContent_MakeAvailable(googlebench)
  if(NOT TARGET benchmark::benchmark)
    add_library(benchmark::benchmark ALIAS benchmark)
  endif()
else()
  find_package(benchmark CONFIG REQUIRED)
endif()

foreach(VER RANGE 0 10)
  set(Sources v${VER}.hip)
  set(TargetName Benchmark-v${VER})

  add_executable(${TargetName}
    ${Sources}
  )

  target_include_directories(${TargetName}
    PRIVATE
      "${CMAKE_CURRENT_LIST_DIR}"
  )

  target_link_libraries(${TargetName}
    PRIVATE
      Reduction
      benchmark::benchmark
      $<$<TARGET_EXISTS:TBB::tbb>:TBB::tbb>
  )

  set_target_properties(${TargetName}
    PROPERTIES
      ${GPU_RUNTIME}_STANDARD 20
      ${GPU_RUNTIME}_EXTENSIONS OFF
      ${GPU_RUNTIME}_STANDARD_REQUIRED ON
  )

  if(GPU_RUNTIME STREQUAL CUDA)
    set_source_files_properties(${Sources}
      PROPERTIES
        LANGUAGE ${GPU_RUNTIME}
    )
    find_package(HIP MODULE REQUIRED)
    target_include_directories(${TargetName}
      PRIVATE
        "${HIP_ROOT_DIR}/include"
    )
  endif()
endforeach()
