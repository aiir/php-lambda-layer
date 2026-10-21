#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")"

# always clean up the extracted layer, however docker exits
trap 'rm -rf layer' EXIT

# extract the most recent build to disc
rm -rf layer
unzip -q ../layer.zip -d ./layer

# run the Amazon docker container and mount our layer and test code at the relevant paths; the test
# harness only runs /var/runtime/bootstrap, so the layer's bootstrap is mounted there too
docker run --rm -p 9000:8080 \
  -v "$(pwd)/layer:/opt" \
  -v "$(pwd)/src:/var/task" \
  -v "$(pwd)/layer/bootstrap:/var/runtime/bootstrap" \
  public.ecr.aws/lambda/provided:al2023 \
  index.php
