#!/usr/bin/env sh

PHP_MINOR_VERSION=$1

echo echo "Building layer for PHP 7.$PHP_MINOR_VERSION - using Remi repository"

yum install -y httpd wget
git clone https://github.com/rpm-software-management/yum-utils.git
cd yum-utils/
make install
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
wget https://rpms.remirepo.net/enterprise/remi-release-6.rpm
rpm -Uvh remi-release-6.rpm
rpm -Uvh epel-release-latest-6.noarch.rpm

yum-config-manager --enable remi-php${PHP_MINOR_VERSION}

yum install -y --disablerepo="*" --enablerepo="remi,remi-php7${PHP_MINOR_VERSION}" php php-dom php-mbstring php-mysqlnd

mkdir /tmp/layer
cd /tmp/layer
sed "s/PHP_MINOR_VERSION/${PHP_MINOR_VERSION}/g" /opt/layer/php.ini >php.ini
sed "s/PHP_MINOR_VERSION/${PHP_MINOR_VERSION}/g" /opt/layer/bootstrap >bootstrap
chmod a+x bootstrap

mkdir bin
cp /usr/bin/php bin/
cp /usr/bin/php-cgi bin/

mkdir lib
for lib in libncurses.so.5 libtinfo.so.5 libpcre.so.0; do
  cp "/lib64/${lib}" lib/
done

cp /usr/lib64/libedit.so.0 lib/
cp /usr/lib64/libargon2.so.0 lib/

mkdir -p lib/php/7.${PHP_MINOR_VERSION}
cp -a /usr/lib64/php/modules lib/php/7.${PHP_MINOR_VERSION}/

zip -r /opt/layer/php7${PHP_MINOR_VERSION}.zip .
