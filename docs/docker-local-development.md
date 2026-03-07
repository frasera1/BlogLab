# Docker Local Development

## What this setup runs

- `db` — SQL Server 2022 Developer on `localhost:14333`
- `db-init` — one-shot schema initializer for `BlogDB`
- `api` — ASP.NET Core 3.1 API on `http://localhost:5000`
- `ui` — Angular 11 dev server on `http://localhost:4200`

## Prerequisites

- Docker Desktop
- A local `.env` file populated with development credentials

## Important database note

The Docker stack now uses an internal SQL Server container instead of the host SQL instance.
The API connection string is composed in `docker-compose.yml` and points to `db,1433` on the Compose network.

The external SQL Server is still useful as the source of truth when you want to regenerate the schema script.
The export script writes the schema in dependency-safe order so it can be applied by the SQL Server container during startup.

## Setup

1. If needed, copy `.env.example` to `.env`
2. Set `BLOGDB_SA_PASSWORD`, `BLOGDB_APP_USER`, and `BLOGDB_APP_PASSWORD`
3. Fill in Cloudinary values if you need photo upload support

## Database assets

- `docker/db/init/00-create-db.sql` — creates `BlogDB`
- `docker/db/init/01-schema.sql` — generated schema from the external SQL Server
- `docker/db/init/02-create-app-login.sql` — creates the app login/user in the containerized DB
- `docker/db/init/init-db.sh` — waits for SQL Server and initializes the DB on first run

## Regenerate the schema script

From the repo root:

`pwsh ./scripts/export-blogdb-schema.ps1 -ServerInstance 'AFMAIN\AFMAINSQL22' -Database 'BlogDB' -Username 'bloguser' -Password '<password>'`

If you regenerate the schema after the DB volume already exists, reset the local DB volume before restarting the stack so `db-init` can apply the new script:

`docker compose down -v`

## Run

From the repository root:

`docker compose up --build`

## One-command smoke test

From the repository root:

`pwsh ./scripts/smoke-test-docker-dev.ps1`

This command:

- runs `docker compose up --build -d`
- waits for `db-init` to finish successfully
- checks `http://localhost:5000/api/blog`
- checks `http://localhost:4200`

If the stack is already running and you only want to verify it:

`pwsh ./scripts/smoke-test-docker-dev.ps1 -SkipComposeUp`

## Stop

`docker compose down`

## Notes

- The DB container persists data in a named Docker volume
- The `db-init` service only applies the schema when `BlogDB` does not already exist in that volume
- The init script uses `sqlcmd -b`, so container startup now fails fast if schema application hits an error
- The API container restores NuGet packages and runs `dotnet run`
- The UI container installs packages into a Docker volume and runs `ng serve`
- File watching uses polling for better compatibility with mounted volumes on Windows
- The Angular app already points to `http://localhost:5000/api` for development
- The `.env` file is used for both Compose variable substitution and container environment overrides