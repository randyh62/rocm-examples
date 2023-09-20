# Stream HPC HIP libraries CI base image
FROM streamhpc/hip-libraries-rocm-ubuntu-ci:5.6.1

# Contentious convenience allowing simple toolchain definition and usage.
# 
# Users typically want to use their toolchains conveniently in their shells. Providing full paths to to compilers such
# /opt/rocm/bin/amdclang++ vs. amdclang++ soon becomes tedious, so users typically add such tools to the PATH, as is
# the norm on Linux, and partly on Windows [1] too. The PATH however subtly alters the behavior of a few tools, most
# importantly CMake's find_package() config search [2]. We add it here as it's mostly considered a packaging defect
# that the (currently) most prevalent distribution channel leaves finishing setup to the user.
#
# [1]: Users of Windows whom have been burned by DLL-Hell (https://en.wikipedia.org/wiki/DLL_Hell) know that the
#      convenience of tools being on the path opens the gates to a specific circle of hell. Because the PATH affects
#      DLL loading (https://learn.microsoft.com/en-us/windows/win32/dlls/dynamic-link-library-search-order) adding a
#      folder to the PATH affects applications in subtle, often unintended ways. Developers are very soon burned for eg.
#      adding Doxygen's bin folder to the PATH, which also holds libclang.dll, at which point any application searching
#      for it may pick up an incompatible version of libclang.dll. (GPGPU devs will typically have multiple Clang forks
#      installed, so soon they'll find themselves in a similar situation with the executables as well, clang++.exe,
#      llvm-spirv.exe, multiple OpenCL ICD loaders, etc.) Instead of adding tools to the PATH, it's safer and not much
#      less convenient to setup aliases in the user's shell.
#
# [2]: https://cmake.org/cmake/help/latest/command/find_package.html#config-mode-search-procedure
ENV PATH=/opt/rocm/bin:${PATH}

# Install .NET runtime 6.0 for VS Code CMake Language Support extension
# https://marketplace.visualstudio.com/items?itemName=josetr.cmake-language-support-vscode
ARG MICROSOFT_PACKAGES_URL=https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb
RUN wget ${MICROSOFT_PACKAGES_URL} -O packages-microsoft-prod.deb ; \
    dpkg -i ./packages-microsoft-prod.deb ; \
    rm ./packages-microsoft-prod.deb ; \
    export DEBIAN_FRONTEND=noninteractive ; \
    apt update ; \
    apt install -y ; \
    dotnet-runtime-6.0
