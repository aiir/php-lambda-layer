#!/usr/bin/env sh

# extract the most recent build to disc
unzip ../layer.zip -d ./layer

# we have to fiddle with the bootstrap's shebang during local testing because of limitations in the
# Amazon provided test harness
BOOTSTRAP_TMP=$(mktemp)
{ echo '#!/bin/sh'; echo 'exec /opt/bin/php -c /opt/php.ini /opt/bootstrap "$@"'; } > "$BOOTSTRAP_TMP"
chmod +x "$BOOTSTRAP_TMP"

# run the Amazon docker container and mount our layer and test code at the relevant paths
docker run -p 9000:8080 \
  -v $(pwd)/layer:/opt \
  -v $(pwd)/src:/var/task \
  -v "$BOOTSTRAP_TMP":/var/runtime/bootstrap \
  public.ecr.aws/lambda/provided:al2023 \
  index.php

# once docker is terminated, clean up
rm "$BOOSTRAP_TMP"
rm -rf layer
