# Migrations To Core 10 Lessons Learned

## Prompt 01

### Prompt 01 Scope

- Captured a route and runtime baseline before changing the backend architecture.

### Prompt 01 What mattered

- `dotnet build BlogLab.sln` succeeded before migration work started.
- The compose-managed `api` container was not a stable verification target because of a bind-mount file watcher crash loop.
- Host-running the API against Docker SQL was the most reliable way to capture the baseline.

### Prompt 01 Key findings

- The persisted local DB schema had drifted from the checked-in SQL init scripts.
- `POST /api/account/register` failed because the live `ApplicationUser`/`AccountType` schema did not include `IsAdmin`.
- Public read routes were reachable and auth-gated routes consistently enforced `401` for anonymous calls.

### Prompt 01 Follow-up impact

- Prompt 02 and Prompt 03 could proceed safely.
- Local DB reconciliation had to happen before relying on register/login as migration-time verification.

## Prompt 02

### Prompt 02 Scope

- Upgraded backend target frameworks from `netcoreapp3.1` to `net10.0` without changing route behavior.

### Prompt 02 What mattered

- All five backend projects had to move together because the web host references the other backend projects directly.
- The framework bump itself was low-risk once package modernization was deferred to the next step.

### Prompt 02 Outcome

- `BlogLab.Web`, `BlogLab.Models`, `BlogLab.Identity`, `BlogLab.Services`, and `BlogLab.Repository` now target `net10.0`.
- `dotnet restore BlogLab.sln` and `dotnet build BlogLab.sln` succeeded after the bump.

### Prompt 02 Follow-up impact

- The remaining work after Prompt 02 was package-related rather than framework-related.

## Prompt 03

### Prompt 03 Scope

- Modernized package references for .NET 10 compatibility and removed obsolete dependencies.

### Prompt 03 What mattered

- `Microsoft.AspNetCore.Http.Abstractions` was removable from the current source because the shared framework already covers the needed ASP.NET Core APIs.
- `System.Data.SqlClient` should be replaced, not just version-bumped, on modern .NET.
- Package graph changes introduced a `Microsoft.Extensions.Configuration.Abstractions` downgrade that had to be resolved directly in the consuming projects.

### Prompt 03 Outcome

- JWT/auth packages were modernized.
- Repository SQL client usage moved to `Microsoft.Data.SqlClient`.
- Restore and build finished with no warnings after the package refresh.

### Prompt 03 Follow-up impact

- Prompt 04 exposed runtime behavior differences from the newer token stack even though Prompt 03 built cleanly.

## Prompt 04

### Prompt 04 Scope

- Replaced the old `Program.cs` plus `Startup.cs` bootstrap with a single minimal-hosting `Program.cs` while keeping MVC controllers alive.

### Prompt 04 What mattered

- This project needed explicit imports for builder, DI, and hosting extension methods because they were not coming in implicitly.
- Preserving `AddControllers()` and `MapControllers()` kept the controller route surface stable during the hosting-model change.
- The newer token libraries enforced a stricter HS512 key-length requirement at runtime.

### Prompt 04 Outcome

- `Startup.cs` was removed.
- `Program.cs` now owns service registration and middleware pipeline setup.
- The JWT signing key in `appsettings.json` was lengthened so register/login continued to work.
- Build and representative route verification passed.

### Prompt 04 Follow-up impact

- Prompt 05 could focus on maintainability only, because functional parity was already re-established.

## Prompt 05

### Prompt 05 Scope

- Extract reusable setup from `Program.cs` into focused extension methods.

### Prompt 05 What mattered

- Keeping endpoint mapping in `Program.cs` preserved a clear distinction between app setup and route definition.
- Newer JWT bearer behavior required explicitly disabling inbound claim remapping so existing controller claim lookups continued to work unchanged.

### Prompt 05 Outcome

- Service registration moved into `Extensions/ServiceCollectionExtensions.cs`.
- Authentication setup moved into `Extensions/AuthenticationExtensions.cs`.
- CORS setup moved into `Extensions/CorsExtensions.cs`.
- `Program.cs` now reads as assembly order rather than implementation detail.
- Validation passed with `dotnet build BlogLab.sln`, `GET /api/blog = 200`, and authenticated `GET /api/photo = 200`.

## Prompt 06

### Prompt 06 Scope

- Add OpenAPI and Swagger in development to verify the current controller surface more easily.

### Prompt 06 What mattered

