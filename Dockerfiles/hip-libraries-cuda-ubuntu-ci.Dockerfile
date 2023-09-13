# NVIDIA CUDA base docker image
FROM nvidia/cuda:11.7.1-devel-ubuntu20.04

# Arguments controlling image properties
ARG ROCM_VER=5.6.1
ARG CMAKE_MINIMUM=3.21.7
ARG CMAKE_LATEST=3.27.4
ARG CUDA_ARCHS=50;70;86
ARG CONTAINER_USER=developer
ARG RENDER_GID=109
ARG VCPKG_INSTALL_ROOT=/opt/Microsoft/Vcpkg

# Avoid locale-related warnings
ENV LANG en_US.utf8
ENV VCPKG_INSTALLATION_ROOT ${VCPKG_INSTALL_ROOT}

# Download repo sign keys from https:// sites
#   wget
#   ca-certificates
# Apply gpg keys
#   gpg
# Ability to run scripts with sudo (convenience)
#   sudo
# Fetch ROCm repos to build for NVIDIA, not AMD
#   git
# Avoid Perl warnings on inability to set locales
#   locales-all
RUN export DEBIAN_FRONTEND=noninteractive ; \
    apt update ; \
    apt upgrade -y ; \
    apt install --no-install-recommends -y \
    wget \
    ca-certificates \
    gpg \
    sudo \
    git \
    locales-all ; \
    rm -rf /var/lib/apt/lists/*

# Register repo.radeon.com APT signkey & and repo
RUN sudo mkdir --parents --mode=0755 /etc/apt/keyrings ; \
    wget https://repo.radeon.com/rocm/rocm.gpg.key -O - | \
    gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null ; \
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/${ROCM_VER} focal main" | \
    sudo tee /etc/apt/sources.list.d/rocm.list > /dev/null

# Install HIP with NVIDIA back-end
#
# The repo.radeon.com packages depend on the Canonical `cuda` package however that brings an entire graphical stack
# with itself, moreover we already have CUDA installed, being in the CUDA base image. Therefore we install base HIP
# packages and patch the `hip-runtime-nvidia` package to not depend on the `cuda` package. Previous solution used
# `dpkg --ignore-depends` which left APT in an inconsistent state. Instead we:
#  - We extract the .deb file
#  - Obtain the control file
#  - Run a regex removing `cuda` from the `Depends: ` field
#  - Build the .deb file again
#  - Install using apt
RUN export DEBIAN_FRONTEND=noninteractive ; \
    apt update ; \
    apt install -y ninja-build hip-dev hipify-clang openmp-extras ; \
    apt download hip-runtime-nvidia ; \
    dpkg-deb -x hip-runtime-nvidia_* deb-hip-runtime-nvidia ; \
    dpkg-deb --control hip-runtime-nvidia_* deb-hip-runtime-nvidia/DEBIAN ; \
    sed --in-place -E "s/^Depends: cuda \([<>= 0-9\.]*\),/Depends:/g" ./deb-hip-runtime-nvidia/DEBIAN/control ; \
    dpkg -b deb-hip-runtime-nvidia hip-runtime-nvidia-without-cuda.deb ; \
    apt install ./hip-runtime-nvidia-without-cuda.deb ; \
    rm hip-* deb-* ; \
    rm -rf /var/lib/apt/lists/*

# Register /opt/rocm/lib with the system linker
RUN echo "/opt/rocm/lib" >> /etc/ld.so.conf.d/rocm.conf ; \
    ldconfig

# Download CMake minimum and latest
RUN sudo mkdir -p /opt/Kitware/CMake ; \
    wget -c https://github.com/Kitware/CMake/releases/download/v${CMAKE_MINIMUM}/cmake-${CMAKE_MINIMUM}-linux-x86_64.tar.gz -O - | sudo tar -xz --directory /opt/Kitware/CMake ; \
    sudo mv /opt/Kitware/CMake/cmake-${CMAKE_MINIMUM}-linux-x86_64 /opt/Kitware/CMake/${CMAKE_MINIMUM} ; \
    wget -c https://github.com/Kitware/CMake/releases/download/v${CMAKE_LATEST}/cmake-${CMAKE_LATEST}-linux-x86_64.tar.gz -O - | sudo tar -xz --directory /opt/Kitware/CMake ; \
    sudo mv /opt/Kitware/CMake/cmake-${CMAKE_LATEST}-linux-x86_64 /opt/Kitware/CMake/${CMAKE_LATEST}

# Build hipLIBS, with NVIDIA as the back-end.
#
# hipconfig's compiler-based heuristics of detecting HIP_PLATFORM assumes too much.
# Using NVIDIA platform with amdclang++ instead of nvcc is totally supported. The presence
# of amdclang++ should not affect the selection process. Even as such
# https://github.com/ROCm-Developer-Tools/HIP/pull/2849 needs merging.
# We can't control platform selection locally using the CMake variable -D HIP_PLATFORM=nvidia
# because [we don't consult it in SetupNVCC.cmake](https://github.com/ROCmSoftwarePlatform/hipRAND/blob/bf0191437bd12ef769261652f280ce1983cc8c3b/cmake/SetupNVCC.cmake#L111-L116)
# like [FindHIP.cmake does](https://github.com/ROCm-Developer-Tools/HIP/blob/b8965f1f3d58d7adf7d702c09e75ebf3dd718f8c/cmake/FindHIP.cmake#L193-L202).
# We should probably use the solution of @Kevin from SO: https://stackoverflow.com/a/62935259/1476661
# For the time being, global manual override it is.

# Install hipRAND
RUN export HIP_PLATFORM=nvidia ; \
    export HIP_COMPILER=nvcc ; \
    wget https://github.com/ROCmSoftwarePlatform/hipRAND/archive/refs/tags/rocm-${ROCM_VER}.tar.gz ; \
    tar -xf rocm-* ; \
    rm rocm-* ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    -S ./hipRAND-rocm-${ROCM_VER} \
    -B ./hipRAND-rocm-${ROCM_VER}/build \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHS}" \
    -D CMAKE_MODULE_PATH=/opt/rocm/hip/cmake \
    -D BUILD_WITH_LIB=CUDA ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    --build ./hipRAND-rocm-${ROCM_VER}/build \
    -- -j`nproc` ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    --install ./hipRAND-rocm-${ROCM_VER}/build \
    --prefix /opt/rocm ; \
    rm -rf hipRAND-*

# Install hipCUB
RUN export HIP_PLATFORM=nvidia ; \
    export HIP_COMPILER=nvcc ; \
    wget https://github.com/ROCmSoftwarePlatform/hipCUB/archive/refs/tags/rocm-${ROCM_VER}.tar.gz ; \
    tar -xf rocm-* ; \
    rm rocm-* ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    -S ./hipCUB-rocm-${ROCM_VER} \
    -B ./hipCUB-rocm-${ROCM_VER}/build \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHS}" \
    -D CMAKE_MODULE_PATH=/opt/rocm/hip/cmake ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    --build ./hipCUB-rocm-${ROCM_VER}/build \
    -- -j`nproc` ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    --install ./hipCUB-rocm-${ROCM_VER}/build \
    --prefix /opt/rocm ; \
    rm -rf hipCUB-*

# Install hipBLAS
RUN export HIP_PLATFORM=nvidia ; \
    export HIP_COMPILER=nvcc ; \
    wget https://github.com/ROCmSoftwarePlatform/hipBLAS/archive/refs/tags/rocm-${ROCM_VER}.tar.gz ; \
    tar -xf rocm-* ; \
    rm rocm-* ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    -S ./hipBLAS-rocm-${ROCM_VER} \
    -B ./hipBLAS-rocm-${ROCM_VER}/build \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_Fortran_COMPILER=/opt/rocm/bin/amdflang \
    -D CMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHS}" \
    -D CMAKE_MODULE_PATH=/opt/rocm/hip/cmake \
    -D USE_CUDA=ON ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    --build ./hipBLAS-rocm-${ROCM_VER}/build \
    -- -j`nproc` ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    --install ./hipBLAS-rocm-${ROCM_VER}/build \
    --prefix /opt/rocm ; \
    rm -rf hipBLAS-*

# Install hipSOLVER
RUN export HIP_PLATFORM=nvidia ; \
    export HIP_COMPILER=nvcc ; \
    wget https://github.com/ROCmSoftwarePlatform/hipSOLVER/archive/refs/tags/rocm-${ROCM_VER}.tar.gz ; \
    tar -xf rocm-* ; \
    rm rocm-* ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    -S ./hipSOLVER-rocm-${ROCM_VER} \
    -B ./hipSOLVER-rocm-${ROCM_VER}/build \
    -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_Fortran_COMPILER=/opt/rocm/bin/amdflang \
    -D CMAKE_CUDA_ARCHITECTURES="${CUDA_ARCHS}" \
    -D CMAKE_MODULE_PATH=/opt/rocm/hip/cmake \
    -D USE_CUDA=ON ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    --build ./hipSOLVER-rocm-${ROCM_VER}/build \
    -- -j`nproc` ; \
    /opt/Kitware/CMake/${CMAKE_MINIMUM}/bin/cmake \
    --install ./hipSOLVER-rocm-${ROCM_VER}/build \
    --prefix /opt/rocm ; \
    rm -rf hipSOLVER-*

# Add the render group or change id if already exists
RUN if [ $(getent group render) ]; then \
    groupmod --gid ${RENDER_GID} render; \
    else \
    groupadd --system --gid ${RENDER_GID} render; \
    fi

# Add a user with sudo permissions for the container
RUN sudo useradd -Um -G sudo,video,render ${CONTAINER_USER} ; \
   echo ${CONTAINER_USER} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${CONTAINER_USER} ; \
   chmod 0440 /etc/sudoers.d/${CONTAINER_USER}

# Install ROCm-examples dependencies using APT
RUN export DEBIAN_FRONTEND=noninteractive ; \
    apt update ; \
    apt install -y \
    pkg-config \
    glslang-tools \
    libvulkan-dev \
    vulkan-validationlayers \
    libglfw3-dev ; \
    rm -rf /var/lib/apt/lists/*

# Install ROCm-examples (transitive) dependencies using Vcpkg
#
# Install Vcpkg dependencies
#   curl zip unzip tar
# Vcpkg port of glfw3 needs deps from system
#   libxinerama-dev
#   libxcursor-dev
#   xorg-dev
#   libglu1-mesa-dev
#   pkg-config
# Vcpkg port of Vulkan SDK only checks system install
#   libvulkan-dev
# Required tools for compiling shaders for graphics samples
#   glslang-tools
RUN export DEBIAN_FRONTEND=noninteractive ; \
    apt update ; \
    apt install -y \
    curl zip unzip tar \
    libxinerama-dev libxcursor-dev xorg-dev libglu1-mesa-dev pkg-config \
    libvulkan-dev \
    glslang-tools ; \
    git clone https://github.com/microsoft/vcpkg.git ${VCPKG_INSTALLATION_ROOT} ; \
    ${VCPKG_INSTALLATION_ROOT}/bootstrap-vcpkg.sh ; \
    sudo chown --recursive ${CONTAINER_USER}:${CONTAINER_USER} ${VCPKG_INSTALLATION_ROOT} ; \
    rm -rf /var/lib/apt/lists/*

# Create work directory
RUN sudo mkdir /workspaces ; \
    sudo chown ${CONTAINER_USER}:${CONTAINER_USER} /workspaces

WORKDIR /workspaces
VOLUME /workspaces
USER ${CONTAINER_USER}
