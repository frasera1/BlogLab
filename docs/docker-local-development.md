# Docker Local Development

## What this setup runs

- `api` — ASP.NET Core 3.1 API on `http://localhost:5000`
- `ui` — Angular 11 dev server on `http://localhost:4200`

The database is **not** containerized in this setup.

## Prerequisites

- Docker Desktop
- A reachable external SQL Server database

## Important database note

The current `appsettings.json` uses Windows integrated security against a machine-specific SQL Server instance.
That connection string is not suitable for the Linux API container.

By default, the API container will use the connection string already present in `BlogLab.Web/appsettings.json`.

If you need to override it for Docker local development, use a `.env` file.

In practice, **Linux containers commonly cannot use Windows named-instance + integrated-security connection strings** reliably. If your `appsettings.json` uses a server name like `MACHINE\\INSTANCE`, prefer overriding it with a SQL-auth connection string that uses a reachable host/IP and explicit port.

Example:

`ConnectionStrings__DefaultConnection=Server=host.docker.internal,1433;Database=BlogDB;User Id=bloglab_user;Password=change-me;TrustServerCertificate=True;Encrypt=False`

If your SQL Server is on another machine, replace `host.docker.internal` with that host name or IP.

## Setup

1. If needed, copy `.env.example` to `.env`
2. If needed, update `ConnectionStrings__DefaultConnection`
3. Fill in Cloudinary values if you need photo upload support

## Run

From the repository root:

`docker compose up --build`

## Stop

`docker compose down`

## Notes

- The API container restores NuGet packages and runs `dotnet run`
- The UI container installs packages into a Docker volume and runs `ng serve`
- File watching uses polling for better compatibility with mounted volumes on Windows
- The Angular app already points to `http://localhost:5000/api` for development
- The `.env` file is optional and is only used for container environment overrides