- `Swashbuckle.AspNetCore` 10.x on this stack uses `Microsoft.OpenApi.OpenApiInfo`, not the older `Microsoft.OpenApi.Models.OpenApiInfo` namespace.
- The development-only Swagger branch still needs the hosting extensions namespace imported so `app.Environment.IsDevelopment()` compiles inside an extension class.
- Keeping Swagger registration in its own extension method let Prompt 06 stay additive without cluttering `Program.cs`.

### Prompt 06 Outcome

- Added `Extensions/OpenApiExtensions.cs` with service registration and development-only middleware wiring.
- `Program.cs` now enables endpoint exploration and Swagger UI through the new extension methods.
- `dotnet build BlogLab.sln` succeeded after fixing the OpenAPI namespace and hosting extension imports.
- `GET /swagger/index.html` and `GET /swagger/v1/swagger.json` both returned `200` locally, and the generated document enumerates the existing controller routes.

### Prompt 06 Follow-up impact

- Prompt 07 can build on a working OpenAPI surface instead of relying only on manual route probes.

## Prompt 07

### Prompt 07 Scope

- Replaced `AccountController` with a minimal API route group under `/api/account` while leaving the rest of MVC routing in place.

### Prompt 07 What mattered

- Removing only the account controller avoided route conflicts while keeping the remaining controller surface untouched for later prompts.
- Minimal APIs do not inherit `[ApiController]` validation behavior, so request validation had to be made explicit to preserve `400` responses for invalid register/login payloads.
- Keeping the response-shaping logic in one helper reduced the risk of token or field drift between register and login.

### Prompt 07 Outcome

- Added a dedicated account endpoint mapper that exposes `POST /api/account/register` and `POST /api/account/login`.
- Preserved the existing `ITokenService`, `UserManager<ApplicationUserIdentity>`, and `SignInManager<ApplicationUserIdentity>` flow.
- Removed `AccountController` after the new minimal endpoints were wired into `Program.cs`.

### Prompt 07 Follow-up impact

- Prompt 08 can now migrate the larger blog surface without reopening the auth contract work.
- Prompt 12 should eventually remove controller infrastructure only after the remaining controller groups have been migrated.

## Prompt 08

### Prompt 08 Scope

- Replaced `BlogController` with a minimal API route group under `/api/blog` while keeping the remaining MVC controllers active.

### Prompt 08 What mattered

- The blog surface mixes anonymous reads with authenticated writes, so authorization had to remain endpoint-specific rather than group-wide.
- The previous controller relied on JWT `nameid` claims plus `User.IsInRole("Admin")` for ownership and delete semantics, so the minimal endpoints had to preserve those exact checks.
- `Get` still returns `200` with a null body when a blog is missing, while like-toggle and delete return `400` for a missing blog, so missing-resource behavior is intentionally inconsistent and had to stay that way for contract stability.

### Prompt 08 Outcome

- Added a dedicated blog endpoint mapper for list, get, get-by-user, famous, create, like-toggle, and delete routes.
- Preserved blog-create photo ownership validation and owner-or-admin delete logic.
- Removed `BlogController` after wiring the minimal endpoints through `Program.cs`.

### Prompt 08 Follow-up impact

- Prompt 09 can reuse the same incremental pattern for `BlogCommentController`.
- Prompt 13 is a good place to consolidate duplicated minimal-API helpers like validation and claim extraction once more route groups are migrated.

## Prompt 09

### Prompt 09 Scope

- Replaced `BlogCommentController` with a minimal API route group under `/api/blogcomment` while leaving the remaining MVC controllers active.

### Prompt 09 What mattered

- The comment surface is small but still mixes anonymous reads with authenticated writes, so authorization had to stay on the create and delete endpoints only.
- Delete behavior is owner-only, not owner-or-admin like blogs, so the minimal endpoint needed to preserve that narrower authorization rule.
- Minimal APIs do not inherit `[ApiController]` validation, so comment-create validation had to be made explicit to keep `400` responses stable for invalid payloads.
- Comment-create validation exposed an existing schema inconsistency: the API contract and `BlogCommentType` allow `ParentBlogCommentId` to be null for top-level comments, but the checked-in `dbo.BlogComment` table definition and persisted local DB still had the column as non-nullable.

### Prompt 09 Outcome

- Added a dedicated blog-comment endpoint mapper for list, create, and delete routes.
- Preserved JWT `nameid` claim lookup and the original delete error messages for missing or foreign-owned comments.
- Removed `BlogCommentController` after wiring the minimal endpoints through `Program.cs`.
- Updated the SQL init and reconciliation scripts so top-level blog comments can be created with a null `ParentBlogCommentId`, matching the existing request contract.

### Prompt 09 Follow-up impact

