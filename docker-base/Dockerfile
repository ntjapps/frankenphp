FROM dunglas/frankenphp:1-php8.5

# Install PHP Extensions
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
