# SmartDrop Admin Dashboard

Phase 1 frontend for the Smart Delivery System admin dashboard.

This app currently includes:

- SmartDrop branding
- Login page
- JWT auth state
- Admin protected routes
- Access denied page
- Sidebar and topbar dashboard shell
- Placeholder navigation for future phases

## Local Setup

Install dependencies:

```powershell
npm install
```

Run the development server:

```powershell
npm run dev
```

Open:

```text
http://localhost:5173
```

Build for production:

```powershell
npm run build
```

Preview the production build:

```powershell
npm run preview
```

## Environment

Create `.env.local` if you need to override defaults:

```env
VITE_API_BASE_URL=http://127.0.0.1:8000
```

The default API origin is `http://127.0.0.1:8000`.

## Backend Assumptions

Login:

```http
POST /api/token/
```

Current user:

```http
GET /api/accounts/me/
```

Logout:

```http
POST /api/accounts/logout/
```

Phase 1 does not render fake operational metrics. Dashboard data, orders,
lockers, devices, notifications, and audit logs will be connected in later
phases.
