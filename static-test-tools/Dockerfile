ARG DOCKER_REGISTRY="riot"
FROM ${DOCKER_REGISTRY}/riotdocker-base:latest

LABEL maintainer="alexandre.abadie@inria.fr"

ENV DEBIAN_FRONTEND noninteractive

ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8

# copy some included packages
RUN mkdir /pkgs
# ARG COCCINELLE_DEB="coccinelle_1.0.8~19.04npalix1_amd64.deb"
# COPY files/${COCCINELLE_DEB} /pkgs/${COCCINELLE_DEB}

RUN echo "deb-src http://archive.ubuntu.com/ubuntu/ impish main restricted universe multiverse" >> /etc/apt/sources.list

RUN \
    echo 'Update the package index files to latest available versions' >&2 && \
    apt-get update && \
    echo 'Installing static test tools' >&2 && \
    apt-get -y --no-install-recommends install \
        cppcheck \
        doxygen \
        graphviz \
        less \
        make \
        pcregrep \
        shellcheck \
        vera++ \
        wget \
        dpkg-dev
RUN apt-get build-dep -y coccinelle
RUN apt-get source --compile coccinelle
RUN ls -lha
RUN dpkg -i *
RUN \
    echo 'Cleaning up installation files' >&2 && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /pkgs

# Install required Python packages
COPY requirements.txt /tmp/requirements.txt
RUN echo 'Installing python3 packages' >&2 && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    rm -f /tmp/requirements.txt

# Install uncrustify
COPY --from=ghcr.io/kaspar030/uncrustify-builder:latest /usr/bin/uncrustify /usr/bin/uncrustify
