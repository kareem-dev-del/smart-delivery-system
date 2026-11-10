# SmartDrop Delivery Platform

SmartDrop is a full-stack delivery and smart-locker project. Customers place orders and choose a locker station, administrators manage products, stations, couriers, and orders, and couriers handle their assigned deliveries from a Flutter app.

> **Project status:** local development is supported with Docker Compose. A public production deployment is not configured yet.

## Project highlights

- JWT authentication with customer, courier, and administrator roles.
- Django REST APIs for accounts, products, lockers, orders, notifications, and audit records.
- PostgreSQL persistence, schema migrations, and transactional order creation with stock and drawer locking.
- React and TypeScript admin dashboard with English and Arabic localization.
- Flutter customer and courier mobile experiences.
- Redis and Celery for background and scheduled work.
- Docker Compose for the local backend services.

## Architecture

```text
React admin dashboard ─┐
Flutter mobile app ─────┼── HTTPS/JSON ──> Django REST API ──> PostgreSQL
                       │                         │
                       │                         └── Redis ──> Celery worker / beat
                       └── API calls
```

The backend is the source of truth for identity, permissions, prices, inventory, order status, and locker assignment. Client apps send user choices; the API validates them and applies business rules before saving data.

## Technology

| Area | Stack |
|---|---|
| Backend | Python, Django, Django REST Framework, Simple JWT |
| Database | PostgreSQL |
| Background jobs | Celery, Redis |
| Admin frontend | React, TypeScript, Vite |
| Mobile apps | Flutter, Dart, BLoC |
| Local infrastructure | Docker, Docker Compose |
| Source control | Git, GitHub Pull Requests, GitHub Actions |

## Run locally

### Requirements

- Docker Desktop with Docker Compose
- Node.js and npm for the admin dashboard
- Flutter SDK and Android SDK for the mobile app

### Backend

From the repository root, create the local environment file and set a private development password and secret key:

```powershell
Copy-Item backend/.env.example backend/.env
```

Create the persistent database volume once, then start the backend services:

```powershell
docker volume create smart_delivery_postgres_data
docker compose -f backend/compose.yaml up -d --build
```

The API is available at `http://localhost:8000`. OpenAPI/Swagger documentation is available at `http://localhost:8000/api/docs/` when enabled in the local environment.

Useful commands:

```powershell
docker compose -f backend/compose.yaml ps
docker compose -f backend/compose.yaml logs -f web
docker compose -f backend/compose.yaml exec web python manage.py migrate
```

### Admin dashboard

```powershell
cd frontend/admin-dashboard
npm install
npm run dev
```

Open `http://localhost:5173`. To use a different API URL, create `frontend/admin-dashboard/.env.local`:

```env
VITE_API_BASE_URL=http://127.0.0.1:8000
```

### Flutter app

For an Android emulator, run:

```powershell
cd frontend/customer-app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

For a physical Android device connected by USB, set up ADB reverse and use the host loopback URL:

```powershell
adb reverse tcp:8000 tcp:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## API overview

The API uses JSON and bearer access tokens. Sign in at `POST /api/token/`, then send `Authorization: Bearer <access-token>` to protected endpoints.

| Resource | Example endpoints |
|---|---|
| Accounts | `/api/accounts/me/`, `/api/accounts/register/` |
| Products | `/api/products/`, `/api/products/categories/` |
| Customer orders | `GET /api/orders/`, `POST /api/orders/` |
| Order tracking | `/api/orders/{public_id}/tracking/` |
| Courier assignments | `/api/orders/courier/assignments/` |
| Admin orders | `/api/orders/admin/` |
| Locker stations | `/api/lockers/` and admin locker endpoints |

The complete interactive schema is available at `/api/docs/` in local development when `API_DOCUMENTATION_ENABLED=True`.

## Repository layout

```text
backend/                     Django project and Docker Compose services
frontend/admin-dashboard/    React + TypeScript operations dashboard
frontend/customer-app/       Flutter customer and courier app
docs/                        API contract and project documentation
```

## Git workflow

Work on a focused feature branch, review staged changes, commit, push, and open a Pull Request. GitHub Actions checks the change before it is merged into `main`.

```powershell
git switch -c feat/short-feature-name
git status
git diff
git add <files>
git diff --cached
git commit -m "feat: describe the change"
git push -u origin feat/short-feature-name
```

## Deployment status

This repository currently documents and supports local Docker-based development. It does not yet have a public live URL. Production deployment requires hosted PostgreSQL and Redis, service secrets, allowed-host and CORS configuration, static/media storage, and separately deployed frontend and backend services. Never upload `.env` files, API tokens, or production secrets to GitHub.

See [the portfolio deployment guide](docs/deployment-guide.md) for the required services, environment variables, deployment order, and current media-storage limitation.

## License

No license has been added yet. Contact the repository owner before reusing this project outside the training or portfolio context.