- Prompt 10 can follow the same route-group pattern for the photo surface.
- Prompt 13 remains the right cleanup point for extracting shared minimal-endpoint helpers.

## Prompt 10

### Prompt 10 Scope

- Replaced `PhotoController` with a minimal API route group under `/api/photo` while leaving the remaining MVC controllers active.

### Prompt 10 What mattered

- The upload endpoint is multipart and contract-sensitive: the form field name must remain `file`, and the Cloudinary upload plus repository insert flow had to stay unchanged.
- Photo deletion is owner-only and also depends on a second rule that blocks removal when the photo is still referenced by one of the current user's blogs.
- The historical baseline for `GET /api/photo/{photoId}` on a missing record is `204`, so the minimal endpoint needs explicit `NoContent()` handling instead of returning a `200` null payload.
- Host-running `dotnet` does not automatically load `.env`, so local verification needed the Cloudinary settings exported into the process environment before the upload route could be exercised.

### Prompt 10 Outcome

- Added a dedicated photo endpoint mapper for upload, get-mine, get-by-id, and delete routes.
- Preserved Cloudinary upload/delete service usage and the existing ownership plus in-use blog checks.
- Removed `PhotoController` after wiring the minimal endpoints through `Program.cs`.
- Verified `dotnet build BlogLab.sln`, authenticated `GET /api/photo = 200`, missing `GET /api/photo/{photoId} = 204`, authenticated missing-photo `DELETE /api/photo/{photoId} = 400`, and after exporting Cloudinary settings from `.env`, a full upload/get-mine/get-by-id/delete round trip for a real image.

### Prompt 10 Follow-up impact

- Prompt 11 can finish the route migration with the admin-only surface.
- Prompt 12 can remove controller infrastructure once the remaining controller is converted.

## Prompt 11

### Prompt 11 Scope

- Replaced `AdminBlogController` with a minimal API route group under `/api/admin/blog` and completed the controller-to-endpoint migration for the current API surface.

### Prompt 11 What mattered

- The admin route is still just a specialized blog listing endpoint, so it needed the same paging defaults and current-user claim extraction as the public blog list route.
- Authorization behavior is two-stage: anonymous requests should still be challenged by auth, but authenticated non-admin requests must continue to receive an explicit `403` with the existing message `You must be an admin to manage blogs.`
- Preserving the route as `/api/admin/blog` avoids forcing any client-side admin changes during the migration.

### Prompt 11 Outcome

- Added a dedicated admin-blog endpoint mapper for `GET /api/admin/blog`.
- Preserved the explicit admin-role gate and current-user-aware repository call.
- Removed `AdminBlogController` after wiring the minimal endpoint through `Program.cs`.

### Prompt 11 Follow-up impact

- Prompt 12 can now remove `AddControllers()` and `MapControllers()` because the controller surface has been fully migrated.
- Prompt 13 can consolidate repeated validation and claim helpers across the new endpoint mappers.

## Prompt 12

### Prompt 12 Scope

- Removed the remaining MVC controller infrastructure after all route groups had already been migrated to minimal APIs.

### Prompt 12 What mattered

- By the start of Prompt 12 the `Controllers` folder was already empty, so the remaining migration risk was limited to service-registration and endpoint-mapping cleanup rather than route logic changes.
- `AddControllers()` and `MapControllers()` could be removed only after verifying that every baseline route was already mapped through the new endpoint extensions.
- The route-baseline comparison for this prompt is meaningful because earlier prompts intentionally preserved route contracts while migrating one group at a time.
- Running the comparison immediately after removing MVC plumbing surfaced one subtle behavior drift: the missing-blog endpoint had become `200` under the minimal implementation and needed to be restored to the observed `204` baseline.

### Prompt 12 Outcome

- Removed `AddControllers()` from service registration.
- Removed `MapControllers()` from `Program.cs`.
- Left the existing minimal-hosting, auth, CORS, exception, and OpenAPI setup intact.
- Updated the minimal blog `GET /api/blog/{blogId}` endpoint to return `204 No Content` for missing blogs so the minimal-only host matches the baseline route behavior.
- Verified the Prompt 01 route surface against the minimal-only host: anonymous protected routes still return `401`, admin checks still return `401/403/200` in the expected cases, missing blog/photo reads return `204`, and the previously broken register/comment/photo flows now succeed after the earlier local schema and environment fixes.

### Prompt 12 Follow-up impact

- Prompt 13 can focus purely on minimal API cleanup and ergonomics instead of functional migration work.
- Controller-specific infrastructure is no longer part of the runtime path.

## Prompt 13

### Prompt 13 Scope

