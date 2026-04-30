#!/usr/bin/env sh

# tidy up any previous attempts
rm layer.zip
rm -rf build

# this line force Docker to build for arm64 regardless of host architecture
docker buildx build --platform linux/arm64 -t aiir/php .

# create a container from the docker image, which should contain a PHP installation
docker run -d --name dummy --platform linux/arm64 --entrypoint sleep aiir/php infinity

# extract the required files from the container to the host file system
mkdir -p build/bin build/lib/php

docker cp dummy:/usr/bin/php build/bin/
docker cp dummy:/usr/bin/php-cgi build/bin/
docker cp -a dummy:/usr/lib64/php8.5/modules build/lib/php/

# get all unique shared library dependencies for both binaries, resolve symlinks, and copy both symlink and real file
docker exec dummy sh -c '
  ldd /usr/bin/php /usr/bin/php-cgi \
    | grep -oP "(?<=> )/[^ ]+" \
    | sort -u \
    | while read -r lib; do
        echo "$lib"
        readlink -f "$lib"
      done \
    | sort -u
' | while read -r path; do
    docker cp "dummy:$path" build/lib/
done

# destroy the container
docker rm -f dummy

# copy the bootstrap and config
cp src/bootstrap build/
cp src/php.ini build/

# create the layer zip file
cd build
zip -ry ../layer.zip .
cd ..
rm -rf build
