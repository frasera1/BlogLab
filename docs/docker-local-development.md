# Docker and Local Development

## What this setup runs

- `db` — SQL Server 2022 Developer on `localhost:14333`
- `db-init` — one-shot schema initializer for `BlogDB`
- `api` — ASP.NET Core 3.1 API on `http://localhost:5000`
- `ui` — Angular 11 dev server on `http://localhost:4200`

The alternate Next.js UI in `bloglab-ui-next` is **not** currently part of
`docker-compose.yml`. Run it separately on the host at `http://localhost:3000`
when you want to compare the legacy Angular UI and the new alternate UI side by
side.

## Prerequisites

- Docker Desktop
- Node.js and npm for host-side `BlogLab-UI` or `bloglab-ui-next` runs
- .NET SDK tooling compatible with `BlogLab.Web` (`netcoreapp3.1`) if you want
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
- `CloudinaryOptions__CloudName`, `CloudinaryOptions__ApiKey`,
  `CloudinaryOptions__ApiSecret` — optional photo upload settings

### `bloglab-ui-next/.env.local`

Use `bloglab-ui-next/.env.local` for the alternate Next.js UI only.

- `NEXT_PUBLIC_BLOGLAB_API_BASE_URL` — backend API base URL, usually
  `http://localhost:5000/api`
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
4. Copy `bloglab-ui-next/.env.example` to `bloglab-ui-next/.env.local`.
5. Confirm `NEXT_PUBLIC_BLOGLAB_API_BASE_URL=http://localhost:5000/api` in the
   Next.js env file.

## Recommended ways to run all three apps together

### Option A — Docker for DB/API/Angular, host run for Next.js

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

### Option B — Docker for DB only, host run for API + Angular + Next.js

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

Normal registration creates non-admin users only, so local admin access must be
bootstrapped manually.

1. Register a user through either UI.
2. Connect to the local `BlogDB` as `sa` or with the app login from `.env`.
3. Promote the user:

   ```sql
   USE [BlogDB];

   UPDATE dbo.ApplicationUser
   SET IsAdmin = 1
   WHERE Username = 'your-username';
   ```

4. Sign out and sign back in so a fresh JWT/session is issued.

The admin feature is intentionally limited to the separate `/admin/blogs`
workspace and only supports viewing and deleting blogs across users.

## Optional Ollama setup

The Ollama integration is only needed for the Next.js AI draft flow.

- Browser code should call the Next.js proxy route at `POST /api/ai/ollama`,
  not Ollama directly.
- Enable it with `BLOGLAB_OLLAMA_ENABLED=true` in
  `bloglab-ui-next/.env.local`.
- The default local upstream is `http://localhost:11434` and the default model
  is `llama3.2`.
- Make sure your Ollama-compatible server is running and the configured model is
  available before using AI draft generation.
- When disabled, the proxy returns `503` instead of attempting an upstream
  request.

## Suggested rollout strategy for admin view + delete

1. Keep the Angular UI available during rollout and treat the Next.js app as an
   alternate UI on `http://localhost:3000`.
2. Bootstrap admin access only for a small number of known test accounts.
3. Keep admin work inside `/admin/blogs`, separate from the normal author
   workspace.
4. Keep the feature limited to review + delete only. Do not expand to cross-user
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

It does not currently start or verify the separate `bloglab-ui-next` dev server.

If the stack is already running and you only want to verify it:

`pwsh ./scripts/smoke-test-docker-dev.ps1 -SkipComposeUp`

## Stop

`docker compose down`

## Notes

- The DB container persists data in a named Docker volume.
- The `db-init` service only applies the schema when `BlogDB` does not already
  exist in that volume.
- The init script uses `sqlcmd -b`, so container startup fails fast if schema
  application hits an error.
- The API container restores NuGet packages and runs `dotnet run`.
- The Angular UI container installs packages into a Docker volume and runs
  `ng serve`.
- File watching uses polling for better compatibility with mounted volumes on
  Windows.
- The `.env` file is used for both Compose variable substitution and container
  environment overrides.