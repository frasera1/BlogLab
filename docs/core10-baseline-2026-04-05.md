# BlogLab API Baseline - 2026-04-05

## Build baseline

- `dotnet build BlogLab.sln` succeeds on the current codebase.
- Current build warnings:
  - `netcoreapp3.1` is out of support (`NETSDK1138`).
  - `System.Data.SqlClient 4.8.2` has known moderate/high vulnerabilities.
  - `Microsoft.AspNetCore.Authentication.JwtBearer 3.1.14` has a known moderate vulnerability.
  - `System.IdentityModel.Tokens.Jwt 6.11.0` has a known moderate vulnerability.

## Practical local run steps used for this baseline

1. Start SQL Server from Docker:
   - `docker compose up -d db db-init`
2. Run the API on the host instead of the compose `api` service:
   - the compose `api` container intermittently hits a bind-mount file watcher `System.IO.IOException` and restarts.
3. Use an override connection string to the Dockerized SQL instance:
   - `ConnectionStrings__DefaultConnection=Server=localhost,14333;Database=BlogDB;User Id=sa;Password=BlogLab!DevSa2026;Persist Security Info=False;Pooling=False;MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=True`
4. Start the API:
   - `dotnet run --project BlogLab.Web --no-launch-profile --urls http://localhost:5000`

Notes:

- The persisted local Docker DB is schema-drifted relative to `docker/db/init/01-schema.sql`.
- The live `ApplicationUser` table and `dbo.AccountType` type currently have 6 columns, while the checked-in code and schema expect 7 including `IsAdmin`.
- Because of that drift, `POST /api/account/register` currently fails before a normal authenticated user can be created.
- The compose default app login (`bloguser`) also did not work against the persisted local DB volume in this environment, so the host-run used `sa` for the baseline only.

## Route smoke baseline

Observed against `http://localhost:5000`.

| Route | Observed status | Notes |
| --- | --- | --- |
| `POST /api/account/register` | `500` | Valid request fails. Server log shows TVP/schema mismatch: code sends 7 columns to `dbo.AccountType`, live DB expects 6. |
| `POST /api/account/login` | `400` | `Invalid login attempt.` after failed register. |
| `GET /api/blog` | `200` | Returned empty page payload: `{"items":[],"totalCount":0}`. |
| `GET /api/blog/{blogId}` | `204` | Missing blog id currently returns no content for `GET /api/blog/999999`. |
| `GET /api/blog/user/{applicationUserId}` | `200` | Returned empty array for `applicationUserId=0`. |
| `GET /api/blog/famous` | `200` | Returned empty array. |
| `POST /api/blog` | `401` anonymous, `500` with synthetic valid JWT | Anonymous request is blocked by auth. With a signed synthetic token, the request reached the handler and failed at SQL because no matching user row exists in the drifted local DB. |
| `POST /api/blog/{blogId}/like/toggle` | `401` anonymous, `400` with synthetic valid JWT on `blogId=999999` | Anonymous request is blocked by auth. Authenticated request returns `Blog does not exist.` |
| `GET /api/blogcomment/{blogId}` | `200` | Returned empty array for `blogId=999999`. |
| `POST /api/blogcomment` | `401` anonymous, `500` with synthetic valid JWT | Anonymous request is blocked by auth. Authenticated request currently hits a DB constraint error (`ParentBlogCommentId` null handling in the persisted DB path). |
| `GET /api/photo/{photoId}` | `204` | Missing photo id currently returns no content for `GET /api/photo/999999`. |
| `GET /api/photo` | `401` anonymous, `200` with synthetic valid JWT | Authenticated request returned an empty collection. |
| `POST /api/photo` | `401` anonymous, `400` with synthetic valid JWT | Anonymous request is blocked by auth. Authenticated multipart upload reached the handler and returned `400` in this baseline run. |
| `GET /api/admin/blog` | `401` anonymous, `403` with synthetic non-admin JWT, `200` with synthetic admin JWT | Auth pipeline and explicit admin check are both active. Admin-authenticated request returned `200` with an empty page payload. |

## Baseline issues to compare after migration

- Account registration is currently broken on this local DB because the persisted SQL schema does not match the checked-in code/schema around `IsAdmin`.
- The compose `api` container is not a stable baseline run target on this machine because of the file watcher restart issue.
- Public read routes are reachable and currently return empty payloads when the database has no rows.
- Protected routes consistently reject anonymous requests with `401`.