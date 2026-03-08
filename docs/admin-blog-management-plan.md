## Prompt 19 - Admin Blog Management Plan

### Scope

This plan is intentionally limited to **view + delete only**.

- Admins can review blogs across users in a dedicated admin area.
- Admins can delete any blog.
- Admins cannot create or edit blogs on behalf of other users.
- Existing author flows remain ownership-based and unchanged.

### Audit Summary

#### Current backend state

- Authentication exists, but there is no admin role in the database model.
- `ApplicationUser` and `ApplicationUserIdentity` do not contain an admin flag.
- `TokenService` only emits `nameid` and `unique_name` claims.
- `DELETE /api/blog/{blogId}` is authenticated, but authorization is owner-only in `BlogController`.
- `BlogRepository.DeleteAsync(int blogId)` is generic; the ownership check happens in the controller.
- `Blog_Upsert` enforces ownership by matching both `BlogId` and `ApplicationUserId`, which is good for keeping cross-user edit out of scope.

#### Current database state

- `dbo.ApplicationUser` has no `IsAdmin` or role column.
- `dbo.AccountType`, `Account_Insert`, and `Account_GetByUsername` do not persist or return admin state.
- Blog reads are available through `Blog_GetAll`, `Blog_Get`, and `Blog_GetByUserId`.
- Public blog reads already include useful admin-review metadata such as `BlogId`, `ApplicationUserId`, `Username`, `Title`, `PhotoId`, `PublishDate`, and `UpdateDate`.

#### Current Next.js alternate UI state

- Login/register already persist a secure cookie-backed session.
- The typed `ApplicationUser` contract does not include admin state.
- `AuthSession` and the session cookie payload do not include admin state.
- Authenticated blog deletion already flows through the Next.js BFF route `DELETE /api/blog/[blogId]`.
- Existing protected author pages are for the signed-in author only and should stay separate from admin management.

### Smallest Safe Feature Set

The smallest safe admin feature set is:

1. represent admin status explicitly in the backend and auth payloads
2. surface that status into the Next.js session contract
3. add a dedicated admin-only read path for reviewing blogs across users
4. add admin-only delete-any-blog authorization
5. add a dedicated admin UI for review + delete only

### Required Contract Changes

#### Prompt 20 - backend foundations

- Add `IsAdmin` to `dbo.ApplicationUser`.
- Extend `dbo.AccountType` to include `IsAdmin`.
- Update `Account_Insert` and `Account_GetByUsername` to write/read `IsAdmin`.
- Add `IsAdmin` to:
  - `BlogLab.Models/Account/ApplicationUserIdentity.cs`
  - `BlogLab.Models/Account/ApplicationUser.cs`
- Update `AccountRepository` table-valued parameter mapping.
- Update login/register response shaping so `ApplicationUser` includes `IsAdmin`.
- Add an admin claim in `TokenService` so backend authorization can rely on token claims.

#### Prompt 21 - Next.js session propagation

- Add `isAdmin` to `bloglab-ui-next/src/lib/api/contracts.ts` `ApplicationUser`.
- Let `AuthUser` continue deriving from `ApplicationUser` without `token`.
- Update session shaping in `src/lib/auth/session.ts` so `isAdmin` is stored and validated.
- Update login/register route handlers so the session cookie reflects backend admin state.

#### Prompt 22 - admin-only reads

Preferred approach:

- Add a dedicated backend endpoint for admin blog management, rather than overloading owner/public paths.
- Keep the response shape close to the existing `Blog` contract if possible.

Recommended endpoint:

- `GET /api/admin/blog`

Recommended behavior:

- requires authentication
- requires admin role/claim
- returns a paged list of blogs across users
- includes author metadata already present in the current blog read model
- returns `403` for authenticated non-admin users

This is safer than reusing author endpoints because it keeps privileged reads explicit.

#### Prompt 23 - admin UI

Recommended page:

- `/admin/blogs`

Recommended behavior:

- server-side session guard requiring `session.user.isAdmin === true`
- clear access-denied state for signed-in non-admin users
- separate navigation entry from author pages
- read-only review table/cards first
- show author username, blog id, dates, title, excerpt, and link to public detail

#### Prompt 24 - admin delete authorization

Recommended behavior:

- keep `POST /api/blog` and `Blog_Upsert` owner-based only
- extend delete authorization only
- allow delete when the caller is either:
  - the blog owner, or
  - an admin

This can likely be implemented in `BlogController` without changing `BlogRepository.DeleteAsync(int blogId)`.

#### Prompt 25 - admin delete flow in Next.js

- Add an admin-facing delete action from `/admin/blogs`.
- Reuse the secure Next.js BFF pattern for authenticated delete requests.
- Add admin-specific confirmation copy so destructive access is unmistakable.
- Revalidate `/admin/blogs` as well as affected public pages after deletion.

### Important Constraints

- Do not add cross-user edit support.
- Do not weaken the existing owner-based save/upsert flow.
- Keep admin UI separate from the author workspace.
- Keep privileged browser-side actions behind Next.js route handlers because auth depends on HTTP-only cookies.

### Recommended Implementation Order

1. Prompt 20 - add backend admin representation and auth payload support
2. Prompt 21 - propagate `isAdmin` through the Next.js session layer
3. Prompt 22 - add dedicated admin-only blog list endpoint
4. Prompt 23 - build read-only `/admin/blogs`
5. Prompt 24 - permit admin delete-any-blog in backend + BFF
6. Prompt 25 - add admin delete UX only

### Go/No-Go Decision

This feature is safe to proceed with in small steps because the current system already separates:

- backend authorization logic in controllers
- authenticated browser mutations through the Next.js BFF
- owner-based upsert semantics in SQL

That makes **admin read + delete** a tractable addition without expanding into higher-risk cross-user edit behavior.