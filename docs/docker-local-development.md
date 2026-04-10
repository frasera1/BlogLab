# Docker and Local Development

## What this setup runs

- `db` — SQL Server 2022 Developer on `localhost:14333`
- `db-init` — one-shot schema initializer for `BlogDB`
- `api` — ASP.NET Core .NET 10 API on `http://localhost:5000`
- `ui` — Angular 11 dev server on `http://localhost:4200`
- `ui-next` — Next.js alternate UI on `http://localhost:3001`

The `ui-next` service runs the alternate UI from `bloglab-ui-next` with the
public browser API URL still pointing at `http://localhost:5000/api`, while
server-side requests inside the container use the internal Compose URL
`http://api:5000/api`.

## Prerequisites

- Docker Desktop
- Node.js and npm for host-side `BlogLab-UI` or `bloglab-ui-next` runs
- .NET SDK tooling compatible with `BlogLab.Web` (`net10.0`) if you want
  to run the API outside Docker
- A local repository-root `.env` file populated with development credentials

## Important database note

The Docker stack uses an internal SQL Server container instead of the host SQL
instance. The Compose-based API connection string points to `db,1433` on the
Compose network.

The external SQL Server is still useful as the source of truth when you want to
regenerate the schema script. The export script writes the schema in
dependency-safe order so it can be applied by the SQL Server container during
startup.

## Environment variable guide

### Repository root `.env`

Use the root `.env` file for Docker Compose and the API container.

- `BLOGDB_SA_PASSWORD` — SQL Server `sa` password for the local container
- `BLOGDB_APP_USER` / `BLOGDB_APP_PASSWORD` — application DB login created by
  `docker/db/init/02-create-app-login.sql`
- `Jwt__Key` — optional JWT signing key override for the API container
- `CLOUDINARY_URL` — preferred Cloudinary connection string for photo uploads
- `CloudinaryOptions__CloudName`, `CloudinaryOptions__ApiKey`,
  `CloudinaryOptions__ApiSecret` — optional fallback photo upload settings

### `bloglab-ui-next/.env.local`

Use `bloglab-ui-next/.env.local` for the alternate Next.js UI only.

- `NEXT_PUBLIC_BLOGLAB_API_BASE_URL` — backend API base URL, usually
  `http://localhost:5000/api`
- `BLOGLAB_SERVER_API_BASE_URL` — optional server-only API base URL for SSR and
  route handlers; use `http://localhost:5000/api` on the host and
  `http://api:5000/api` inside Docker Compose
- `BLOGLAB_AUTH_TOKEN_COOKIE_NAME` / `BLOGLAB_AUTH_SESSION_COOKIE_NAME` —
  cookie names used by the Next.js BFF auth flow
- `BLOGLAB_AUTH_COOKIE_MAX_AGE_SECONDS` — auth/session cookie lifetime
- `BLOGLAB_AUTH_COOKIE_SECURE` — set to `false` for plain HTTP localhost
- `BLOGLAB_OLLAMA_ENABLED`, `BLOGLAB_OLLAMA_HOST_URL`,
  `BLOGLAB_OLLAMA_MODEL`, `BLOGLAB_OLLAMA_TIMEOUT_MS`,
  `BLOGLAB_OLLAMA_API_KEY` — optional AI draft proxy settings

### Angular local configuration

The legacy Angular UI already targets `http://localhost:5000/api` in
`BlogLab-UI/src/environments/environment.ts`, so there is no separate `.env`
file for the Angular development server.

## Setup

1. Copy `.env.example` to `.env` if needed.
2. Set `BLOGDB_SA_PASSWORD`, `BLOGDB_APP_USER`, and `BLOGDB_APP_PASSWORD`.
3. Fill in Cloudinary values in `.env` if you need photo upload support.
  Prefer `CLOUDINARY_URL`; the split `CloudinaryOptions__*` keys are only a fallback.
4. Copy `bloglab-ui-next/.env.example` to `bloglab-ui-next/.env.local`.
5. Confirm `NEXT_PUBLIC_BLOGLAB_API_BASE_URL=http://localhost:5000/api` in the
   Next.js env file.
6. If you run `bloglab-ui-next` on the host, keep
   `BLOGLAB_SERVER_API_BASE_URL=http://localhost:5000/api`. The Compose service
   overrides it to `http://api:5000/api` automatically.
7. By default the Dockerized Next.js app publishes on `http://localhost:3001`.
  If you want a different host port, set `BLOGLAB_UI_NEXT_HOST_PORT` before
  `docker compose up`.

## Recommended ways to run the apps together

