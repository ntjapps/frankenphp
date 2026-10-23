#!/usr/bin/env bash
# Runs the image's real security-headers.caddy + path-filter.caddy (bind-mounted over the ones in
# the image) against a tiny fixture docroot and checks the HTTP status of sensitive paths.
# Builds nothing: it only needs an already-pulled/built image with the frankenphp binary.
#
#   tests/test-paths.sh                       # image ghcr.io/ntjapps/frankenphp:latest
#   IMAGE=my/image:tag tests/test-paths.sh
#
# The container is capped (512 MB, 1 CPU), bound to 127.0.0.1 on a random high port and removed on exit.
set -u
IMAGE="${IMAGE:-ghcr.io/ntjapps/frankenphp:latest}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="$HERE/../docker-base"
WORK="$(mktemp -d)"
NAME="path-filter-test-$$"
PORT=$((20000 + RANDOM % 20000))
FAILS=0
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1; rm -rf "$WORK"; }
trap cleanup EXIT

PUB="$WORK/app/public"
mkdir -p "$PUB/.well-known" "$PUB/.git" "$PUB/vendor/horizon" "$PUB/build" "$PUB/real/dir" \
         "$WORK/app/storage/app/public/sub"
echo '<?php echo "index-ok:" . strlen(file_get_contents("php://input"));' > "$PUB/index.php"
echo '<?php echo "worker-ok";' > "$PUB/frankenphp-worker.php"
echo '<?php echo "PWNED";'     > "$PUB/foo.php"
echo '<?php echo "PWNED";'     > "$PUB/vendor/autoload.php"
echo '<?php echo "PWNED";'     > "$PUB/real/dir/deep.php"
echo '<?php echo "PWNED";'     > "$WORK/app/storage/app/public/x.php"
echo '<?php echo "PWNED";'     > "$WORK/app/storage/app/public/sub/y.php"
echo 'plain'                   > "$WORK/app/storage/app/public/photo.txt"
echo 'APP_KEY=secret'          > "$PUB/.env"
echo 'APP_KEY=secret'          > "$PUB/.env.production"
echo 'deny from all'           > "$PUB/.htaccess"
echo '[core]'                  > "$PUB/.git/config"
echo '{"ok":true}'             > "$PUB/.well-known/assetlinks.json"
echo '{}'                      > "$PUB/.well-known/apple-app-site-association"
echo 'secret'                  > "$PUB/.well-known/.hidden"
echo '{}'                      > "$PUB/composer.json"
echo 'dump'                    > "$PUB/db.sql"
echo 'console.log(1)'          > "$PUB/build/app.js"
echo 'console.log(2)'          > "$PUB/vendor/horizon/app.js"
echo 'x'                       > "$PUB/robots.txt"
ln -s /app/storage/app/public "$PUB/storage"
chmod -R a+rX "$WORK"

start() { # extra docker args...
  docker rm -f "$NAME" >/dev/null 2>&1
  docker run -d --rm --name "$NAME" --memory=512m --memory-swap=512m --cpus=1 \
    -p "127.0.0.1:$PORT:80" \
    -v "$WORK/app:/app:ro" \
    -v "$HERE/Caddyfile.test:/etc/caddy/Caddyfile.test:ro" \
    -v "$BASE/security-headers.caddy:/etc/frankenphp/security-headers.caddy:ro" \
    -v "$BASE/path-filter.caddy:/etc/frankenphp/path-filter.caddy:ro" \
    -e CADDY_SERVER_EXTRA_DIRECTIVES="import /etc/frankenphp/security-headers.caddy" \
    "$@" "$IMAGE" frankenphp run --config /etc/caddy/Caddyfile.test --adapter caddyfile >/dev/null || exit 2
  for _ in $(seq 1 40); do
    curl -s -o /dev/null "http://127.0.0.1:$PORT/robots.txt" && return 0
    sleep 0.5
  done
  echo "server did not start:"; docker logs "$NAME" 2>&1 | tail -20; exit 2
}

check() { # expected_status path [curl args...]
  local want="$1" path="$2"; shift 2
  local got
  got="$(curl -s -o /dev/null -w '%{http_code}' --path-as-is "$@" "http://127.0.0.1:$PORT$path")"
  if [ "$got" = "$want" ]; then printf 'PASS %s  %s\n' "$got" "$path"
  else printf 'FAIL want %s got %s  %s\n' "$want" "$got" "$path"; FAILS=$((FAILS + 1)); fi
}

echo "== image: $IMAGE (default config)"
start
check 200 /index.php
check 200 /
check 200 /some/laravel/route
check 200 /index.php/api/thing
check 404 /.env
check 404 /.env.production
check 404 /.htaccess
check 404 /.git/config
check 404 /nested/.env
check 404 //.env
check 404 /%2eenv
check 404 /.well-known/.hidden
check 404 /.well-known/../.env
check 404 /vendor/autoload.php
check 404 /storage/x.php
check 404 /storage/sub/y.php
check 404 /storage/x.php/extra
check 404 /STORAGE/X.PHP
check 404 /foo.php
check 404 /foo.php/bar
check 404 /FOO.PHP
check 404 /real/dir/deep.php
check 404 /frankenphp-worker.php
check 404 /cgi-bin/test.cgi
check 404 /composer.json
check 404 /db.sql
check 200 /.well-known/assetlinks.json
check 200 /.well-known/apple-app-site-association
check 200 /build/app.js
check 200 /vendor/horizon/app.js
check 200 /storage/photo.txt
check 200 /robots.txt
if curl -sI "http://127.0.0.1:$PORT/.env" | grep -qi '^x-content-type-options: nosniff'; then
  echo 'PASS 404 responses carry security headers'; else echo 'FAIL 404 without security headers'; FAILS=$((FAILS + 1)); fi
body="$(curl -s "http://127.0.0.1:$PORT/index.php")"
[ "$body" = "index-ok:0" ] && echo "PASS index.php body executed" || { echo "FAIL index.php body: $body"; FAILS=$((FAILS + 1)); }
check 200 /unknown-path-served-by-worker-fallback

echo "== request body cap (CADDY_MAX_REQUEST_BODY=1KB)"
start -e CADDY_MAX_REQUEST_BODY=1KB
head -c 100 /dev/zero > "$WORK/small"
head -c 5000 /dev/zero > "$WORK/big"
# PHP only gets the first max_size bytes of an oversized body (1KB = 1000 bytes in Caddy).
check_body() { # expected_body_of_index.php file
  local got
  got="$(curl -s --data-binary "@$WORK/$2" "http://127.0.0.1:$PORT/index.php")"
  if [ "$got" = "$1" ]; then printf 'PASS %s  (%s body)\n' "$got" "$2"
  else printf 'FAIL want %s got %s  (%s body)\n' "$1" "$got" "$2"; FAILS=$((FAILS + 1)); fi
}
check_body "index-ok:100" small
check_body "index-ok:1000" big

echo "== CADDY_PHP_ENTRYPOINT='.*' (legacy multi-file app)"
start -e 'CADDY_PHP_ENTRYPOINT=.*'
check 200 /foo.php
check 200 /real/dir/deep.php
check 404 /storage/x.php
check 404 /vendor/autoload.php
check 404 /.env

if [ "$FAILS" -ne 0 ]; then echo "$FAILS check(s) FAILED"; exit 1; fi
echo "all checks passed"
