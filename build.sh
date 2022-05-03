#!/usr/bin/env sh

REQUIRED_LIB_FILES="/usr/lib64/libedit.so.0
/usr/lib64/libonig.so.2"

echo "Building layer for PHP 8 - using Amazon Linux Extras"

amazon-linux-extras enable php8.0
yum install -y php-cli php-dom php-mbstring php-mysqlnd

mkdir /tmp/layer
cd /tmp/layer
cp /opt/layer/php.ini .
cp /opt/layer/bootstrap .
chmod a+x bootstrap

mkdir bin
cp /usr/bin/php bin/
cp /usr/bin/php-cgi bin/

mkdir lib
for LIB in $REQUIRED_LIB_FILES; do
  cp $LIB lib/
done

mkdir -p lib/php/8.0
cp -a /usr/lib64/php/modules lib/php/8.0/

zip -r /opt/layer/php80.zip .
