# Stream HPC HIP libraries CI base image
FROM streamhpc/hip-libraries-cuda-ubuntu-ci:5.6.1

ENV PATH=/opt/rocm/bin:${PATH}
