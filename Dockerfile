FROM ubuntu:22.04

# Run updates and install packages
RUN apt-get update && apt-get install -y \
    build-essential vim intel-opencl-icd clinfo ruby-full git libclblast-dev wget curl bzip2 cmake file python3 gcc g++ gfortran libopenblas-dev liblapack-dev pkg-config python3-pip python3-dev python3-venv \
    && wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null \
    && echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list \
    && apt update && apt install -y intel-oneapi-mkl libjpeg-dev libpng-dev

WORKDIR /root/neo
COPY filelist-debs.txt .
RUN wget -i filelist-debs.txt \
    && dpkg -i *.deb

Build level-zero
RUN git clone https://github.com/oneapi-src/level-zero.git \
    && mkdir -p level-zero/build && cd level-zero/build \
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
COPY filelist-pip.txt .
RUN python3 -m pip install -r filelist-pip.txt
RUN python3 dev.py build

# set intel one API env vars
# Set environment variables
ENV CMAKE_PREFIX_PATH="/opt/intel/oneapi/compiler/latest/linux/IntelDPCPP:/opt/intel/oneapi/tbb/latest/env/.." \
    CMPLR_ROOT="/opt/intel/oneapi/compiler/latest" \
    CPATH="/opt/intel/oneapi/tbb/latest/env/../include:/opt/intel/oneapi/mkl/latest/include" \
    DIAGUTIL_PATH="/opt/intel/oneapi/compiler/latest/sys_check/sys_check.sh" \
    LD_LIBRARY_PATH="/opt/intel/oneapi/compiler/latest/linux/lib:/opt/intel/oneapi/compiler/latest/linux/lib/x64:/opt/intel/oneapi/compiler/latest/linux/compiler/lib/intel64_lin:/opt/intel/oneapi/tbb/latest/env/../lib/intel64/gcc4.8:/opt/intel/oneapi/mkl/latest/lib/intel64:/usr/local/lib" \
    LIBRARY_PATH="/opt/intel/oneapi/compiler/latest/linux/compiler/lib/intel64_lin:/opt/intel/oneapi/compiler/latest/linux/lib:/opt/intel/oneapi/tbb/latest/env/../lib/intel64/gcc4.8:/opt/intel/oneapi/mkl/latest/lib/intel64" \
    MANPATH="/opt/intel/oneapi/compiler/latest/documentation/en/man/common:" \
    MKLROOT="/opt/intel/oneapi/mkl/latest" \
    NLSPATH="/opt/intel/oneapi/compiler/latest/linux/compiler/lib/intel64_lin/locale/%l_%t/%N:/opt/intel/oneapi/mkl/latest/lib/intel64/locale/%l_%t/%N" \
    PATH="/opt/intel/oneapi/compiler/latest/linux/bin/intel64:/opt/intel/oneapi/compiler/latest/linux/bin:/opt/intel/oneapi/mkl/latest/bin/intel64:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    PKG_CONFIG_PATH="/opt/intel/oneapi/compiler/latest/lib/pkgconfig:/opt/intel/oneapi/tbb/latest/env/../lib/pkgconfig:/opt/intel/oneapi/mkl/latest/lib/pkgconfig" \
    TBBROOT="/opt/intel/oneapi/tbb/latest/env/.."

# Install Python packages
RUN python3 -m pip install torch==2.0.1a0 torchvision==0.15.2a0 intel_extension_for_pytorch==2.0.110+xpu -f https://developer.intel.com/ipex-whl-stable-xpu && \
    pip install jupyterlab install mkl

RUN mkdir -p /home/jupyter

# Set working directory
WORKDIR /home/jupyter

# Start JupyterLab
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--allow-root", "--NotebookApp.iopub_data_rate_limit=1.0e10"]