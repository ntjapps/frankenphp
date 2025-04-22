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

ARG ORACLE_VERSION=21.15.0.0.0
ARG ORACLE_SIMPLE_VERSION=2115000
ARG ORACLE_ZIP_DIR=instantclient_21_15
ARG OCI_VERSION=3.4.0

# Install Oracle Instant Client
RUN apk add --no-cache libaio libnsl libc6-compat wget unzip && mkdir -p /usr/oracle && \
    curl https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_SIMPLE_VERSION}/instantclient-basic-linux.x64-${ORACLE_VERSION}dbru.zip --output /usr/oracle/oic.zip && \
    curl https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_SIMPLE_VERSION}/instantclient-sdk-linux.x64-${ORACLE_VERSION}dbru.zip --output /usr/oracle/sdk.zip && \
    cd /usr/oracle && \
    unzip oic.zip && \
    unzip sdk.zip && \
    rm -f oic.zip && \
    rm -f sdk.zip

# Install OCI8
RUN LD_LIBRARY_PATH=/usr/oracle/${ORACLE_ZIP_DIR}:$LD_LIBRARY_PATH install-php-extensions \
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
