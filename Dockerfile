FROM php:7.2-apache

RUN apt-get -y update --fix-missing --no-install-recommends
RUN apt-get -y upgrade

# Install useful tools
RUN apt-get -yq install apt-utils nano wget dialog

# Install important libraries
RUN apt-get -y install --fix-missing -qq apt-utils build-essential git curl libcurl4 zip openssl

# Install xdebug
RUN pecl install xdebug-2.6.0
RUN docker-php-ext-enable xdebug

# 1. development packages
RUN apt-get install -y \
    git \
    zip \
    curl \
    sudo \
    nano\
    unzip \
    libicu-dev \
    libbz2-dev \
    libpng-dev \
    libjpeg-dev \
    libmcrypt-dev \
    libreadline-dev \
    libfreetype6-dev \
    software-properties-common\
    g++

RUN apt-get clean

# 2. apache configs + document root
ENV APACHE_DOCUMENT_ROOT=/var/www/html/public
RUN sed -ri -e 's!/var/www/html!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/sites-available/*.conf
RUN sed -ri -e 's!/var/www/!${APACHE_DOCUMENT_ROOT}!g' /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf

# 3. mod_rewrite for URL rewrite and mod_headers for .htaccess extra headers like Access-Control-Allow-Origin-
RUN a2enmod rewrite headers

# 4. start with base php config, then add extensions
RUN mv "$PHP_INI_DIR/php.ini-development" "$PHP_INI_DIR/php.ini"

#RUN git config --global url.”https://4038fc67cce42f31d82ced851db4fc45f261a804:@github.com/".insteadOf “https://github.com/"

# Clone our private GitHub Repository
#RUN git clone -b docker https://4038fc67cce42f31d82ced851db4fc45f261a804:x-oauth-basic@github.com/egahmad/OuijaModuleActivity.git ./
#RUN cp -R /myapp/* /home/app/
#RUN chown app:app -R /home/app/

RUN apt-get -y install libsqlite3-dev libsqlite3-0 default-mysql-client
RUN docker-php-ext-install pdo_mysql
RUN docker-php-ext-install pdo_sqlite
RUN docker-php-ext-install mysqli

RUN docker-php-ext-install tokenizer
RUN docker-php-ext-install json

RUN apt-get -y install zlib1g-dev
RUN docker-php-ext-install zip

RUN apt-get -y install libicu-dev
RUN docker-php-ext-install -j$(nproc) intl

RUN docker-php-ext-install mbstring
RUN docker-php-ext-install gettext

RUN apt-get install -y libfreetype6-dev libjpeg62-turbo-dev libpng-dev
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/
RUN docker-php-ext-install -j$(nproc) gd

RUN apt-get update && apt-get install -y libc-client-dev libkrb5-dev && rm -r /var/lib/apt/lists/*
RUN docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install imap

# Enable apache modules
RUN a2enmod rewrite headers

RUN docker-php-ext-install \
    bz2 \
    iconv \
    bcmath \
    opcache \
    calendar


# 5. composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# 6. Install Laravel Envoy
RUN composer global require "laravel/envoy"

# 7. we need a user with the same UID/GID with host user
# so when we execute CLI commands, all the host file's ownership remains intact
# otherwise command from inside container will create root-owned files and directories
ARG uid
RUN useradd -G www-data,root -u $uid -d /home/devuser devuser
RUN mkdir -p /home/devuser/.composer && \
    chown -R devuser:devuser /home/devuser

# 8. private keys
ARG SSH_KEY
ARG SSH_KEY_PASSPHRASE
RUN mkdir -p /root/.ssh && \
    chmod 0700 /root/.ssh && \
    ssh-keyscan github.com > /root/.ssh/known_hosts && \
    echo "${SSH_KEY}" > /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa

#RUN git config --global user.name "egahmad"
#RUN git config --global user.password "!Wolfandman1542"
#RUN git remote set-url origin git@github.com:egahmad/OuijaCRM.git
#RUN git clone https://github.com/egahmad/OuijaCRM.git

#

# 8. private keys
ARG SSH_KEY
ARG SSH_KEY_PASSPHRASE
RUN mkdir -p /root/.ssh && \
    chmod 0700 /root/.ssh && \
    ssh-keyscan github.com > /root/.ssh/known_hosts && \
    echo "${SSH_KEY}" > /root/.ssh/id_rsa && \
    chmod 600 /root/.ssh/id_rsa


WORKDIR /var/www/html/

COPY . "/var/www/html/"

RUN mv .env.prod .env

RUN composer update
RUN composer install
RUN php artisan key:generate

