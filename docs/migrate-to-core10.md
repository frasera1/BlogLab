## BlogLab.Web -> .NET 10 Minimal API Migration Plan

### Current snapshot

- `BlogLab.Web`, `BlogLab.Models`, `BlogLab.Identity`, `BlogLab.Services`, and `BlogLabRepository` now target `net10.0`.
- `BlogLab.Web` now uses minimal hosting in `Program.cs`; `Startup.cs` and the MVC controller classes have been removed.
- The API now runs through minimal API route groups for account, blog, blog comment, photo, and admin blog endpoints while preserving the existing route contracts.
- The backend still uses JWT bearer auth, ASP.NET Core Identity, Dapper, Cloudinary, custom exception middleware, and permissive development CORS.
- `docker-compose.yml` and `BlogLab.Web/Dockerfile.dev` now support the `.NET 10` local Docker workflow.
- Lightweight backend verification coverage now exists through `scripts/smoke-test-backend-host.ps1`, alongside the broader Docker dev smoke script in `scripts/smoke-test-docker-dev.ps1`.

### Current status

- This migration plan has been executed through Prompt 15.
- The repo now matches the "Definition of done" below, and the remaining value of this file is as an execution record plus a prompt-by-prompt migration checklist.

### Migration principles

1. Upgrade to `.NET 10` first while preserving behavior.
2. Keep existing routes and JSON contracts stable so Angular and Next.js clients keep working.
3. Convert controllers to minimal APIs one endpoint group at a time.
4. Do not mix runtime upgrade, endpoint redesign, and feature changes in the same prompt.
5. After each step, run the smallest useful validation command before continuing.

### Definition of done

- All backend projects required by `BlogLab.Web` build on `net10.0`.
- `BlogLab.Web` uses minimal hosting and minimal API route mapping.
- `Startup.cs` and MVC controllers are removed.
- Existing API routes still behave the same unless a prompt explicitly changes them.
- Docker/dev workflow runs on a .NET 10 SDK image.
- The app builds, starts, authenticates, and serves the current API routes successfully.

### Prompt 01 - Capture a baseline before changing anything

Goal: create a safety baseline for routes, auth behavior, and local run steps.

- Build the current solution.
- Start the API locally or in Docker.
- Record the currently reachable routes and expected status codes for:
  - `POST /api/account/register`
  - `POST /api/account/login`
  - `GET /api/blog`
  - `GET /api/blog/{blogId}`
  - `GET /api/blog/user/{applicationUserId}`
  - `GET /api/blog/famous`
  - `POST /api/blog`
  - `POST /api/blog/{blogId}/like/toggle`
  - `GET /api/blogcomment/{blogId}`
  - `POST /api/blogcomment`
  - `GET /api/photo/{photoId}`
  - `GET /api/photo`
  - `POST /api/photo`
  - `GET /api/admin/blog`
- Save the baseline in a short markdown note under `docs/` for later comparison.

Validation:

- `dotnet build BlogLab.sln`
- a quick manual or scripted smoke check of the main routes

### Prompt 02 - Upgrade all backend project target frameworks to .NET 10

Goal: make the project graph compatible with a `.NET 10` web host before touching routing style.

- Update these projects from `netcoreapp3.1` to `net10.0`:
  - `BlogLab.Web`
  - `BlogLab.Models`
  - `BlogLab.Identity`
  - `BlogLab.Services`
  - `BlogLabRepository`
- Do not convert controllers to minimal APIs yet.
- Keep the app behaviorally identical after the framework bump.

Validation:

- `dotnet restore BlogLab.sln`
- `dotnet build BlogLab.sln`

### Prompt 03 - Modernize NuGet packages for .NET 10 compatibility

Goal: remove or upgrade packages that are obsolete, redundant, or risky on modern ASP.NET Core.

- Review package references in all backend `.csproj` files.
- Prefer removing packages now included by the shared framework instead of pinning very old abstractions packages.
- Replace or upgrade packages that block `net10.0`.
- Pay special attention to:
  - `Microsoft.AspNetCore.Http.Abstractions`
  - `Microsoft.Extensions.Identity.Core`
  - `System.Data.SqlClient` vs `Microsoft.Data.SqlClient`
  - JWT/auth packages
- Use `dotnet add package` / `dotnet remove package` rather than hand-editing package versions when possible.

Validation:

- `dotnet restore BlogLab.sln`
- `dotnet build BlogLab.sln`
- note any compile/runtime warnings that should be handled in the next prompt

### Prompt 04 - Move from Startup.cs to minimal hosting without removing controllers yet

Goal: adopt the modern `.NET 10` hosting model first, while still mapping the existing controllers.

- Replace the old `Program.cs` + `Startup.cs` bootstrap with a single minimal-hosting `Program.cs`.
- Move service registration from `Startup.ConfigureServices` into the builder setup.
- Move middleware pipeline logic from `Startup.Configure` into the `WebApplication` pipeline.
- Keep these behaviors intact:
  - Cloudinary options binding
  - repository/service registrations
  - Identity registration
  - JWT bearer auth
  - dev CORS behavior
  - custom exception handling
  - `MapControllers()`
- Do not remove controllers yet.

Validation:

- `dotnet build BlogLab.sln`
- `dotnet run --project BlogLab.Web`
- verify the old controller routes still respond

### Prompt 05 - Extract reusable setup into extension methods

Goal: keep `Program.cs` small before adding minimal API route groups.

- Create focused extension methods for:
  - service registration
  - authentication/authorization setup
  - CORS setup
  - exception pipeline setup
