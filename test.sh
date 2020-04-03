#!/usr/bin/env sh

PHP_MINOR_VERSION=$1

unzip /opt/layer/php7${PHP_MINOR_VERSION}.zip -d /opt/ # prepare the layer
sed "s/PHP_MINOR_VERSION/${PHP_MINOR_VERSION}/g" /opt/layer/tests/php.ini >/etc/php.ini

# setup composer

mkdir /tmp/composer
cd /tmp/composer

yum install -y wget procps

EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
/opt/bin/php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(/opt/bin/php -r "echo hash_file('sha384', 'composer-setup.php');")"

if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
then
    >&2 echo "ERROR: Invalid installer signature"
    rm composer-setup.php
    exit 1
fi

/opt/bin/php composer-setup.php --quiet

# install dependencies

cd /opt
cp /opt/layer/composer.* .
/opt/bin/php /tmp/composer/composer.phar install

# copy tests

cd /var/task
cp -r /opt/layer/tests/* .

# run PHPUnit

/opt/bin/php -v
/opt/vendor/bin/phpunit .
