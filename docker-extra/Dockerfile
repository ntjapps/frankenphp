ARG BASEIMAGE=ghcr.io/ntjapps/frankenphp:base

# Base Image
FROM ${BASEIMAGE} AS base

# Target Image
FROM base AS pcov

# Install PCOV
RUN install-php-extensions \
    pcov \
    && \
    php -v && \
    php -m

# Target Image
FROM base AS xdebug

# Install XDEBUG
RUN install-php-extensions \
    xdebug \
    && \
    php -v && \
    php -m

# Target Image
FROM base AS oci

ARG ORACLE_VERSION=21.23.0.0.0
ARG ORACLE_SIMPLE_VERSION=2123000
ARG ORACLE_ZIP_DIR=instantclient_21_23
# Instant Client 21 has no Linux arm64 build; arm64 images get 19.x, the
# newest line Oracle ships for aarch64. /usr/oracle/instantclient points at
# whichever one was installed.
ARG ORACLE_ARM64_VERSION=19.32.0.0.0
ARG ORACLE_ARM64_SIMPLE_VERSION=1932000
ARG ORACLE_ARM64_ZIP_DIR=instantclient_19_32
ARG TARGETARCH
ARG OCI_VERSION=3.4.1

# Install Oracle Instant Client
RUN set -eux; \
    apt-get update; \
    if apt-cache show libaio1 >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends libaio1 libnsl2 wget unzip; \
    elif apt-cache show libaio >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends libaio libnsl2 wget unzip; \
    elif apt-cache show libaio-dev >/dev/null 2>&1; then \
        apt-get install -y --no-install-recommends libaio-dev libnsl2 wget unzip; \
    else \
        echo 'libaio package not found in apt repos'; exit 1; \
    fi; \
    rm -rf /var/lib/apt/lists/*; \
    mkdir -p /usr/oracle; \
    case "${TARGETARCH:-amd64}" in \
        arm64) ic_arch=arm64; ic_ver=${ORACLE_ARM64_VERSION}; ic_simple=${ORACLE_ARM64_SIMPLE_VERSION}; ic_dir=${ORACLE_ARM64_ZIP_DIR} ;; \
        *) ic_arch=x64; ic_ver=${ORACLE_VERSION}; ic_simple=${ORACLE_SIMPLE_VERSION}; ic_dir=${ORACLE_ZIP_DIR} ;; \
    esac; \
    curl -fL https://download.oracle.com/otn_software/linux/instantclient/${ic_simple}/instantclient-basic-linux.${ic_arch}-${ic_ver}dbru.zip --output /usr/oracle/oic.zip; \
    curl -fL https://download.oracle.com/otn_software/linux/instantclient/${ic_simple}/instantclient-sdk-linux.${ic_arch}-${ic_ver}dbru.zip --output /usr/oracle/sdk.zip; \
    cd /usr/oracle; \
    unzip -o oic.zip; \
    unzip -o sdk.zip; \
    ln -sfn /usr/oracle/${ic_dir} /usr/oracle/instantclient; \
    rm -f oic.zip sdk.zip

# Install OCI8
RUN LD_LIBRARY_PATH=/usr/oracle/instantclient:$LD_LIBRARY_PATH install-php-extensions \
    oci8 \
    pdo_oci \
    && \
    php -v && \
    php -m

# Target Image
FROM oci AS oci-pcov

# Install PCOV
RUN install-php-extensions \
    pcov \
    && \
    php -v && \
    php -m

# Target Image
FROM oci AS oci-xdebug

# Install XDEBUG
RUN install-php-extensions \
    xdebug \
    && \
    php -v && \
    php -m
