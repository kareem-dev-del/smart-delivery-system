# SmartDrop Admin Dashboard

The admin dashboard is a React and TypeScript web client for managing the SmartDrop delivery network. It uses the Django REST API as its data source.

## Features

- JWT sign-in and protected admin routes
- Dashboard summary, orders, products, categories, locker stations, devices, users, notifications, and audit activity
- Courier availability and order assignment workflows
- English and Arabic interface localization
- Periodic refresh of operational data while the dashboard tab is visible

## Local development

```powershell
npm install
npm run dev
```

Vite serves the app at `http://localhost:5173` by default. The API defaults to `http://127.0.0.1:8000`. To override it, create `.env.local`:

```env
VITE_API_BASE_URL=http://127.0.0.1:8000
```

## Build

```powershell
npm run typecheck
npm run build
npm run preview
```

The production bundle is generated in `dist/`. For deployment, set `VITE_API_BASE_URL` to the public HTTPS address of the backend before building.

See the repository [README](../../README.md) for the complete project architecture and setup.
