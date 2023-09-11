FROM ubuntu:22.04

# Run updates and install packages
RUN apt-get update && apt-get install -y \
    build-essential intel-opencl-icd clinfo ruby-full git libclblast-dev wget curl bzip2 cmake file python3 gcc g++ gfortran libopenblas-dev liblapack-dev pkg-config python3-pip python3-dev python3-venv \
    && wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list \
    && apt update && apt install -y intel-oneapi-mkl libjpeg-dev libpng-dev

WORKDIR /root/neo

RUN wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.14062.11/intel-igc-core_1.0.14062.11_amd64.deb
RUN wget https://github.com/intel/intel-graphics-compiler/releases/download/igc-1.0.14062.11/intel-igc-opencl_1.0.14062.11_amd64.deb
RUN wget https://github.com/intel/compute-runtime/releases/download/23.22.26516.18/intel-level-zero-gpu-dbgsym_1.3.26516.18_amd64.ddeb
RUN wget https://github.com/intel/compute-runtime/releases/download/23.22.26516.18/intel-level-zero-gpu_1.3.26516.18_amd64.deb
RUN wget https://github.com/intel/compute-runtime/releases/download/23.22.26516.18/intel-opencl-icd-dbgsym_23.22.26516.18_amd64.ddeb
RUN wget https://github.com/intel/compute-runtime/releases/download/23.22.26516.18/intel-opencl-icd_23.22.26516.18_amd64.deb
RUN wget https://github.com/intel/compute-runtime/releases/download/23.22.26516.18/libigdgmm12_22.3.0_amd64.deb
RUN dpkg -i *.deb

# Build level-zero
RUN git clone https://github.com/oneapi-src/level-zero.git \
    && cd level-zero/build \
    && cmake .. \
    && cmake --build . --config Release --target package \
    && cmake --build . --config Release --target install

RUN apt update
RUN apt install intel-oneapi-mkl libjpeg-dev libpng-dev -y
RUN mkdir -p /usr/app
WORKDIR /usr/app
RUN git clone https://github.com/scipy/scipy.git
SHELL ["/bin/bash", "-c"]
WORKDIR /usr/app/scipy
RUN git submodule update --init
RUN python3 -m venv venv
RUN source venv/bin/activate
RUN python3 -m pip install numpy cython pythran pybind11 meson ninja pydevtool rich-click
RUN python3 -m pip install pytest pytest-xdist pytest-timeout pooch threadpoolctl asv gmpy2 mpmath hypothesis
RUN python3 -m pip install sphinx "pydata-sphinx-theme==0.9.0" sphinx-design matplotlib numpydoc jupytext myst-nb
RUN python3 -m pip install mypy typing_extensions types-psutil pycodestyle ruff cython-lint
RUN python3 dev.py build

# set intel one API env vars
# Set environment variables
ENV MKLROOT=/opt/intel/oneapi/mkl/latest DPCPPROOT=/opt/intel/oneapi/compiler/latest \
    CPATH="/opt/intel/oneapi/mkl/2023.2.0/include" \
    LD_LIBRARY_PATH="/opt/intel/oneapi/mkl/2023.2.0/lib/intel64" \
    NLSPATH="/opt/intel/oneapi/mkl/2023.2.0/lib/intel64/locale/%l_%t/%N" \
    LIBRARY_PATH="/opt/intel/oneapi/mkl/2023.2.0/lib/intel64" \
    PATH="/opt/intel/oneapi/mkl/2023.2.0/bin/intel64:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    PKG_CONFIG_PATH="/opt/intel/oneapi/mkl/2023.2.0/lib/pkgconfig"

# # Create a new user with sudo privileges
RUN useradd -ms /bin/bash jupyter

# # Install Python packages
RUN python3 -m pip install torch==2.0.1a0 torchvision==0.15.2a0 intel_extension_for_pytorch==2.0.110+xpu -f https://developer.intel.com/ipex-whl-stable-xpu && \
    pip install jupyterlab install mkl

# Change ownership of relevant directories (optional but recommended)
RUN chown -R jupyter:jupyter /home/jupyter

# Switch to non-root user
USER jupyter

# Set working directory
WORKDIR /home/jupyter

# Start JupyterLab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--NotebookApp.iopub_data_rate_limit=1.0e10"]