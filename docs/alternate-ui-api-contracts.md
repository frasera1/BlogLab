# BlogLab Alternate UI API Contract Inventory

## Existing API Surface Reused by the Next.js UI

Base API URL: `http://localhost:5000/api`

### Account

- `POST /api/account/register` → request `{ username, password, email, fullname? }`, response `ApplicationUser`
- `POST /api/account/login` → request `{ username, password }`, response `ApplicationUser`

### Blog

- `POST /api/blog` (auth) → request `{ blogId, title, content, photoId? }`, response `Blog`
- `GET /api/blog?Page={page}&PageSize={pageSize}` → response `PagedResults<Blog>`
- `GET /api/blog/{blogId}` → response `Blog`
- `GET /api/blog/user/{applicationUserId}` → response `Blog[]`
- `GET /api/blog/famous` → response `Blog[]`
- `DELETE /api/blog/{blogId}` (auth) → response affected row count as `number`

### Comment

- `POST /api/blogcomment` (auth) → request `{ blogCommentId, parentBlogCommentId?, blogId, content }`, response `BlogComment`
- `GET /api/blogcomment/{blogId}` → response `BlogComment[]`
- `DELETE /api/blogcomment/{blogCommentId}` (auth) → response affected row count as `number`

### Photo

- `POST /api/photo` (auth, multipart) → form field name must be `file`, response `Photo`
- `GET /api/photo` (auth) → response current user's `Photo[]`
- `GET /api/photo/{photoId}` → response `Photo`
- `DELETE /api/photo/{photoId}` (auth) → response affected row count as `number`

## Frontend Contract Notes

- ASP.NET Core is using default controller JSON serialization, so the Next.js layer models wire payloads in `camelCase`.
- The typed clients now live in `bloglab-ui-next/src/lib/api/` and cover `account`, `blog`, `comment`, and `photo` operations.
- Shared request/response types are defined in `bloglab-ui-next/src/lib/api/contracts.ts`.

## Backend Mismatches / Gaps Relevant to the Alternate UI

1. **Auth is token-returning only**
   - `login` and `register` return a JWT-bearing `ApplicationUser` payload.
   - There is no `GET /api/account/me`, refresh-token flow, or cookie/session endpoint.
   - The alternate UI will need a Next.js BFF/route-handler layer or client-side token persistence strategy until backend session endpoints exist.

2. **Blog writes are POST upserts, not RESTful create/update splits**
   - Blog editing depends on `POST /api/blog` with `blogId` in the body.
   - There is no `PUT`/`PATCH /api/blog/{id}` endpoint.
   - This is usable, but the frontend must model it as an upsert contract rather than separate create/update APIs.

3. **Error payloads are inconsistent across 400 responses**
   - Some actions return a plain string.
   - Identity failures return an array of `{ code, description }` objects.
   - Validation failures can return `ProblemDetails`-style `errors` maps.
   - The Next client normalizes these shapes, but a consistent backend error contract would simplify modal UX.

4. **Photo upload is multipart-only and bound to a single field name**
   - Upload requires `multipart/form-data` with a file field named `file`.
   - There is no JSON-based upload initiation contract or metadata mutation endpoint.

5. **No dedicated current-user profile endpoint**
   - The UI gets user profile data only as a side effect of login/register.
   - A `GET /api/account/me` endpoint would make session restoration and SSR-safe auth checks much cleaner.
