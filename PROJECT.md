# spry

A minimal monorepo. This document describes **structure and contracts only**: which folders exist, what lives in each, and the rules that bind the parts together. It contains no implementation code.

## 1. Scope of this slice

- Backend exposes **exactly two endpoints**: `GET /api/meetings` and `POST /api/meetings`.
- One entity, `Meeting`, with **exactly** these fields: `id`, `title`, `starts_at`, `ends_at`, `attendee_count`.
- Frontend has **exactly one page**: a list of meetings plus a form to add one.
- Infrastructure is **exactly three containers**: `postgres`, `backend`, `frontend`.

Anything not listed above is out of scope and must not be added to this slice.

## 2. Pinned versions

| Technology | Version | Where |
|---|---|---|
| PostgreSQL | 18-alpine | `postgres` service |
| Python | 3.13-slim | backend |
| FastAPI | 0.141.1 | backend |
| SQLAlchemy | 2.1.1 | backend (ORM) |
| Alembic | 1.20.0 | backend (migrations) |
| Node.js | 24 (LTS) | frontend |
| React | 19.3.0 | frontend |
| TypeScript | 7.0.2 | frontend |
| Vite | 8.3.1 | frontend |
| Tailwind CSS | 4.3.3 | frontend |
| shadcn/ui | via `shadcn` CLI 4.21.0 | frontend (components are copied into the repo, not installed as a package) |

Required supporting pieces, pinned in `backend/pyproject.toml` and `frontend/package.json` and not otherwise expanded: an ASGI server (Uvicorn) and a PostgreSQL driver (psycopg 3) for the backend; the icon set `lucide-react` and the Radix primitives the shadcn/ui components are built on for the frontend.

Versions were checked against the PyPI and npm registries on 2026-09-29. Python, Node and PostgreSQL majors are chosen as the current stable lines.

## 3. Repository layout

```
spry/
├── PROJECT.md
├── docker-compose.yml
├── backend/
│   ├── Dockerfile
│   ├── pyproject.toml
│   ├── alembic.ini
│   ├── alembic/
│   │   ├── env.py
│   │   ├── script.py.mako
│   │   └── versions/
│   └── app/
│       ├── main.py
│       ├── config.py
│       ├── database.py
│       ├── models/
│       ├── schemas/
│       └── api/
└── frontend/
    ├── Dockerfile
    ├── package.json
    ├── vite.config.ts
    ├── tsconfig.json
    ├── components.json
    ├── index.html
    └── src/
        ├── main.tsx
        ├── App.tsx
        ├── index.css
        ├── api/
        ├── types/
        ├── lib/
        └── components/
            └── ui/
```

### 3.1 Root

| Path | Purpose |
|---|---|
| `PROJECT.md` | This document. The source of truth for structure and contracts. |
| `docker-compose.yml` | Defines the three services and nothing else. See section 5. |
| `backend/` | The API service. |
| `frontend/` | The web UI service. |

### 3.2 `backend/`

| Path | Purpose |
|---|---|
| `Dockerfile` | Builds the backend image (Python 3.13). |
| `pyproject.toml` | Declares and pins backend dependencies. |
| `alembic.ini` | Alembic configuration. The database URL is not stored here; it is read from the environment. |
| `alembic/` | Everything Alembic owns. |
| `alembic/env.py` | Connects Alembic to the SQLAlchemy metadata and the `DATABASE_URL` environment variable. |
| `alembic/script.py.mako` | Alembic's template for new migration files. |
| `alembic/versions/` | Migration files. The schema is changed **only** through files here, never by `create_all`. Contains the single initial migration that creates the `meetings` table. |
| `app/` | The FastAPI application package. |
| `app/main.py` | Creates the FastAPI app and mounts the API router. Interactive docs and the OpenAPI routes are disabled so the two meeting endpoints are the only routes served. |
| `app/config.py` | Reads configuration from environment variables. The only setting is `DATABASE_URL`. |
| `app/database.py` | SQLAlchemy engine, session factory, and declarative base. |
| `app/models/` | SQLAlchemy ORM models. Contains only `Meeting`. |
| `app/schemas/` | Request and response schemas. Define the wire contract in section 4. |
| `app/api/` | HTTP route handlers. Contains only the meetings router. Handlers talk to the database through a SQLAlchemy session and return schema types, never ORM objects directly. |

### 3.3 `frontend/`