### Option A — Docker for DB/API/Angular/Next.js

This is the simplest way to run both frontends and the API together.

1. From the repository root, start the full Docker stack:

   `docker compose up --build`

2. Open:

- Angular UI: `http://localhost:4200`
- Next.js alternate UI: `http://localhost:3001`
- ASP.NET API: `http://localhost:5000`

If you want the Next.js UI on a different host port, run Compose with
`BLOGLAB_UI_NEXT_HOST_PORT=<port>` and use `http://localhost:<port>`.

### Option B — Docker for DB/API/Angular, host run for Next.js

This is the easiest way to compare the legacy and alternate UIs against the same
backend.

1. From the repository root, start the Docker stack:

   `docker compose up --build`

2. In a second terminal, start the alternate UI:

   - `cd bloglab-ui-next`
   - `npm install` (first run only)
   - `npm run dev`

3. Open:

   - Angular UI: `http://localhost:4200`
   - Next.js alternate UI: `http://localhost:3000`
   - ASP.NET API: `http://localhost:5000`

### Option C — Docker for DB only, host run for API + Angular + Next.js

Use this when you want the API and both frontends running directly on the host.

1. From the repository root, start only the database services:

   `docker compose up -d db db-init`

2. In PowerShell, configure the API to use the local containerized DB:

   - `$env:ASPNETCORE_ENVIRONMENT = "Development"`
   - `$env:Jwt__Issuer = "http://localhost:5000"`
   - `$env:ConnectionStrings__DefaultConnection = "Server=localhost,14333;Database=BlogDB;User Id=<BLOGDB_APP_USER>;Password=<BLOGDB_APP_PASSWORD>;Persist Security Info=False;Pooling=False;MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=True"`

3. Start the API from the repository root:

   `& 'C:\Program Files\dotnet\dotnet.exe' run --project .\BlogLab.Web --launch-profile "BlogLab.Web"`

4. Start the Angular UI in a second terminal:

   - `cd BlogLab-UI`
   - `npm install` (first run only)
   - `npm start`

5. Start the Next.js alternate UI in a third terminal:

   - `cd bloglab-ui-next`
   - `npm install` (first run only)
   - `npm run dev`

## Database assets

- `docker/db/init/00-create-db.sql` — creates `BlogDB`
- `docker/db/init/01-schema.sql` — generated schema from the external SQL
  Server
- `docker/db/init/02-create-app-login.sql` — creates the app login/user in the
  containerized DB and grants `db_owner`
- `docker/db/init/init-db.sh` — waits for SQL Server and initializes the DB on
  first run

## Admin bootstrap for local development

The Docker init flow now seeds a default admin account in `BlogDB`.

- Username: `adminlab`
- Password: `Admin12345!`

If you already had a persisted Docker volume before this seed was added, either
restart the stack so the reconcile/seed steps run again, or promote an existing
user manually:

```sql
USE [BlogDB];

UPDATE dbo.ApplicationUser
SET IsAdmin = 1
WHERE Username = 'your-username';
```

After changing admin state, sign out and sign back in so a fresh JWT/session is
issued.

The admin feature currently spans two dedicated workspaces:

- `/admin/blogs` for cross-user blog review and delete actions
- `/admin/users` for user review, admin role changes, and high-friction user deletion

Self-service profile management lives separately at `/me/profile` for the signed-in user only.

## Admin and profile verification checklist

After the API and Next.js app are running locally:

1. Sign in as `adminlab` / `Admin12345!` or another promoted admin account.
2. Open `http://localhost:3000/me/profile` for a host-run Next.js app, or `http://localhost:3001/me/profile` for the Dockerized Next.js app.
3. Verify that `fullname` and `email` can be updated from `/me/profile` and that username remains read-only in the MVP flow.
4. Open `/admin/users` and verify the paged user list loads only for admins.
5. Verify role changes from `/admin/users`, including the backend-enforced last-admin protection path.
6. Verify the user delete dialog requires typed username confirmation and refreshes the list after success.

## Focused automated coverage

- Backend deletion guardrails and orchestration: `dotnet test .\BlogLab.Services.Tests\BlogLab.Services.Tests.csproj --disable-build-servers --artifacts-path tests/artifacts/.artifacts-tests-prompt16`
- Next.js account/admin route and page coverage: `cd bloglab-ui-next` then `npm run test -- src/app/me/profile/page.test.ts src/app/admin/users/page.test.ts src/app/api/account/me/route.test.ts src/app/api/admin/users/route.test.ts src/app/api/admin/users/[applicationUserId]/role/route.test.ts src/app/api/admin/users/[applicationUserId]/route.test.ts src/lib/account/profile.test.ts src/lib/account/profile-client.test.ts src/lib/auth/session.test.ts src/lib/users/admin-role.test.ts src/lib/users/admin-delete.test.ts`

