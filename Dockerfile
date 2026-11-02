# must match the Lambda runtime the functions use (provided.al2023), and RUNTIME_IMAGE in build.sh
FROM public.ecr.aws/lambda/provided:al2023 AS php

# install the highest PHP stream (phpX.Y) available in the latest Amazon Linux repo release,
# rather than whichever version Amazon has chosen as the default for the unversioned "php" package
RUN PHP=$(dnf --releasever=latest repoquery 'php[0-9]*' 2>/dev/null \
      | grep -oE '^php[0-9]+\.[0-9]+' \
      | sort -uV \
      | tail -n 1) \
 && test -n "$PHP" \
 && echo "Installing $PHP" \
 && dnf install -y --releasever=latest "$PHP" "$PHP-mysqlnd" "$PHP-intl" \
 && dnf clean all

# compile the timezonedb extension in a separate stage, so the compiler and development packages never
# reach the image the layer is built from; Amazon Linux's tzdata lags behind tz releases, and PHP uses
# the extension's data whenever it is newer
FROM php AS timezonedb

# install the release PECL lists as latest from its tarball, as pecl's own release lookup can lag behind
RUN PHP=$(rpm -q --qf '%{NAME}' "$(rpm -qf /usr/bin/php)" | sed 's/-cli$//') \
 && dnf install -y --releasever=latest "$PHP-devel" php-pear gcc make \
 && VERSION=$(curl -fsS https://pecl.php.net/rest/r/timezonedb/latest.txt) \
 && echo "Installing timezonedb $VERSION" \
 && pecl install "https://pecl.php.net/get/timezonedb-$VERSION.tgz" \
 && cp "$(php -r "echo ini_get('extension_dir');")/timezonedb.so" /timezonedb.so

FROM php

COPY --from=timezonedb /timezonedb.so /tmp/timezonedb.so
RUN mv /tmp/timezonedb.so "$(php -r "echo ini_get('extension_dir');")/"
