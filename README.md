[![Build Run](https://github.com/ntjapps/frankenphp/actions/workflows/docker-build.yaml/badge.svg)](https://github.com/ntjapps/frankenphp/actions/workflows/image-build.yaml)

# What is this repository?

This is customized frankenphp repository for use in other application

## LICENSE

License can be read in [LICENSE](https://github.com/ntjapps/frankenphp/blob/latest/LICENSE)

## Path filtering and request limits (Laravel Octane)

The image sets `CADDY_SERVER_EXTRA_DIRECTIVES="import /etc/frankenphp/security-headers.caddy"`. Laravel Octane's Caddyfile
places that placeholder inside its `route { ... }` block, before `php_server`, so everything in the file is evaluated in
the order written and before any file is served or executed. `security-headers.caddy` imports
[`docker-base/path-filter.caddy`](docker-base/path-filter.caddy) after the headers, so blocked requests still get the
security headers. Apps must forward `CADDY_SERVER_EXTRA_DIRECTIVES` in `config/octane.php` (`caddy.env`), otherwise Octane
overwrites it and none of this applies.

Why: Octane uses `php_server { try_files {path} frankenphp-worker.php }`, so any existing `*.php` file under `public/`
(also through the `public/storage` symlink) is executed and dotfiles are served as static files.

Blocked with `404` (not 403, so a scanner cannot tell a blocked path from a missing one):

| Rule | Paths |
| --- | --- |
| Dotfiles and dot-directories | `/.env`, `/.git/...`, `/.htaccess`, `/a/.hidden`; also `//.env`, `/%2eenv`, `/.well-known/../.env` |
| PHP in data directories (always) | `*.php`, `.phtml`, `.phar`, `.phps`, `.inc`, `.php5` ... under `/storage/` and `/vendor/`; `/cgi-bin/` |
| Any other PHP | everything except the entry point regexp (default `/index.php`, with or without PATH_INFO), e.g. `/foo.php`, `/x.php/bar`, `/frankenphp-worker.php` |
| Files that never belong in a docroot | `composer.json/.lock`, `package.json`, `package-lock.json`, `installed.json`, `artisan`, `Dockerfile*`, `docker-compose*`, `*.sql *.bak *.old *.orig *.swp *.log *.sh *.ini` |

Not blocked: `/.well-known/` (ACME, `assetlinks.json`, `apple-app-site-association`, OAuth metadata; a dot segment inside it is
still blocked), `/build/` and published package assets such as `/vendor/horizon/app.js` (Horizon, Telescope, Livewire,
Filament), and non-PHP files under `/storage/`. `frankenphp-worker.php` is never requested by path: `php_server` reaches it
through its internal `try_files` rewrite, which happens after the filter.

Request body: `request_body { max_size 128MB }` (Caddy has no limit by default). 128MB covers the largest app upload
(seefin entity import: PHP `post_max_size` 105M). PHP only receives the first `max_size` bytes of a larger body.

Overrides (container env, read when Caddy loads the config; the env var must be unset or non-empty):

| Variable | Default | Effect |
| --- | --- | --- |
| `CADDY_PHP_ENTRYPOINT` | `^/+index\.php(/\|$)` | Regexp of the allowed PHP entry point(s). `.*` allows any PHP file outside `/storage/` and `/vendor/` (legacy multi-file PHP app). |
| `CADDY_MAX_REQUEST_BODY` | `128MB` | Max request body, a Caddy size (`256MB`, `1GB`). There is no "off": use a large value such as `100GB`. |

Test (no build; runs the image with the config files bind-mounted over a fixture docroot, capped container on a random port):

```sh
tests/test-paths.sh                  # IMAGE=ghcr.io/ntjapps/frankenphp:latest by default
IMAGE=my/image:tag tests/test-paths.sh
```

## Updates

28 Sep 2026