- Keep endpoint mapping out of these service-registration extensions for now.
- Leave behavior unchanged.

Validation:

- `dotnet build BlogLab.sln`
- smoke test one public route and one authorized route

### Prompt 06 - Add OpenAPI support for migration-time verification

Goal: make route verification easier while converting controllers to minimal APIs.

- Add OpenAPI/Swagger support in development.
- Make sure the generated API surface reflects the current controller routes first.
- Keep this scoped to developer productivity; do not redesign API contracts.

Validation:

- `dotnet run --project BlogLab.Web`
- confirm Swagger/OpenAPI loads in development

### Prompt 07 - Convert AccountController to a minimal API route group

Goal: migrate the smallest authentication surface first.

- Replace `AccountController` with a minimal API route group under `/api/account`.
- Preserve request/response contracts and status code behavior.
- Keep using the existing services:
  - `ITokenService`
  - `UserManager<ApplicationUserIdentity>`
  - `SignInManager<ApplicationUserIdentity>`
- Remove only this controller after the minimal endpoints are working.

Validation:

- `dotnet build BlogLab.sln`
- smoke test register and login

### Prompt 08 - Convert BlogController to a minimal API route group

Goal: migrate the largest and highest-value route group carefully.

- Replace `BlogController` with minimal API endpoints under `/api/blog`.
- Preserve all current routes and semantics, including:
  - anonymous reads
  - authorized create/delete/like toggle
  - claim-based current user lookup
  - owner/admin delete logic
- Prefer route-group helpers or local private methods so the file stays readable.
- Keep the response shapes identical.

Validation:

- `dotnet build BlogLab.sln`
- smoke test list, get, create, like toggle, and delete

### Prompt 09 - Convert BlogCommentController to a minimal API route group

Goal: continue the controller-to-endpoint migration with a smaller dependency surface.

- Replace `BlogCommentController` with minimal API endpoints under `/api/blogcomment`.
- Preserve authorization, route templates, and response shapes.
- Remove only this controller after the minimal endpoints work.

Validation:

- `dotnet build BlogLab.sln`
- smoke test comment list/create/delete

### Prompt 10 - Convert PhotoController to a minimal API route group

Goal: migrate the photo endpoints without changing Cloudinary behavior.

- Replace `PhotoController` with minimal API endpoints under `/api/photo`.
- Preserve multipart/form-data handling, auth rules, and ownership checks.
- Keep `IPhotoService` and repository usage unchanged unless the compiler forces a small adaptation.

Validation:

- `dotnet build BlogLab.sln`
- smoke test get-by-id, get-mine, upload, and delete

### Prompt 11 - Convert AdminBlogController to a minimal API route group

Goal: finish the privileged endpoints and keep admin authorization explicit.

- Replace `AdminBlogController` with minimal API endpoints under `/api/admin/blog`.
- Preserve the current admin-only authorization behavior.
- Use named authorization policies if that makes the minimal API version clearer.

Validation:

- `dotnet build BlogLab.sln`
- verify admin route behavior for both admin and non-admin callers

### Prompt 12 - Remove MVC controller infrastructure

Goal: complete the minimal API migration once all route groups are live.

- Delete the remaining controller classes after their minimal equivalents are confirmed.
- Remove `AddControllers()` and `MapControllers()`.
- Remove `Startup.cs` if it still exists.
- Clean up unused MVC/controller usings and packages.

Validation:

- `dotnet build BlogLab.sln`
- run the same route baseline from Prompt 01 and compare results

### Prompt 13 - Tighten minimal API ergonomics and consistency

Goal: improve maintainability after functional parity is reached.

- Organize minimal endpoints into feature files or endpoint-mapping extension classes.
- Use typed results where it improves clarity.
- Add common helpers for reading the current user id and admin status from claims.
- Add route names/tags where useful for OpenAPI readability.
- Keep this cleanup behavior-preserving.

Validation:

- `dotnet build BlogLab.sln`
- inspect Swagger/OpenAPI output

### Prompt 14 - Update Docker and local development workflow for .NET 10

Goal: ensure the upgraded API runs the same way in local Docker-based development.

- Update `BlogLab.Web/Dockerfile.dev` to a .NET 10 SDK image.
- Verify `docker-compose.yml` still builds and runs the API service.
- Confirm the `dotnet restore` and `dotnet run` commands still work in the container.
- Keep exposed port and env var behavior the same unless a migration issue requires a documented change.

Validation:

- `docker compose build api`
- `docker compose up api`

### Prompt 15 - Add backend verification coverage for the migrated host

Goal: leave the system safer than it started.

- Add a lightweight backend test project if none exists.
- Cover at least:
  - app startup
  - one anonymous read route
  - one authenticated route
  - one admin-only route
- If a full integration test harness is too large for one step, at minimum add a repeatable smoke-test script under `scripts/`.

Validation:

- run the smallest targeted test command for the new test project or smoke script

### Recommended execution order

1. Prompt 01
2. Prompt 02
3. Prompt 03
4. Prompt 04
5. Prompt 05
6. Prompt 06
7. Prompt 07
8. Prompt 08
9. Prompt 09
10. Prompt 10
11. Prompt 11
12. Prompt 12
13. Prompt 13
14. Prompt 14
15. Prompt 15

### Notes for whoever executes the prompts

- The safest path is **upgrade first, convert second**.
- Because `BlogLab.Web` references other backend projects, the migration cannot be isolated to the web project's target framework alone.
- Keep Angular and Next.js clients stable by preserving current routes and response contracts during the migration.
- If a prompt uncovers a breaking package issue, solve it in that prompt and do not silently bundle unrelated refactors.