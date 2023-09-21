# Ubuntu based docker image
FROM ubuntu:20.04

# Arguments controlling image properties
ARG ROCM_VER=5.6.1
ARG CMAKE_MINIMUM=3.21.7
ARG CMAKE_LATEST=3.27.4
ARG CONTAINER_USER=developer
ARG RENDER_GID=109
ARG VCPKG_INSTALL_ROOT=/opt/Microsoft/Vcpkg

# Avoid locale-related warnings
ENV LANG en_US.utf8
# Environment variable picked up by CMakePresets.json
# Compatible with virtual environments provided by GitHub Actions
# https://github.com/actions/runner-images#available-images
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

# Install HIP with AMD back-end
RUN export DEBIAN_FRONTEND=noninteractive ; \
    apt update ; \
    apt install -y ninja-build rocm-hip-sdk ; \
    rm -rf /var/lib/apt/lists/*

# Register /opt/rocm/lib with the system linker
RUN echo "/opt/rocm/lib" >> /etc/ld.so.conf.d/rocm.conf ; \
    ldconfig

# Download CMake minimum and latest
RUN sudo mkdir -p /opt/Kitware/CMake ; \
    wget -c https://github.com/Kitware/CMake/releases/download/v${CMAKE_MINIMUM}/cmake-${CMAKE_MINIMUM}-linux-x86_64.tar.gz -O - | sudo tar -xz --directory /opt/Kitware/CMake ; \
    sudo mv /opt/Kitware/CMake/cmake-${CMAKE_MINIMUM}-linux-x86_64 /opt/Kitware/CMake/${CMAKE_MINIMUM} ; \
    sudo ln -s /opt/Kitware/CMake/${CMAKE_MINIMUM} /opt/Kitware/CMake/minimum ; \
    wget -c https://github.com/Kitware/CMake/releases/download/v${CMAKE_LATEST}/cmake-${CMAKE_LATEST}-linux-x86_64.tar.gz -O - | sudo tar -xz --directory /opt/Kitware/CMake ; \
    sudo mv /opt/Kitware/CMake/cmake-${CMAKE_LATEST}-linux-x86_64 /opt/Kitware/CMake/${CMAKE_LATEST} ; \
    sudo ln -s /opt/Kitware/CMake/${CMAKE_MINIMUM} /opt/Kitware/CMake/latest

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
