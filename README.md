# Local Infrastructure (Docker)

A local, containerized development environment that mirrors the production stack for the any project. It composes a Next.js frontend, a Laravel API, a headless WordPress CMS, an Nginx reverse proxy, and a MySQL 8 database into a single `docker compose` stack.

## Architecture Overview

```
                        ┌──────────────────────────────┐
                        │        Nginx Proxy           │
                        │  localhost:80                │
                        └───────┬───────────┬──────────┘
                                │           │
          ┌───────────┬─────────┼───┬─────────┼───────────┐
          ▼           ▼         ▼   ▼         ▼           ▼
   ┌────────┐ ┌──────────┐ ┌────────┐ ┌────────┐ ┌──────────┐
   │ Next.js│ │  Laravel │ │WordPress│ │  MySQL │ │ (Docker) │
   │ app.test│ │ api.app. │ │cms.app.│ │  db    │ │  net   │
   └────────┘ └──────────┘ └────────┘ └────────┘ └──────────┘
```

| Service | Container | Image / Build | Internal |
|---|---|---|---|
| Frontend UI | `local_nextjs` | `./frontend-ui/Dockerfile` (build) | `localhost:3000` |
| Backend API | `local_laravel` | `./backend-api/Dockerfile` (build) | `:9000` (PHP-FPM) |
| CMS (WordPress) | `local_wordpress` | `wordpress:6.5-php8.2-fpm-alpine` | `:9000` (PHP-FPM) |
| MySQL DB | `local_mysql` | `mysql:8.0` | `:3306` |
| Nginx Proxy | `local_nginx_proxy` | `nginx:alpine` | `:80` |

> **Note:** `frontend-ui`, `backend-api`, and `cms-content` are mount/build contexts referenced by the compose file but are **not** checked into this repository. The compose file expects them to exist as sibling directories (or you must create them / point `docker compose` at the correct paths).

## Quick Start

### Prerequisites

- Docker Engine 20.10+ with Compose V2 (`docker compose`)
- DNS hosts entries (or an `/etc/hosts` alias) for `app.test`, `api.app.test`, and `cms.app.test`

### 1. Prepare host aliases

```bash
# Append to /etc/hosts (requires sudo on Linux)
echo "127.0.0.1 app.test api.app.test cms.app.test" | sudo tee -a /etc/hosts
```

### 2. Bring the stack up

```bash
cd /home/demid/Project/lab/prime/docker
docker compose up -d --build
```

### 3. Verify

```bash
# List running containers
docker compose ps

# View logs (frontend, backend, or proxy)
docker compose logs -f frontend-ui
docker compose logs -f backend-api
docker compose logs -f local-proxy
```

Open your browser at:

- **Frontend:** http://app.test
- **API:** http://api.app.test
- **WordPress:** http://cms.app.test

## Configuration Reference

### Environment variables (compose)

#### `frontend-ui`

| Variable | Default | Purpose |
|---|---|---|
| `NEXT_PUBLIC_API_URL` | `http://api.app.test` | Base URL the frontend uses for API calls |
| `NEXT_PUBLIC_WP_URL` | `http://cms.app.test` | Base URL for the WordPress REST API |

#### `backend-api`

| Variable | Default | Purpose |
|---|---|---|
| `DB_CONNECTION` | `mysql` | DB driver |
| `DB_HOST` | `mysql-db` | Docker service name of MySQL |
| `DB_PORT` | `3306` | MySQL port |
| `DB_DATABASE` | `laravel_db` | Laravel schema |
| `DB_USERNAME` | `root` | DB user |
| `DB_PASSWORD` | `secretlocalpwd` | DB password |

#### `cms-content`

| Variable | Default | Purpose |
|---|---|---|
| `WORDPRESS_DB_HOST` | `mysql-db` | MySQL service name |
| `WORDPRESS_DB_NAME` | `wordpress_db` | WP schema |
| `WORDPRESS_DB_USER` | `root` | DB user |
| `WORDPRESS_DB_PASSWORD` | `secretlocalpwd` | DB password |

> **Security note:** The credentials above are **local development defaults only**. Rotate them in any non-local environment. See the security section.

### Nginx routing (`docker/nginx/default.conf`)

Three virtual hosts are defined on port 80:

| `server_name` | Target | Notes |
|---|---|---|
| `app.test` | `frontend-ui:3000` | Proxies all traffic (Websocket upgrade handled) |
| `api.app.test` | `backend-api:9000` | PHP-FPM; `root` points at `backend/public` |
| `cms.app.test` | `cms-content:9000` | PHP-FPM; `root` points at `cms` |

### MySQL initialization (`docker/mysql/init.sql`)

The file is mounted as `/docker-entrypoint-initdb.d/init.sql:ro`, so it runs automatically on first container startup (only when the `mysql-data` volume is empty).

What it does:

1. Creates `laravel_db` and `wordpress_db`.
2. Creates dedicated, least-privilege users:
   - `laravel_user` → scoped to `laravel_db`
   - `wordpress_user` → scoped to `wordpress_db`
3. Grants `root` full privileges (needed for direct GUI tools such as TablePlus/DBeaver).

### WordPress `php.ini` overrides (`docker/wordpress/php.ini`)

Mounted into the container as `/usr/local/etc/php/conf.d/custom.ini`:

| Directive | Value | Effect |
|---|---|---|
| `upload_max_filesize` | `128M` | Max upload size |
| `post_max_size` | `128M` | Max POST body size |
| `memory_limit` | `512M` | PHP memory limit |

## Volumes