| Path | Purpose |
|---|---|
| `Dockerfile` | Builds the frontend image (Node 24) that runs the Vite dev server. |
| `package.json` | Declares and pins frontend dependencies and scripts. |
| `vite.config.ts` | Vite configuration, including the Tailwind plugin and the `/api` proxy to the `backend` service (section 5.3). |
| `tsconfig.json` | TypeScript configuration. Strict mode is on. |
| `components.json` | shadcn/ui configuration (aliases, Tailwind CSS entry, component destination). |
| `index.html` | Vite HTML entry point. |
| `src/main.tsx` | React entry point. Mounts `App`. |
| `src/App.tsx` | The single page: a header with a "New meeting" button and a vertical list of meetings. The create form opens in a dialog. No router. |
| `src/index.css` | Tailwind CSS entry and theme tokens. |
| `src/api/` | The only place that calls the backend. Exposes typed functions for list and create. Components never call `fetch` directly. |
| `src/types/` | TypeScript types mirroring the wire contract in section 4. |
| `src/lib/` | Small shared helpers required by shadcn/ui (class-name utility). |
| `src/components/` | Components specific to the page: `MeetingList`, `MeetingCard`, `NewMeetingDialog`, and `MeetingForm`. |
| `src/components/ui/` | shadcn/ui components copied in by the CLI. Only the components the page actually uses are added: button, card, input, label, dialog. Not hand-edited beyond styling. |

## 4. Contracts

### 4.1 Meeting entity

| Field | Type | Rules |
|---|---|---|
| `id` | integer | Assigned by the database. Never supplied by the client. |
| `title` | string | Required. Non-empty after trimming. Maximum 200 characters. |
| `starts_at` | datetime | Required. ISO 8601 with timezone offset. Stored as `timestamptz`. |
| `ends_at` | datetime | Required. ISO 8601 with timezone offset. Stored as `timestamptz`. Must be strictly after `starts_at`. |
| `attendee_count` | integer | Required. Zero or greater. |

No other fields exist: no timestamps for creation or update, no owner, no description, no location.

### 4.2 `GET /api/meetings`

- Request: no body, no query parameters.
- Response `200`: JSON array of Meeting objects (all five fields), ordered by `starts_at` ascending, then `id` ascending. An empty table returns `[]`.
- No pagination, filtering, or search.

### 4.3 `POST /api/meetings`

- Request body (JSON): `title`, `starts_at`, `ends_at`, `attendee_count`. Sending `id` or any unknown field is rejected.
- Response `201`: the created Meeting object (all five fields, including the new `id`).
- Response `422`: the request violated a rule in 4.1. The body uses FastAPI's standard validation error shape.

### 4.4 Boundaries between parts

- **Frontend to backend:** only through the two endpoints above, using the JSON shapes above. The frontend always calls relative paths beginning with `/api`.
- **Backend to database:** only through SQLAlchemy. Schema changes only through Alembic migrations.
- **Types:** `backend/app/schemas/` and `frontend/src/types/` describe the same shapes and must be changed together in the same commit.
- **Configuration:** only environment variables set in `docker-compose.yml`. There are no `.env` files and no secrets management.

## 5. Docker Compose

`docker-compose.yml` lives at the repository root and defines **only** `postgres`, `backend`, and `frontend`.

The only command a new developer runs is:

```
docker compose up
```

(Docker Desktop is the only prerequisite.) The backend and frontend source folders are bind-mounted into their containers so edits reload live (the frontend also mounts an anonymous volume at `/app/node_modules` so the bind mount does not hide the dependencies installed in the image). The database has no persistent volume: it is disposable, and its schema is rebuilt from migrations on every fresh start.

### 5.1 `postgres`

| Aspect | Value |
|---|---|
| Image | `postgres:18-alpine` |
| Listens on | `5432` (container). Published to host `5432`. |
| Depends on | Nothing. |
| Readiness | Healthcheck runs `pg_isready` against the configured user and database. Other services treat it as ready only when this check passes. |
| Configuration | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` set inline in compose with fixed local-development values. |

### 5.2 `backend`

| Aspect | Value |
|---|---|
| Build | `./backend` |
| Listens on | `8000` (container). Published to host `8000`. |
| Depends on | `postgres`, with condition `service_healthy`. |
| Readiness | Healthcheck requests `GET /api/meetings` from inside the container using the Python interpreter already in the image, and passes on a `200` response. No extra health endpoint exists. A `200` also proves the database connection and the migrated schema work. |
| Startup order | The container applies migrations (`alembic upgrade head`), then starts the ASGI server. The API never serves requests against an unmigrated database. |
| Configuration | `DATABASE_URL`, pointing at host `postgres` on port `5432`. |

### 5.3 `frontend`

| Aspect | Value |
|---|---|
| Build | `./frontend` |
| Listens on | `5173` (container). Published to host `5173`. This is the URL a developer opens in the browser. |
| Depends on | `backend`, with condition `service_healthy`. |
| Readiness | Healthcheck requests `GET /` from inside the container using the Node runtime already in the image, and passes on a `200` response. |
| API access | The Vite dev server proxies `/api` to `http://backend:8000`, so the browser only ever talks to `localhost:5173` and no CORS configuration exists. |

### 5.4 Startup chain

```
postgres (pg_isready passes)
   └─► backend (migrations run, GET /api/meetings returns 200)
          └─► frontend (Vite dev server serves /)
```

## 6. Explicitly out of scope

Nothing beyond this document exists in this slice. There are no other services, no additional endpoints (no update, delete, get-by-id, or health routes), no additional entities or fields, no additional pages or routes, no authentication, no caching, no background jobs, no reverse proxy, no cloud services, and no external integrations. Any of these requires updating this document first.
