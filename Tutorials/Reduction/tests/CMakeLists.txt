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

# NOTE1: Google Test has created a mess with legacy FindGTest.cmake and newer GTestConfig.cmake
#
# FindGTest.cmake defines:   GTest::GTest, GTest::Main, GTEST_FOUND
#
# GTestConfig.cmake defines: GTest::gtest, GTest::gtest_main, GTest::gmock, GTest::gmock_main
#
# NOTE2: Finding GTest in MODULE mode, one cannot invoke find_package in CONFIG mode, because targets
#        will be duplicately defined.
#
# NOTE3: The following snippet first tries to find Google Test binary either in MODULE or CONFIG modes.
#        If neither succeeds it goes on to import Google Test into this build either from a system
#        source package (apt install googletest on Ubuntu 18.04 only) or GitHub and defines the MODULE
#        mode targets. Otherwise if MODULE or CONFIG succeeded, then it prints the result to the
#        console via a non-QUIET find_package call and if CONFIG succeeded, creates ALIAS targets
#        with the MODULE IMPORTED names.
find_package(GTest QUIET)
if(NOT TARGET GTest::GTest AND NOT TARGET GTest::gtest)
  option(BUILD_GTEST "Builds the googletest subproject" ON)
  option(BUILD_GMOCK "Builds the googlemock subproject" OFF)
  option(INSTALL_GTEST "Enable installation of googletest." OFF)
  include(FetchContent)
  if(EXISTS /usr/src/googletest AND NOT DEPENDENCIES_FORCE_DOWNLOAD)
    FetchContent_Declare(
      googletest
      SOURCE_DIR /usr/src/googletest
    )
  else()
    message(STATUS "Google Test not found. Fetching...")
    FetchContent_Declare(
      googletest
      GIT_REPOSITORY https://github.com/google/googletest.git
      GIT_TAG        e2239ee6043f73722e7aa812a459f54a28552929 # release-1.11.0
    )
  endif()
  FetchContent_MakeAvailable(googletest)
  add_library(GTest::GTest ALIAS gtest)
  add_library(GTest::Main  ALIAS gtest_main)
else()
  find_package(GTest REQUIRED)
  if(TARGET GTest::gtest_main AND NOT TARGET GTest::Main)
    add_library(GTest::GTest ALIAS GTest::gtest)
    add_library(GTest::Main  ALIAS GTest::gtest_main)
  endif()
endif()

foreach(VER RANGE 1 10)
  set(Sources v${VER}.hip)
  set(TargetName Test-v${VER})

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
      GTest::GTest
      GTest::Main
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

  add_test(
    NAME ${TargetName}
    COMMAND ${TargetName}
  )
endforeach()
