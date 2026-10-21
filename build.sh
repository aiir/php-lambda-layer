#!/usr/bin/env sh

# stop on any failure, so we never package a layer from an old image or a partial build
set -eu

cd "$(dirname "$0")"

# the image Lambda's provided.al2023 runtime is based on, used to decide which libraries to bundle and
# to verify the finished layer
RUNTIME_IMAGE=public.ecr.aws/lambda/provided:al2023
PLATFORM=linux/arm64

# glibc must match the runtime's dynamic loader, so it is never bundled
GLIBC='^(ld-linux.*|libc|libm|libdl|libpthread|librt|libresolv|libutil)\.so'

BUILD_CONTAINER="aiir-php-build-$$"
RUNTIME_CONTAINER="aiir-php-runtime-$$"

# always remove the containers and working directory, whether the build succeeds or fails
cleanup() {
  docker rm -f "$BUILD_CONTAINER" "$RUNTIME_CONTAINER" >/dev/null 2>&1 || true
  rm -rf build
}
trap cleanup EXIT
trap 'exit 1' INT TERM

# tidy up any previous attempts
rm -f layer.zip
rm -rf build

# build from scratch for arm64 regardless of host architecture; --pull and --no-cache ensure the newest
# base image and packages are used rather than cached layers from an earlier build
docker buildx build --pull --no-cache --load --platform "$PLATFORM" -t aiir/php .
docker pull --platform "$PLATFORM" "$RUNTIME_IMAGE"

# create containers from the PHP image and the plain runtime image
docker run -d --name "$BUILD_CONTAINER" --platform "$PLATFORM" --entrypoint sleep aiir/php infinity >/dev/null
docker run -d --name "$RUNTIME_CONTAINER" --platform "$PLATFORM" --entrypoint sleep "$RUNTIME_IMAGE" infinity >/dev/null

# extract the required files from the container to the host file system
mkdir -p build/bin build/lib/php

docker cp "$BUILD_CONTAINER:/usr/bin/php" build/bin/
docker cp "$BUILD_CONTAINER:/usr/bin/php-cgi" build/bin/

EXTENSION_DIR=$(docker exec "$BUILD_CONTAINER" php -r "echo ini_get('extension_dir');")

docker cp -a "$BUILD_CONTAINER:$EXTENSION_DIR" build/lib/php/modules

# resolve the shared library dependencies of both binaries and all extensions, failing if any are missing
LDD=$(docker exec "$BUILD_CONTAINER" sh -c "ldd /usr/bin/php /usr/bin/php-cgi $EXTENSION_DIR/*.so")
if printf '%s\n' "$LDD" | grep -q 'not found'; then
  echo 'Missing shared libraries:' >&2
  printf '%s\n' "$LDD" | grep 'not found' | sort -u >&2
  exit 1
fi
LIBS=$(printf '%s\n' "$LDD" | sed -n 's/.*=> \(\/[^ ]*\).*/\1/p' | sort -u)

# fingerprint each library (following symlinks) in both images, as "<sha256> <path>"; a library
# absent from an image is fingerprinted as "missing"
FINGERPRINT='for lib in "$@"; do
  if [ -e "$lib" ]; then echo "$(sha256sum < "$lib" | cut -d" " -f1) $lib"; else echo "missing $lib"; fi
done'
# shellcheck disable=SC2086
BUILD_SUMS=$(docker exec "$BUILD_CONTAINER" sh -c "$FINGERPRINT" _ $LIBS)
# shellcheck disable=SC2086
RUNTIME_SUMS=$(docker exec "$RUNTIME_CONTAINER" sh -c "$FINGERPRINT" _ $LIBS)

# bundle only the libraries the runtime lacks or has a different copy of, copying both the symlink
# and the real file it points to
for lib in $LIBS; do
  name=$(basename "$lib")
  if printf '%s\n' "$name" | grep -qE "$GLIBC"; then
    continue
  fi
  build_sum=$(printf '%s\n' "$BUILD_SUMS" | awk -v l="$lib" '$2 == l { print $1 }')
  runtime_sum=$(printf '%s\n' "$RUNTIME_SUMS" | awk -v l="$lib" '$2 == l { print $1 }')
  if [ "$build_sum" = "$runtime_sum" ]; then
    continue
  fi
  echo "Bundling $name (runtime: $runtime_sum)"
  docker cp "$BUILD_CONTAINER:$lib" build/lib/
  real=$(docker exec "$BUILD_CONTAINER" readlink -f "$lib")
  if [ "$real" != "$lib" ]; then
    docker cp "$BUILD_CONTAINER:$real" build/lib/
  fi
done

# copy the bootstrap and config
cp src/bootstrap src/bootstrap.php src/php.ini build/
chmod +x build/bootstrap

# verify the layer in a clean runtime: no missing libraries, both binaries start, and every extension
# loads without warnings (extensions that others depend on are loaded first)
docker run --rm --platform "$PLATFORM" -v "$(pwd)/build:/opt:ro" --entrypoint sh "$RUNTIME_IMAGE" -c '
  set -e
  export LD_LIBRARY_PATH="/opt/lib:$LD_LIBRARY_PATH"
  if ldd /opt/bin/php /opt/bin/php-cgi /opt/lib/php/modules/*.so | grep "not found"; then
    echo "Layer has missing shared libraries" >&2
    exit 1
  fi
  /opt/bin/php -v
  /opt/bin/php-cgi -v >/dev/null
  EXTENSIONS=""
  for ext in mysqlnd pdo dom xml $(ls /opt/lib/php/modules | sed "s/\.so$//"); do
    case " $EXTENSIONS " in *" -d extension=$ext "*) ;; *) EXTENSIONS="$EXTENSIONS -d extension=$ext" ;; esac
  done
  OUTPUT=$(/opt/bin/php -n -d extension_dir=/opt/lib/php/modules $EXTENSIONS -d display_startup_errors=1 -m 2>&1)
  if printf "%s\n" "$OUTPUT" | grep -iE "warning|error|unable"; then
    echo "Layer extensions failed to load" >&2
    exit 1
  fi
  echo "Verified $(ls /opt/lib/php/modules | wc -l) extensions"
'

# create the layer zip file
(cd build && zip -qry ../layer.zip .)

echo "Built layer.zip"
