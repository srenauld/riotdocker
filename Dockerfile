#
# RIOT Dockerfile
#
# The resulting image will contain everything needed to build RIOT for all
# supported platforms. This is the largest build image, it takes about 1.5 GB in
# total.
#
# Setup:
# 1. Install docker, add yourself to docker group, enable docker, relogin
#
# Use prebuilt image:
# 1. Prebuilt image can be pulled from Docker Hub registry with:
#      # docker pull riot/riotbuild
# 
# Use own build image:
# 1. Build own image based on latest base OS image:
#      # docker build --pull -t riotbuild .
#
# Usage:
# 1. cd to riot root
# 2. # docker run -i -t -u $UID -v $(pwd):/data/riotbuild riotbuild ./dist/tools/compile_test/compile_test.py

FROM ubuntu:bionic

LABEL maintainer="Kaspar Schleiser <kaspar@riot-os.org>"

ENV DEBIAN_FRONTEND noninteractive

ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

# The following package groups will be installed:
# - update the package index files to latest available version
# - native platform development and build system functionality (about 400 MB installed)
# - Cortex-M development (about 550 MB installed), through the gcc-arm-embedded PPA
# - MSP430 development (about 120 MB installed)
# - AVR development (about 110 MB installed)
# - LLVM/Clang build environment (about 125 MB installed)
# All apt files will be deleted afterwards to reduce the size of the container image.
# The OS must not be updated by apt. Docker image should be build against the latest
#  updated base OS image. This can be forced with `--pull` flag.
# This is all done in a single RUN command to reduce the number of layers and to
# allow the cleanup to actually save space.
# Total size without cleaning is approximately 1.525 GB (2016-03-08)
# After adding the cleanup commands the size is approximately 1.497 GB
RUN \
    dpkg --add-architecture i386 >&2 && \
    echo 'Update the package index files to latest available versions' >&2 && \
    apt-get update \
    && echo 'Installing native toolchain and build system functionality' >&2 && \
    apt-get -y --no-install-recommends install \
        afl++ \
        automake \
        bsdmainutils \
        build-essential \
        ca-certificates \
        ccache \
        cmake \
        coccinelle \
        curl \
        cppcheck \
        doxygen \
        gcc-multilib \
        gdb \
        g++-multilib \
        git \
        graphviz \
        less \
        libffi-dev \
        libpcre3 \
        libtool \
        m4 \
        parallel \
        pcregrep \
        protobuf-compiler \
        python \
        python3 \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        p7zip \
        rsync \
        ssh-client \
        subversion \
        unzip \
        vera++ \
        vim-common \
        wget \
        xsltproc \
    && echo 'Installing MSP430 toolchain' >&2 && \
    apt-get -y --no-install-recommends install \
        gcc-msp430 \
        msp430-libc \
    && echo 'Installing AVR toolchain' >&2 && \
    apt-get -y --no-install-recommends install \
        gcc-avr \
        binutils-avr \
        avr-libc \
    && echo 'Installing LLVM/Clang toolchain' >&2 && \
    apt-get -y --no-install-recommends install \
        llvm \
        clang \
        clang-tools \
    && echo 'Installing socketCAN' >&2 && \
    apt-get -y --no-install-recommends install \
        libsocketcan-dev:i386 \
        libsocketcan2:i386 \
    && echo 'Cleaning up installation files' >&2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Install ARM GNU embedded toolchain
# For updates, see https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads
ARG ARM_URLBASE=https://developer.arm.com/-/media/Files/downloads/gnu-rm
ARG ARM_URL=${ARM_URLBASE}/9-2019q4/gcc-arm-none-eabi-9-2019-q4-major-x86_64-linux.tar.bz2
ARG ARM_MD5=fe0029de4f4ec43cf7008944e34ff8cc
ARG ARM_FOLDER=gcc-arm-none-eabi-9-2019-q4-major
RUN echo 'Installing arm-none-eabi toolchain from arm.com' >&2 && \
    mkdir -p /opt && \
    curl -L -o /opt/gcc-arm-none-eabi.tar.bz2 ${ARM_URL} && \
    echo "${ARM_MD5} /opt/gcc-arm-none-eabi.tar.bz2" | md5sum -c && \
    tar -C /opt -jxf /opt/gcc-arm-none-eabi.tar.bz2 && \
    rm -f /opt/gcc-arm-none-eabi.tar.bz2 && \
    echo 'Removing documentation' >&2 && \
    rm -rf /opt/gcc-arm-none-eabi-*/share/doc
    # No need to dedup, the ARM toolchain is already using hard links for the duplicated files

