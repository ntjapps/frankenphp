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

ARG ORACLE_VERSION=21.24.0.0.0
ARG ORACLE_SIMPLE_VERSION=2124000
ARG ORACLE_ZIP_DIR=instantclient_21_24
# Instant Client 21 has no Linux arm64 build; arm64 images get 19.x, the
# newest line Oracle ships for aarch64. /usr/oracle/instantclient points at
# whichever one was installed.
ARG ORACLE_ARM64_VERSION=19.32.0.0.0
ARG ORACLE_ARM64_SIMPLE_VERSION=1932000
ARG ORACLE_ARM64_ZIP_DIR=instantclient_19_32
# SHA-256 of the four zips above (computed from the files download.oracle.com served on 2026-11-12, i.e. trust on first download:
# compare with Oracle's download page when bumping). The build fails on a mismatch. Bump a version and its two hashes together, per arch.
ARG ORACLE_BASIC_SHA256=e384447b08e8242b80b3f225703312e66c8fd522e1450c93f774b9545744d87e
ARG ORACLE_SDK_SHA256=47224bbdc42c120528079a08e5463f3b9ab53d6dfa2626ab01fde309969ff44a
ARG ORACLE_ARM64_BASIC_SHA256=d5b413822c6cb1a9bb5cfe83ee2a138c39e9b7a931fb9887f5c82fc67ca859ad
ARG ORACLE_ARM64_SDK_SHA256=be3b37817943102cb051fad80f5dc821821cf1616ffd0983c2ded81621c760d3
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
        arm64) ic_arch=arm64; ic_ver=${ORACLE_ARM64_VERSION}; ic_simple=${ORACLE_ARM64_SIMPLE_VERSION}; ic_dir=${ORACLE_ARM64_ZIP_DIR}; ic_basic_sha=${ORACLE_ARM64_BASIC_SHA256}; ic_sdk_sha=${ORACLE_ARM64_SDK_SHA256} ;; \
        *) ic_arch=x64; ic_ver=${ORACLE_VERSION}; ic_simple=${ORACLE_SIMPLE_VERSION}; ic_dir=${ORACLE_ZIP_DIR}; ic_basic_sha=${ORACLE_BASIC_SHA256}; ic_sdk_sha=${ORACLE_SDK_SHA256} ;; \
    esac; \
    curl -fL https://download.oracle.com/otn_software/linux/instantclient/${ic_simple}/instantclient-basic-linux.${ic_arch}-${ic_ver}dbru.zip --output /usr/oracle/oic.zip; \
    curl -fL https://download.oracle.com/otn_software/linux/instantclient/${ic_simple}/instantclient-sdk-linux.${ic_arch}-${ic_ver}dbru.zip --output /usr/oracle/sdk.zip; \
    echo "${ic_basic_sha}  /usr/oracle/oic.zip" | sha256sum -c -; \
    echo "${ic_sdk_sha}  /usr/oracle/sdk.zip" | sha256sum -c -; \
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

# Target Image
# LDAP: only for applications that authenticate against a directory (ldap_* / LdapRecord).
# Kept out of :base so every other app stays without libldap.
FROM base AS ldap

# Install LDAP (install-php-extensions pulls the libldap runtime library)
RUN install-php-extensions \
    ldap \
    && \
    php -v && \
    php -m && \
    php -r 'exit(function_exists("ldap_connect") ? 0 : 1);'

# Target Image
# LDAP on top of the Oracle image, for applications that need both.
FROM oci AS ldap-oci

# Install LDAP (install-php-extensions pulls the libldap runtime library)
RUN install-php-extensions \
    ldap \
    && \
    php -v && \
    php -m && \
    php -r 'exit(function_exists("ldap_connect") && function_exists("oci_connect") ? 0 : 1);'