- Tightened the minimal API endpoint mappers for consistency and maintainability after functional parity had already been established.

### Prompt 13 What mattered

- Prompt 13 needed to stay behavior-preserving, so the right cleanup targets were duplicated validation code, duplicated JWT claim parsing, and OpenAPI metadata rather than endpoint logic changes.
- Shared helpers are only useful here if they preserve the existing `nameid` claim contract and the explicit validation behavior that replaced `[ApiController]` in earlier prompts.
- Minimal API route names show up directly as Swagger `operationId` values, so adding them is a low-risk way to make the document easier to inspect during the remaining migration steps.

### Prompt 13 Outcome

- Added `Extensions/EndpointValidationExtensions.cs` so request models can reuse one explicit validation path through `ValidateRequest()`.
- Added `Extensions/CurrentUserExtensions.cs` so all endpoint groups share the same current-user id and admin-role helpers.
- Updated the endpoint mappers to use typed result factories where that improved readability without changing the returned status codes or payloads.
- Added explicit route names across the feature route groups while keeping the existing tags, and verified through `GET /swagger/v1/swagger.json` that representative `operationId` values now include `Account_Register`, `Blog_GetAll`, `Photo_Upload`, and `AdminBlog_GetAll`, with the expected `Account`, `Blog`, `Photo`, and `AdminBlog` tags still present.
- Verified `dotnet build BlogLab.sln` still succeeds after the cleanup.

### Prompt 13 Follow-up impact

- Prompt 14 can focus on Docker and local-dev workflow changes without carrying forward endpoint-level duplication.
- Swagger/OpenAPI is now a more useful verification surface for the remaining migration prompts.

## Prompt 14

### Prompt 14 Scope

- Updated the Docker-based API development workflow for the migrated `.NET 10` backend and revalidated the Compose API path.

### Prompt 14 What mattered

- The existing Compose wiring already matched the current backend shape, so the core runtime change was the dev SDK image rather than a broader `docker-compose.yml` redesign.
- The API container still uses a bind-mounted workspace and runs `dotnet restore` plus `dotnet run`, so local validation needed to account for build-output contention between host-run and container-run API processes.
- The right Prompt 14 validation target was the Compose `api` service itself, not just a successful image build.

### Prompt 14 Outcome

- Updated `BlogLab.Web/Dockerfile.dev` from the old 3.1 SDK image to `mcr.microsoft.com/dotnet/sdk:10.0`.
- Updated `docs/docker-local-development.md` so it now describes the API container and host prerequisites in `.NET 10` terms.
- Ran `docker compose build api` successfully against the updated Dockerfile.
- Ran `docker compose up -d api` and verified `GET /api/blog` returns `200` from the Dockerized API on `http://localhost:5000`.
- Documented the local-dev caveat that host-running the API and Compose-running the API at the same time can produce `MSB3021` access-denied errors because both processes write to the same bind-mounted backend build outputs.

### Prompt 14 Follow-up impact

- Prompt 15 can now build on a working `.NET 10` Docker API path instead of treating Compose support as still pre-migration.
- Any repeatable smoke coverage added in Prompt 15 should avoid running the host API and Compose API concurrently.

## Prompt 15

### Prompt 15 Scope

- Added lightweight, repeatable backend verification coverage through a host-run smoke script instead of introducing a full integration test project.

### Prompt 15 What mattered

- The migration already had a stable verification pattern: host-run the API against Docker SQL using the local `sa` override, then exercise a small number of representative routes.
- A smoke script is only useful here if it covers the post-migration host shape, not just the container shape, and if it checks both authenticated and admin-only behavior rather than only anonymous reads.
- The Prompt 14 host-vs-container contention caveat still applies, so the backend script needed to stop any running Compose API before starting the host process.

### Prompt 15 Outcome

- Added `scripts/smoke-test-backend-host.ps1`.
- The script starts `db` and `db-init`, host-runs `BlogLab.Web`, waits for startup via `GET /api/blog`, registers and logs in a user, verifies authenticated `POST /api/blog`, verifies non-admin `GET /api/admin/blog = 403`, promotes that user to admin through the local SQL container, and then verifies admin `GET /api/admin/blog = 200`.
- The script supports `-SkipComposeUp` and `-SkipApiStart` so it can be reused in different local verification flows.
- Verified the script end-to-end with `pwsh ./scripts/smoke-test-backend-host.ps1`.

### Prompt 15 Follow-up impact

- The migration now has a repeatable backend verification command that covers startup, anonymous read readiness, an authenticated route, and an admin-only route.
- Any later backend changes can use the new smoke script as the fastest regression check before larger UI or Docker-stack validation.
