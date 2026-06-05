# syntax=docker/dockerfile:1

# =============================================================================
# Stage 1: Recompile PHP from source with FD_SETSIZE=8192 and rebuild FrankenPHP
#
# Background: FrankenPHP embeds PHP in a single Go/Caddy process that shares one
# file-descriptor table with all HTTP connections. Under load, socket fd numbers
# exceed 1024, causing PHP's stream_select() to fail with:
#   "You MUST recompile PHP with a larger value of FD_SETSIZE."
# FD_SETSIZE is a compile-time constant baked into PHP's C source. The prebuilt
# dunglas/frankenphp image inherits FD_SETSIZE=1024 from the system headers of
# the official php:8.5-zts-bookworm base image. This stage recompiles PHP from
# source with -DFD_SETSIZE=8192 and rebuilds the frankenphp binary against it.
# =============================================================================
FROM dunglas/frankenphp:1-builder-php8.5 AS php-recompile

# PHP version must match the prebuilt binary in the base image exactly.
# Update this ARG when bumping the base image tag.
ARG PHP_VERSION=8.5.7
ARG PHP_SHA256="01ba2ed1c2658dacf91bebc8be6a4885f69b811c7993831fc48e26107ab29985"

# FD_SETSIZE value. 8192 is large enough for high-concurrency FrankenPHP worker
# deployments while staying well within kernel ulimit defaults.
ARG FD_SETSIZE=8192

# Override the PHP_CFLAGS/PHP_CPPFLAGS set by the php:8.5-zts-bookworm base.
# -DFD_SETSIZE must appear before sys/select.h is transitively included, which
# CFLAGS guarantees (the preprocessor sees it on the command line first).
ENV PHP_CFLAGS="-DFD_SETSIZE=${FD_SETSIZE} -fstack-protector-strong -fpic -fpie -O2 -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64"
ENV PHP_CPPFLAGS="${PHP_CFLAGS}"

# Install build dependencies. The builder image already has most of these;
# the install is a no-op for already-present packages.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        libargon2-dev \
        libcurl4-openssl-dev \
        libonig-dev \
        libreadline-dev \
        libsodium-dev \
        libsqlite3-dev \
        libssl-dev \
        libxml2-dev \
        zlib1g-dev \
        xz-utils \
        wget \
    ; \
    rm -rf /var/lib/apt/lists/*

# Download and verify PHP source tarball.
RUN set -eux; \
    mkdir -p /usr/src; \
    wget -q -O /usr/src/php.tar.xz \
        "https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz"; \
    echo "${PHP_SHA256}  /usr/src/php.tar.xz" | sha256sum -c -; \
    mkdir -p /usr/src/php; \
    tar -xJf /usr/src/php.tar.xz -C /usr/src/php --strip-components=1; \
    rm /usr/src/php.tar.xz

# Compile PHP with FD_SETSIZE override.
# configure flags mirror php:8.5-zts-bookworm exactly so the resulting
# libphp.so is ABI-compatible with the extension ecosystem.
RUN set -eux; \
    cd /usr/src/php; \
    gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)"; \
    debMultiarch="$(dpkg-architecture --query DEB_BUILD_MULTIARCH)"; \
    if [ ! -d /usr/include/curl ]; then \
        ln -sT "/usr/include/$debMultiarch/curl" /usr/local/include/curl; \
    fi; \
    export \
        CFLAGS="${PHP_CFLAGS}" \
        CPPFLAGS="${PHP_CPPFLAGS}" \
    ; \
    ./configure \
        --build="${gnuArch}" \
        --sysconfdir="/usr/local/etc" \
        --with-config-file-path="/usr/local/etc/php" \
        --with-config-file-scan-dir="/usr/local/etc/php/conf.d" \
        --enable-option-checking=fatal \
        --with-mhash \
        --with-pic \
        --enable-mbstring \
        --enable-mysqlnd \
        --with-password-argon2 \
        --with-sodium=shared \
        --with-pdo-sqlite=/usr \
        --with-sqlite3=/usr \
        --with-curl \
        --with-iconv \
        --with-openssl \
        --with-readline \
        --with-zlib \
        --enable-phpdbg \
        --enable-phpdbg-readline \
        --with-pear \
        --with-libdir="lib/$debMultiarch" \
        --enable-embed \
        --enable-zts \
        --disable-zend-signals \
    ; \
    make -j "$(nproc)"; \
    make install; \
    make clean

# =============================================================================
# Stage 2: Rebuild the FrankenPHP binary against the freshly compiled PHP.
#
# The dunglas/frankenphp:builder image ships Go source at /go/src/app.
# xcaddy is copied from the official caddy builder image.
# We link against the new libphp installed in stage 1 (/usr/local/lib/libphp.so).
# =============================================================================
FROM php-recompile AS frankenphp-build

# Re-declare ARG so it is visible inside this stage's RUN commands.
ARG FD_SETSIZE=8192

COPY --from=caddy:builder /usr/bin/xcaddy /usr/bin/xcaddy

RUN set -eux; \
    CGO_ENABLED=1 \
    XCADDY_SETCAP=1 \
    CGO_CFLAGS="-DFD_SETSIZE=${FD_SETSIZE} $(php-config --includes)" \
    CGO_LDFLAGS="$(php-config --ldflags) $(php-config --libs)" \
    xcaddy build \
        --output /usr/local/bin/frankenphp \
        --with github.com/dunglas/frankenphp=/go/src/app/ \
        --with github.com/dunglas/frankenphp/caddy=/go/src/app/caddy/ \
        --with github.com/dunglas/mercure/caddy \
        --with github.com/dunglas/vulcain/caddy; \
    setcap cap_net_bind_service=+ep /usr/local/bin/frankenphp; \
    frankenphp version

# =============================================================================
# Stage 3: Runtime image — standard dunglas/frankenphp with the patched binary
#           and libphp.so replaced. PHP extensions are installed as before.
# =============================================================================
FROM dunglas/frankenphp:1-php8.5

# Replace the prebuilt frankenphp binary and libphp.so with the
# FD_SETSIZE=8192 variants built in the stages above.
# libphp.so may be versioned (e.g. libphp8.5.so) or unversioned; copy both
# the shared object and any symlinks so ldconfig can resolve them.
COPY --from=frankenphp-build /usr/local/bin/frankenphp /usr/local/bin/frankenphp
COPY --from=frankenphp-build /usr/local/lib/libphp.so /usr/local/lib/libphp.so
RUN setcap cap_net_bind_service=+ep /usr/local/bin/frankenphp && \
    ldconfig && \
    frankenphp version

# Install PHP Extensions (unchanged from original)
RUN install-php-extensions \
    bcmath \
    core \
    ctype \
    curl \
    date \
    dom \
    exif \
    fileinfo \
    filter \
    gd \
    gmp \
    hash \
    iconv \
    intl \
    json \
    libxml \
    mbstring \
    mongodb \
    mysqli \
    mysqlnd \
    openssl \
    pcntl \
    pcre \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    pdo_sqlite \
    pgsql \
    phar \
    posix \
    random \
    redis \
    reflection \
    session \
    simplexml \
    sockets \
    sodium \
    sqlite3 \
    standard \
    tokenizer \
    xml \
    xmlreader \
    xmlwriter \
    opcache \
    zip \
    zlib \
    && \
# Test if PHP is working
    php -v && \
    php -m