| Volume | Purpose |
|---|---|
| `mysql-data` (named) | Persists MySQL data across restarts |
| `./frontend-ui:/app` | Live-syncs the Next.js app into the container |
| `./backend-api:/var/www/html` | Live-syncs the Laravel app into the container |
| `./cms-content:/var/www/html` | Live-syncs WordPress into the container |
| `./docker/nginx/default.conf` | Injects Nginx config |
| `./docker/mysql/init.sql` | Executes DB schema on first boot |
| `./docker/wordpress/php.ini` | Overrides PHP settings |

## Troubleshooting

### `frontend-ui`, `backend-api`, or `cms-content` not found

The compose file references these as local build/mount contexts. They do not exist in this local checkout. Either:

- Create the missing directories with their own `Dockerfile`/`package.json`/WordPress content, or
- Adjust `docker-compose.yml` to point `build.context` to the correct path.

### DNS resolution failures for `app.test` / `api.app.test` / `cms.app.test`

Ensure the host aliases are set (see Quick Start). If using Docker Desktop on Linux, you may also need:

```bash
sudo ln -sf /etc/hosts /etc/resolv.conf
```

### WordPress media uploads fail

Check `docker/wordpress/php.ini`; `upload_max_filesize` and `post_max_size` are set to `128M`.

### MySQL "access denied" from Laravel/WordPress

Ensure `mysql-db` has finished initializing. Check:

```bash
docker compose logs mysql-db
docker compose exec mysql-db mysql -uroot -psecretlocalpwd -e "SHOW DATABASES;"
```

## Stopping / Resetting

```bash
# Stop (keeps volumes and DB)
docker compose down

# Stop and remove volumes (deletes the MySQL database)
docker compose down -v

# Rebuild a specific service after code changes
docker compose up -d --build frontend-ui
```

## Operational Notes

- **No SSL/TLS** — HTTP only, intended for local development.
- **All containers share** `app-network` (bridge driver). Hostnames resolve only inside the Docker network.
- **MySQL root** is exposed on `localhost:3306` to allow direct GUI connections; the composed `init.sql` grants a dedicated user per service plus a root account with `WITH GRANT OPTION`.

## Proposed Roadmap

- Add `docker-compose.override.yml` for dev-only overrides (e.g., Xdebug).
- Add healthchecks to all services and `depends_on` condition `service_healthy`.
- Document how to scale the frontend/backend to multiple replicas.
- Add a Let's Encrypt / TLS option for local `*.test` domains.
- Add a `composer install` / `npm install` step inside the relevant images.

---

*This repository is a local, standalone infrastructure skeleton. It is not intended for production use without hardening (TLS, secrets management, least-privilege DB users, backups, monitoring).*

## Recommended Specialists

This local infrastructure is a full-stack web environment. Depending on the focus area, the following specialist roles will find this setup most relevant:

### 1. Backend / API Engineers
- **Focus:** Laravel (`backend-api`), MySQL, database migrations, API design.
- **Why:** The `backend-api` service exposes a PHP-FPM Laravel app; authentication, routing, and DB access are the core concerns.

### 2. Frontend / UI Engineers
- **Focus:** Next.js (`frontend-ui`), client-side routing, API mocking, responsive design.
- **Why:** `frontend-ui` runs as a Next.js container and is wired to `NEXT_PUBLIC_API_URL` and `NEXT_PUBLIC_WP_URL` for mocking production endpoints locally.

### 3. Web / CMS Developers
- **Focus:** WordPress, headless CMS REST/GraphQL, PHP configuration, media handling.
- **Why:** `cms-content` runs WordPress 6.5 as a headless FPM app behind the Nginx proxy, with `php.ini` tweaks for upload limits.

### 4. DevOps / Site Reliability Engineers (SRE)
- **Focus:** Container orchestration, networking, persistent volumes, CI/CD, deployment automation.
- **Why:** The `docker-compose.yml` is the primary artifact; a DevOps/SRE engineer owns healthchecks, `depends_on`, volume lifecycle, multi-container networking, and promotion to staging/prod.

### 5. Database Administrators (DBA)
- **Focus:** MySQL 8 configuration, schema design, user privilege scoping, backup/restore, performance tuning.
- **Why:** `mysql-db` with `mysql-data` volume, the `init.sql` bootstrap, and the least-privilege `laravel_user` / `wordpress_user` grants are all DBA-facing choices.

### 6. Infrastructure as Code / Platform Engineers
- **Focus:** Reproducible environments, Docker Compose patterns, `.env` handling, environment parity validation.
- **Why:** This setup models a "compose-as-infrastructure" pattern; a platform engineer uses it to enforce consistent local dev environments and to build higher-level tooling (healthchecks, overrides, linting).

### 7. Security Engineers / DevSecOps
- **Focus:** Secrets management, local credential hygiene, least-privilege access, container hardening, vulnerability scanning.
- **Why:** The compose file ships with hardcoded DB credentials and root MySQL access on `localhost:3306`; a security-focused specialist would own replacing those with a secrets manager (e.g., `docker secrets`, HashiCorp Vault, or a local `.env` template) and tightening exposure.

### 8. QA / Test Automation Engineers
- **Focus:** End-to-end testing, API testing, test data provisioning, local environment reproducibility.
- **Why:** The stack provides deterministic, reproducible endpoints (`app.test`, `api.app.test`, `cms.app.test`) and a seeded test database, making it well-suited for writing automated tests against a live environment.

### 9. Full-Stack / Generalist Engineers
- **Focus:** All of the above; rapid prototyping and local development.
- **Why:** Anyone building or iterating on the combined frontend + API + CMS + DB locally will use this stack as their daily working environment.

| `./docker/wordpress/php.ini` | Overrides PHP settings |