ENV PATH ${PATH}:/opt/${ARM_FOLDER}/bin

# Install MIPS binary toolchain
# For updates: https://www.mips.com/develop/tools/codescape-mips-sdk/ (select "Codescape GNU Toolchain")
ARG MIPS_VERSION=2018.09-03
RUN echo 'Installing mips-mti-elf toolchain from mips.com' >&2 && \
    mkdir -p /opt && \
    curl -L "https://codescape.mips.com/components/toolchain/${MIPS_VERSION}/Codescape.GNU.Tools.Package.${MIPS_VERSION}.for.MIPS.MTI.Bare.Metal.CentOS-6.x86_64.tar.gz" -o - \
        | tar -C /opt -zx && \
    echo 'Removing documentation and translations' >&2 && \
    rm -rf /opt/mips-mti-elf/*/share/{doc,info,man,locale} && \
    echo 'Deduplicating binaries' && \
    cd /opt/mips-mti-elf/*/mips-mti-elf/bin && \
    for f in *; do test -f "../../bin/mips-mti-elf-$f" && ln -f "../../bin/mips-mti-elf-$f" "$f"; done && cd -

ENV MIPS_ELF_ROOT /opt/mips-mti-elf/${MIPS_VERSION}

ENV PATH ${PATH}:${MIPS_ELF_ROOT}/bin

# Install RISC-V binary toolchain
ARG RISCV_VERSION=8.2.0-2.2-20190521
ARG RISCV_BUILD=0004
RUN mkdir -p /opt && \
        wget -q https://github.com/gnu-mcu-eclipse/riscv-none-gcc/releases/download/v${RISCV_VERSION}/gnu-mcu-eclipse-riscv-none-gcc-${RISCV_VERSION}-${RISCV_BUILD}-centos64.tgz -O- \
        | tar -C /opt -xz && \
    echo 'Removing documentation' >&2 && \
      rm -rf /opt/gnu-mcu-eclipse/riscv-none-gcc/*/share/doc && \
    echo 'Deduplicating binaries' >&2 && \
    cd /opt/gnu-mcu-eclipse/riscv-none-gcc/*/riscv-none-embed/bin && \
      for f in *; do test -f "../../bin/riscv-none-embed-$f" && \
       ln -f "../../bin/riscv-none-embed-$f" "$f"; \
      done && \
    cd -

ENV PATH $PATH:/opt/gnu-mcu-eclipse/riscv-none-gcc/${RISCV_VERSION}-${RISCV_BUILD}/bin

# compile suid create_user binary
COPY create_user.c /tmp/create_user.c
RUN gcc -DHOMEDIR=\"/data/riotbuild\" -DUSERNAME=\"riotbuild\" /tmp/create_user.c -o /usr/local/bin/create_user \
    && chown root:root /usr/local/bin/create_user \
    && chmod u=rws,g=x,o=- /usr/local/bin/create_user \
    && rm /tmp/create_user.c

# Install complete ESP8266 toolchain in /opt/esp (139 MB after cleanup)
# remember https://github.com/RIOT-OS/RIOT/pull/10801 when updating
RUN echo 'Installing ESP8266 toolchain' >&2 && \
    mkdir -p /opt/esp && \
    cd /opt/esp && \
    git clone https://github.com/gschorcht/xtensa-esp8266-elf && \
    cd xtensa-esp8266-elf && \
    git checkout -q 696257c2b43e2a107d3108b2c1ca6d5df3fb1a6f && \
    rm -rf .git && \
    cd /opt/esp && \
    git clone https://github.com/gschorcht/RIOT-Xtensa-ESP8266-RTOS-SDK.git ESP8266_RTOS_SDK && \
    cd ESP8266_RTOS_SDK/ && \
    git checkout -q c0174eff7278eb5beea66ce1f65b7af57432d2a9 && \
    rm -rf .git* docs examples Kconfig make README.md tools && \
    cd components && \
    rm -rf app_update aws_iot bootloader cjson coap espos esptool_py esp-tls \
           freertos jsmn libsodium log mdns mqtt newlib partition_table \
           pthread smartconfig_ack spiffs ssl tcpip_adapter vfs && \
    find . -type f -name '*.[csS]' -exec rm {} \; && \
    find . -type f -name '*.cpp' -exec rm {} \;

