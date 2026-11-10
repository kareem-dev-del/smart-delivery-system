# Portfolio Deployment Guide

This guide describes a first public demo deployment for SmartDrop. It is for a portfolio and training review, not a production launch.

## What must be online

| Component | Purpose | Configuration |
|---|---|---|
| Django API | Auth, products, orders, lockers, and admin APIs | Docker image from `backend/Dockerfile`, run migrations, then Gunicorn |
| PostgreSQL | Persistent application data | Managed PostgreSQL; use the provider's private connection values |
| Redis | Cache and Celery broker | Managed Redis; set both `REDIS_URL` and `CELERY_BROKER_URL` |
| Celery worker | Processes queued notification email tasks | Same backend image; command `celery -A config worker --loglevel=INFO --concurrency=1` |
| Celery Beat | Expires overdue orders | Same backend image; command `celery -A config beat --loglevel=INFO --schedule=/tmp/celerybeat-schedule --pidfile=/tmp/celerybeat.pid` |
| Admin dashboard | Browser UI for operations | Static Vite build from `frontend/admin-dashboard`, with `VITE_API_BASE_URL` set before building |

Deploy the customer and courier Flutter app separately as an Android build. For the first hosted demo, provide the public API URL with `API_BASE_URL` when building it.

## Backend environment variables

Set these in the hosting provider's secret/environment settings. Do not commit real values to GitHub.

```env
DEBUG=False
SECRET_KEY=<generate-a-long-random-secret>
DATABASE_ENGINE=postgres
POSTGRES_DB=<managed-postgres-database>
POSTGRES_USER=<managed-postgres-user>
POSTGRES_PASSWORD=<managed-postgres-password>
POSTGRES_HOST=<managed-postgres-private-host>
POSTGRES_PORT=5432
ALLOWED_HOSTS=<backend-public-hostname>
CORS_ALLOWED_ORIGINS=https://<dashboard-public-hostname>
CSRF_TRUSTED_ORIGINS=https://<dashboard-public-hostname>
REDIS_URL=<managed-redis-url>
CELERY_BROKER_URL=<managed-redis-url>
API_DOCUMENTATION_ENABLED=False
SECURE_SSL_REDIRECT=False
```

The host should terminate HTTPS and forward `X-Forwarded-Proto`; Django already trusts that proxy header and uses secure session/CSRF cookies when `DEBUG=False`. Keep `SECURE_SSL_REDIRECT=False` unless the chosen provider's proxy behavior has been confirmed, to avoid redirect loops.

Use `/health/` for process health and `/ready/` for database readiness. The API container listens on the provider's `PORT` value and runs Gunicorn using the existing Dockerfile.

For the Railway Postgres service, map its generated variables into the names this Django project reads:

```text
POSTGRES_DB       = ${{Postgres.PGDATABASE}}
POSTGRES_USER     = ${{Postgres.PGUSER}}
POSTGRES_PASSWORD = ${{Postgres.PGPASSWORD}}
POSTGRES_HOST     = ${{Postgres.PGHOST}}
POSTGRES_PORT     = ${{Postgres.PGPORT}}
REDIS_URL         = ${{Redis.REDIS_URL}}
CELERY_BROKER_URL = ${{Redis.REDIS_URL}}
```

Replace `Postgres` and `Redis` in the references if the database services use different names. Railway's PostgreSQL service provides the `PG*` variables, while this repository currently expects the `POSTGRES_*` names.

## Deploy order

1. Create the managed PostgreSQL and Redis services.
2. Deploy the backend web service from the repository's `backend` directory and `Dockerfile`. Set the environment variables above. Start command:

   ```sh
   python manage.py migrate && gunicorn config.wsgi:application --bind 0.0.0.0:${PORT:-8000} --workers 2 --access-logfile - --error-logfile -
   ```

3. Deploy two additional backend services using the same image for Celery worker and Beat, with their commands from the table above. Set the same database and Redis environment values on both.
4. Build the static dashboard from `frontend/admin-dashboard` using `npm ci && npm run build`, publish `dist`, and set `VITE_API_BASE_URL` to the backend's HTTPS origin. Configure the static host to rewrite unknown paths to `/index.html` for React Router routes.
5. Add the final dashboard origin to backend `CORS_ALLOWED_ORIGINS` and `CSRF_TRUSTED_ORIGINS`, then redeploy the API.
6. Check `/health/`, `/ready/`, dashboard login, customer registration/login, products, and an order workflow. Create a non-default demo admin account through the API or Django management command; do not publish credentials in this repository.

The repository includes a Render Blueprint at `render.yaml` for the static dashboard. When creating the Blueprint, provide `VITE_API_BASE_URL` as the API's public HTTPS origin. Render rewrites client-side routes to `index.html`.

On Railway, configure the API service's root directory as `/backend`, Dockerfile as `Dockerfile`, and health check path as `/ready/`. Its start command runs migrations before Gunicorn as shown above. Create the worker and Beat as separate services from that same root and Dockerfile, replacing their Docker start commands with the commands in the service table. Add a public domain to the API service, then set `ALLOWED_HOSTS` to its hostname (without `https://`).

## Email and product images

The in-app notification records are stored in PostgreSQL. Actual outgoing email requires valid SMTP values (`EMAIL_BACKEND`, `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `EMAIL_USE_TLS`, and `DEFAULT_FROM_EMAIL`) in the web and worker services. Without those values, Django uses its console email backend and the worker does not deliver messages to inboxes.

Product image uploads are accepted, but production media storage is not configured yet. `MEDIA_ROOT` currently points to the container filesystem, and Django only serves uploaded media when `DEBUG=True`. Do not enable `DEBUG` on the public service to make images appear. Before demonstrating uploaded images, add an object-storage backend (or another deliberate media-serving setup) and test upload/retrieval there. Until then, the API/dashboard can be demoed without relying on uploaded product pictures.

## Cost and demo limits

Hosting prices and free-tier rules change. Check the provider's current billing page before creating services. A free static dashboard can be paired with a trial backend, but that does not make the complete system a permanent free deployment. Free database/Redis services may sleep, lose state, or expire; the worker and scheduler also need always-on service processes for reliable background jobs and order expiration.

Never put `.env`, passwords, access tokens, private database URLs, or production keys in GitHub. Use provider-managed environment variables and rotate any secret that was accidentally exposed.