## MVP limitations for this slice

- `/me/profile` updates only `fullname` and `email`; username remains read-only.
- Password reset, email verification, audit logging, bulk moderation, and soft-delete/recovery are still deferred.
- Full runtime verification of remote photo cleanup during admin user deletion still depends on valid Cloudinary credentials. The local destructive smoke test can skip photo upload when those credentials are not available.

## Optional Ollama setup

The Ollama integration is only needed for the Next.js AI draft flow.

- Browser code should call the Next.js proxy route at `POST /api/ai/ollama`,
  not Ollama directly.
- Enable it with `BLOGLAB_OLLAMA_ENABLED=true` in
  `bloglab-ui-next/.env.local`.
- If `bloglab-ui-next` runs in Docker but Ollama runs on the host, set
  `BLOGLAB_OLLAMA_HOST_URL=http://host.docker.internal:11434`.
- The default local upstream is `http://localhost:11434` and the default model
  is `llama3.2`.
- Make sure your Ollama-compatible server is running and the configured model is
  available before using AI draft generation.
- When disabled, the proxy returns `503` instead of attempting an upstream
  request.

## Suggested rollout strategy for admin view + delete

1. Keep the Angular UI available during rollout and treat the Dockerized Next.js
  app as an alternate UI on `http://localhost:3001`.
2. Bootstrap admin access only for a small number of known test accounts.
3. Keep admin work inside `/admin/blogs` and `/admin/users`, separate from the normal author
  workspace and `/me/profile` self-service flow.
4. Keep the feature limited to review, role changes, and delete only. Do not expand to cross-user
  create or edit flows without a new scoped change.
5. If issues appear, remove admin access from the affected account and continue
   using the existing non-admin flows while investigating.

## Regenerate the schema script

From the repo root:

`pwsh ./scripts/export-blogdb-schema.ps1 -ServerInstance 'AFMAIN\AFMAINSQL22' -Database 'BlogDB' -Username 'bloguser' -Password '<password>'`

If you regenerate the schema after the DB volume already exists, reset the local
DB volume before restarting the stack so `db-init` can apply the new script:

`docker compose down -v`

## One-command smoke test

From the repository root:

`pwsh ./scripts/smoke-test-docker-dev.ps1`

This command:

- runs `docker compose up --build -d`
- waits for `db-init` to finish successfully
- checks `http://localhost:5000/api/blog`
- checks `http://localhost:4200`
- checks `http://localhost:3001` by default, or `http://localhost:$env:BLOGLAB_UI_NEXT_HOST_PORT` when that override is set

If the stack is already running and you only want to verify it:

`pwsh ./scripts/smoke-test-docker-dev.ps1 -SkipComposeUp`

## Backend-only host smoke test

From the repository root:

`pwsh ./scripts/smoke-test-backend-host.ps1`

This command:

- starts `db` and `db-init` if needed
- host-runs `BlogLab.Web` against the Docker SQL instance with the local `sa` connection string override used during the migration
- verifies host startup through `GET /api/blog = 200`
- verifies one authenticated route with register/login plus `POST /api/blog = 200`
- verifies the admin-only route with `GET /api/admin/blog = 403` as a normal user and `200` after promoting that same user to admin in the local SQL container

If the Docker DB services are already running, you can skip the Compose step:

`pwsh ./scripts/smoke-test-backend-host.ps1 -SkipComposeUp`

If you already started the API yourself and only want the HTTP checks:

`pwsh ./scripts/smoke-test-backend-host.ps1 -SkipComposeUp -SkipApiStart`

## Stop

`docker compose down`

## Notes

- The DB container persists data in a named Docker volume.
- The `db-init` service only applies the schema when `BlogDB` does not already
  exist in that volume.
- The init script uses `sqlcmd -b`, so container startup fails fast if schema
  application hits an error.
- The API container uses the .NET 10 SDK image, restores NuGet packages, and runs `dotnet run`.
- The Angular UI container installs packages into a Docker volume and runs
  `ng serve`.
- The Compose `api` service uses a container-local .NET artifacts path so it
  does not fight the host API over bind-mounted backend `bin`/`obj` outputs.
- The Next.js UI container installs packages into a Docker volume and runs
  `next dev` on port `3000`.
- File watching uses polling for better compatibility with mounted volumes on
  Windows.
- The `.env` file is used for both Compose variable substitution and container
  environment overrides.