ENV PATH $PATH:/opt/esp/xtensa-esp8266-elf/bin
ENV ESP8266_RTOS_SDK_DIR /opt/esp/ESP8266_RTOS_SDK

# Install ESP32 toolchain in /opt/esp (181 MB after cleanup)
# remember https://github.com/RIOT-OS/RIOT/pull/10801 when updating
RUN echo 'Installing ESP32 toolchain' >&2 && \
    mkdir -p /opt/esp && \
    cd /opt/esp && \
    git clone https://github.com/espressif/esp-idf.git && \
    cd esp-idf && \
    git checkout -q f198339ec09e90666150672884535802304d23ec && \
    git submodule update --init --recursive && \
    rm -rf .git* docs examples make tools && \
    rm -f add_path.sh CONTRIBUTING.rst Kconfig Kconfig.compiler && \
    cd components && \
    rm -rf app_trace app_update aws_iot bootloader bt coap console cxx \
           esp_adc_cal espcoredump esp_http_client esp-tls expat fatfs \
           freertos idf_test jsmn json libsodium log lwip mbedtls mdns \
           micro-ecc nghttp openssl partition_table pthread sdmmc spiffs \
           tcpip_adapter ulp vfs wear_levelling xtensa-debug-module && \
    find . -name '*.[csS]' -exec rm {} \; && \
    cd /opt/esp && \
    git clone https://github.com/gschorcht/xtensa-esp32-elf.git && \
    cd xtensa-esp32-elf && \
    git checkout -q 414d1f3a577702e927973bd906357ee00d7a6c6c

ENV PATH $PATH:/opt/esp/xtensa-esp32-elf/bin

# RIOT toolchains
ARG RIOT_TOOLCHAIN_GCC_VERSION=10.1.0
ARG RIOT_TOOLCHAIN_PACKAGE_VERSION=18
ARG RIOT_TOOLCHAIN_TAG=20200722112854-64162e7
ARG RIOT_TOOLCHAIN_GCCPKGVER=${RIOT_TOOLCHAIN_GCC_VERSION}-${RIOT_TOOLCHAIN_PACKAGE_VERSION}
ARG RIOT_TOOLCHAIN_SUBDIR=${RIOT_TOOLCHAIN_GCCPKGVER}-${RIOT_TOOLCHAIN_TAG}

ARG MSP430_URL=https://github.com/RIOT-OS/toolchains/releases/download/${RIOT_TOOLCHAIN_SUBDIR}/riot-msp430-elf-${RIOT_TOOLCHAIN_GCCPKGVER}.tgz
RUN echo 'Installing RIOT MSP430 ELF toolchain' >&2 && \
        wget -q ${MSP430_URL} -O- | tar -C /opt -xz
ENV PATH $PATH:/opt/riot-toolchain/msp430-elf/${RIOT_TOOLCHAIN_GCCPKGVER}/bin

# install required python packages from file
# numpy must be already installed before installing some other requirements (emlearn)
RUN pip3 install --no-cache-dir numpy==1.17.4
COPY requirements.txt /tmp/requirements.txt
RUN echo 'Installing python3 packages' >&2 \
    && pip3 install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# Create working directory for mounting the RIOT sources
RUN mkdir -m 777 -p /data/riotbuild

# Set a global system-wide git user and email address
RUN git config --system user.name "riot" && \
    git config --system user.email "riot@example.com"

# Copy our entry point script (signal wrapper)
COPY run.sh /run.sh
ENTRYPOINT ["/bin/bash", "/run.sh"]

# By default, run a shell when no command is specified on the docker command line
CMD ["/bin/bash"]

WORKDIR /data/riotbuild
