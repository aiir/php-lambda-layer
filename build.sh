#!/usr/bin/env sh

PHP_MINOR_VERSION=$1

if [ "$PHP_MINOR_VERSION" = "3" ]
then
  EL=6
  PACKAGES="wget
yum-utils
httpd"
  REQUIRED_LIB_FILES="/usr/lib64/libargon2.so.0
/usr/lib64/libedit.so.0
/usr/lib64/libonig.so.5
/lib64/libtinfo.so.5
/lib64/libncurses.so.5
/lib64/libpcre.so.0"
elif [ "$PHP_MINOR_VERSION" = "4" ]
then
  EL=7
  PACKAGES="wget
yum-utils
httpd
libxslt-devel
ncurses-compat-libs
libedit-devel
libzip010-compat"
  REQUIRED_LIB_FILES="/lib64/libcrypt.so.1
/lib64/libcurl.so.4
/lib64/libedit.so.0
/lib64/libidn2.so.0
/lib64/liblber-2.4.so.2
/lib64/libldap-2.4.so.2
/lib64/liblzma.so.5
/lib64/libncurses.so.5
/lib64/libnghttp2.so.14
/lib64/libnss3.so
/lib64/libonig.so.5
/lib64/libsasl2.so.3
/lib64/libsmime3.so
/lib64/libssh2.so.1
/lib64/libssl3.so
/lib64/libtinfo.so.5
/lib64/libunistring.so.0
/lib64/libxml2.so.2"
else
  echo "Unrecognised PHP version 7.${PHP_MINOR_VERSION}"
  exit 1
fi

echo "Building layer for PHP 7.${PHP_MINOR_VERSION} - using Remi repository"

yum install -y $PACKAGES
wget https://dl.fedoraproject.org/pub/epel/epel-release-latest-${EL}.noarch.rpm
wget https://rpms.remirepo.net/enterprise/remi-release-${EL}.rpm
rpm -Uvh epel-release-latest-${EL}.noarch.rpm
rpm -Uvh remi-release-${EL}.rpm

yum-config-manager --enable remi-php73
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
for LIB in $REQUIRED_LIB_FILES; do
  cp $LIB lib/
done

mkdir -p lib/php/7.${PHP_MINOR_VERSION}
cp -a /usr/lib64/php/modules lib/php/7.${PHP_MINOR_VERSION}/

zip -r /opt/layer/php7${PHP_MINOR_VERSION}.zip .
