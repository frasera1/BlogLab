# BlogLab Admin User and Profile Management Prompts

## Objective

Extend the current admin/blog groundwork into a safer, broader management feature set that covers:

- admin dashboard support for managing users
- admin role changes
- admin-initiated user deletion and cleanup of related artifacts
- self-service profile management for normal users and admins

This plan assumes the existing admin blog review flow remains in place and should not be regressed.

## Current Baseline

What already exists:

- backend admin state is already represented on `ApplicationUser` and `ApplicationUserIdentity`
- JWT creation already emits an admin/user role claim
- `GET /api/admin/blog` already exists for admin-only blog review
- the Next.js alternate UI already has an `/admin/blogs` page and protected admin shell
- the Next.js session contract already carries `isAdmin`

What is still missing:

- no `GET /api/account/me` endpoint
- no `PUT /api/account/me` endpoint
- no admin user listing endpoint
- no admin user role-change endpoint
- no admin user deletion endpoint
- the custom identity store still has `FindByIdAsync`, `UpdateAsync`, and `DeleteAsync` unimplemented
- the account repository only supports create and lookup-by-username today
- user deletion cannot be a trivial row delete because blogs, comments, likes, and photos all reference `ApplicationUser`

## Delivery Rules

- Keep each step small and reviewable.
- Validate each prompt before moving to the next one.
- Do not weaken existing owner-based author flows.
- Keep privileged admin actions in explicit admin-only backend routes.
- Keep browser mutations behind the existing Next.js BFF/route-handler pattern.
- Treat destructive user deletion as a coordinated workflow, not a direct table delete.

## Tracking Notes

- Add an `Expected outcome` section under every prompt before implementation starts.
- Add a `Lessons learned after completion` section only when a prompt is actually completed.
- Treat this document as the working record for scope decisions and prompt-by-prompt outcomes.

## Recommended Feature Order

1. backend account read/update primitives
2. current-user profile endpoints
3. Next.js self-service profile page
4. admin user list/read support
5. admin role changes
6. admin user deletion orchestration
7. admin user-management UI
8. targeted tests and rollout notes

## Prompt 01 - Audit and Lock the Account Management Scope

Inspect the current account, identity-store, repository, SQL schema, Next.js session, and admin UI code paths. Confirm the exact MVP scope for user/admin profile management and admin user management. Keep the scope limited to:

- self-service profile read/update
- admin user list
- admin toggle of admin role
- admin delete of a user and their related artifacts

Explicitly do not add password reset, email verification, or admin editing of arbitrary user content beyond role and delete flows.

### Expected outcome

- A locked MVP scope for account/profile/admin-user management is documented and agreed in this plan.
- The team knows which backend and frontend gaps are prerequisite work.
- Risky items are explicitly deferred instead of leaking into later prompts.

### Lessons learned after completion

- Admin/blog foundations are already present, so this effort is an extension of the current admin slice rather than a new authorization project.
- The main backend gap is not admin identity; it is missing account-management primitives. The custom identity store still lacks `FindByIdAsync`, `UpdateAsync`, and `DeleteAsync`, and the account repository only supports create plus lookup by username.
- Self-service profile management should start with `fullname` and `email`. Username rename is higher risk for the first pass because there is no existing update flow and the current codebase does not yet establish rename-safe behavior.
- The Next.js app already has the right structural patterns for this work: secure cookie-backed session shaping, protected `/me/*` author pages, and protected admin workspace patterns. That reduces UI risk materially.
- User deletion must be implemented as explicit orchestration. The SQL schema has foreign-key references from `Photo`, `Blog`, `BlogComment`, and `BlogLike` back to `ApplicationUser`, so deleting a user requires ordered cleanup instead of a direct delete.
- The MVP scope is now locked to: self-service profile read/update, admin user listing, admin role toggle, and admin delete of a user plus related artifacts.

### Scope decisions locked by Prompt 01

- In scope for MVP:
	- `GET /api/account/me`
	- `PUT /api/account/me`
	- admin-only user list/read endpoint
	- admin-only role-change endpoint
	- admin-only user deletion endpoint backed by orchestration
	- `/me/profile`
	- `/admin/users`
- Deferred from MVP:
	- password reset
	- email verification
	- audit logging
	- soft delete / restore
	- admin editing of arbitrary user-owned content
	- bulk moderation tools
	- username editing unless a later prompt proves it is safe enough to include

## Prompt 02 - Add Repository and Identity-Store Primitives for Account Lookup and Update

Implement the missing backend primitives needed for profile management and admin user management. Extend the account repository and custom identity store so they support:

- find user by id
- update user profile fields
- delete user

Add only the minimum SQL stored procedures and repository contracts required. Keep the data model aligned with the existing `ApplicationUser` and `ApplicationUserIdentity` types.

### Expected outcome

- The backend has the minimum repository and identity-store operations needed for account lookup, profile updates, and eventual delete orchestration.
- The rest of the plan can build on explicit account primitives instead of ad hoc SQL calls.

### Lessons learned after completion

- The current identity abstraction is simple enough that Prompt 02 could stay small: adding repository methods plus implementing `UserStore.FindByIdAsync`, `UserStore.UpdateAsync`, and `UserStore.DeleteAsync` was sufficient to establish the missing primitives.
- The safest low-level update primitive is a full account-row update rather than separate one-field procedures. That keeps the repository aligned with `ApplicationUserIdentity` and works with normal identity-store update semantics.
- The low-level delete primitive can exist before delete orchestration exists, but it should be treated as an internal building block only. It is not safe for admin UI use until Prompt 12 adds dependent-artifact cleanup.
- SQL changes need to land in both the baseline schema file and the reconcile script so fresh database init and already-existing local databases stay aligned.
- Solution validation in this repo should prefer isolated artifacts builds when `BlogLab.Web` is running locally, because normal output paths can be locked by the active host process.

### Completion notes

- Added account repository primitives for get-by-id, update, and delete.
- Implemented the matching custom identity-store methods.
- Added `Account_GetById`, `Account_Update`, and `Account_Delete` stored procedures to both checked-in SQL init paths.
- Validation succeeded with `dotnet build BlogLab.sln --disable-build-servers --artifacts-path tests/artifacts/.artifacts-prompt02`.

## Prompt 03 - Add a Safe Current-User Account API

Add the minimum authenticated account endpoints needed for self-service profile management:

- `GET /api/account/me`
- `PUT /api/account/me`

Return the same core user shape already used by login/register, minus any unnecessary token reshaping unless the update flow requires a refreshed token. Preserve clear validation behavior and keep authorization based on the authenticated current user only.

### Expected outcome

- Authenticated users can fetch and update their own account details through stable backend endpoints.
- The backend now exposes a clean current-user contract instead of forcing the UI to rely on login/register side effects.

### Lessons learned after completion

- A small dedicated update model is cleaner than reusing register/login DTOs because current-user profile updates do not need password or username fields.
- The first backend profile slice should keep username read-only. That keeps Prompt 03 aligned with the MVP scope locked in Prompt 01 and avoids token/claim churn around `unique_name`.
- `GET /api/account/me` and `PUT /api/account/me` can safely reuse the existing `ApplicationUser` response shape while omitting token refresh. Since the current Prompt 03 update surface only changes `Email` and `Fullname`, no refreshed JWT is required.
- Implementing the endpoints through `UserManager` keeps the flow aligned with Identity normalization and the custom `UserStore` added in Prompt 02, instead of bypassing identity semantics with direct repository calls from the endpoint layer.

### Completion notes

- Added authenticated `GET /api/account/me` and `PUT /api/account/me` routes.
- Added `ApplicationUserUpdate` as the minimal request model for current-user profile edits.
- The new current-user endpoints return the standard `ApplicationUser` shape with `Token = null` because profile read/update does not currently require token refresh.
- Validation succeeded with `dotnet build BlogLab.sln --disable-build-servers --artifacts-path tests/artifacts/.artifacts-prompt03`.

## Prompt 04 - Add Next.js API Client and BFF Support for Current-User Profile Management

Extend the Next.js alternate UI API layer and route-handler/BFF layer to support the new current-user account endpoints. Reuse the existing secure cookie-backed auth/session pattern and keep browser-side code unaware of raw bearer-token storage.

### Expected outcome

- The Next.js app can call the new current-user profile endpoints through the existing secure BFF pattern.
- Browser components do not need direct bearer-token handling to manage profile data.

### Lessons learned after completion

- Prompt 04 required one small but important infrastructure change: the shared API client had to support `PUT` requests before profile updates could flow through the existing client abstraction.
- Profile-update BFF support must refresh the session cookie without overwriting the auth-token cookie. Because the backend `PUT /api/account/me` response intentionally returns `ApplicationUser` with `Token = null`, reusing the login/register session persistence helper would have clobbered the stored bearer token.
- Adding a dedicated session-only refresh helper in the Next.js auth layer keeps the current secure cookie model intact while allowing profile data in the session cookie to stay current.
- The cleanest Prompt 04 scope is: typed API contracts, authenticated account client methods, factory support, and a dedicated `/api/account/me` route handler in the Next.js app. UI pages can come later without reopening the transport/auth design.

### Completion notes

- Added `ApplicationUserUpdateInput` to the shared Next.js API contracts.
- Added authenticated account client methods for current-user read and update.
- Extended the API factory so `account.getCurrentUser` and `account.updateCurrentUser` use the existing token-required flow.
- Added a Next.js BFF route at `/api/account/me` for `GET` and `PUT`.
- Added a session-only cookie refresh helper so profile updates keep the secure session cookie in sync without rewriting the auth-token cookie.
- Validation succeeded with focused Vitest coverage for the new account client, session helper, and `/api/account/me` route.

## Prompt 05 - Build the Self-Service Profile Page

Create a protected profile page in the Next.js alternate UI, such as `/me/profile`, where the signed-in user can review and edit their own account details. Start with the smallest practical editable set:

- fullname
- email
- username only if the backend can safely support rename without side effects

If username changes are risky, keep username read-only in the first pass and document that decision.

### Expected outcome

- Signed-in users have a protected `/me/profile` page for reviewing and updating their own account details.
- The first release ships a safe, minimal profile-editing surface without overreaching into risky identity changes.

### Lessons learned after completion

- The safest page shape for Prompt 05 is a server-rendered `/me/profile` route that reuses the existing author-shell pattern and falls back to the same signed-in guard used elsewhere in the protected workspace.
- Prompt 05 should keep username and admin role read-only. The backend profile slice added in Prompt 03 only supports `Email` and `Fullname`, and keeping identity-changing actions out of this page avoids token/claim churn plus role-management leakage.
- A small browser-side profile client targeting the existing Next.js BFF route at `/api/account/me` is enough for the mutation flow. That preserves the HTTP-only cookie auth model and keeps browser code away from bearer-token handling.
- `react-hook-form` plus Zod was sufficient for this slice because the edit surface is intentionally narrow. The useful extra work was normalizing backend/API errors into a concise submit summary and toast message instead of building more form infrastructure.
- `router.refresh()` after a successful save is important here because Prompt 04 refreshes the session cookie in the BFF. That keeps the server-rendered author workspace aligned with updated profile data on the next render.

### Completion notes

- Added a protected `/me/profile` page in the Next.js alternate UI and wired it into the existing author workspace navigation.
- Added a dedicated profile form with editable `fullname` and `email` fields plus read-only `username` and role display.
- Added small profile-specific client/helpers for validation, request shaping, and backend error normalization against `/api/account/me`.
- Focused validation exists for the profile client and profile schema/helpers, complementing the Prompt 04 route-handler coverage already in place for `/api/account/me`.

## Prompt 06 - Add an Admin-Only User Listing Endpoint

Add a dedicated backend endpoint for admin user management, such as `GET /api/admin/users`, with pagination. Return only the fields the admin UI needs for review and action, for example:

- applicationUserId
- username
- fullname
- email
- isAdmin
- optional counts or timestamps if inexpensive to provide

Return `403` for authenticated non-admin users.

### Expected outcome

- The backend exposes a dedicated admin-only read path for user management.
- The admin UI can load a stable list of users without overloading login/account endpoints.

### Lessons learned after completion

- Prompt 06 stayed cleaner as a dedicated admin endpoint instead of extending `/api/account/*`. That keeps privileged read behavior explicit and avoids blurring self-service account APIs with administrator workflows.
- A small summary contract is the right backend shape here. Returning `applicationUserId`, `username`, `fullname`, `email`, and `isAdmin` gives the future admin UI what it needs without reusing the login/register `ApplicationUser` shape and its token-oriented baggage.
- The existing custom Identity store was not the right abstraction for paged admin listing. A repository-backed read path plus one stored procedure was the simpler and safer addition for Prompt 06.
- Reusing the existing generic `PagedResults<T>` response shape kept pagination predictable without forcing broader model refactoring in the middle of the admin/user-management slice.
- SQL support for this prompt needs to land in both checked-in init paths. Adding the list stored procedure to the baseline schema and reconcile script keeps fresh DB bootstraps and already-persisted local databases aligned.

### Completion notes

- Added `GET /api/admin/users` as an authenticated admin-only endpoint with `page` and `pageSize` query support.
- Added `AdminUserSummary` as the lean response model for admin user review.
- Extended the account repository with a paged list method backed by the new `Account_GetAllPaged` stored procedure.
- Added `Account_GetAllPaged` to both `docker/db/init/01-schema.sql` and `docker/db/init/03-reconcile-schema.sql`.
- Validation succeeded with `dotnet build BlogLab.sln --disable-build-servers --artifacts-path tests/artifacts/.artifacts-prompt06`.

## Prompt 07 - Surface Admin User Listing in the Next.js API Layer

Extend the typed contracts, authenticated API client, and BFF route handlers in `bloglab-ui-next` so the alternate UI can fetch the admin user list through the same protected pattern already used for admin blog management.

### Expected outcome

- The Next.js alternate UI can fetch admin user data using the same secure patterns already established for admin blog review.
- Admin user-management pages stay consistent with the rest of the app's API architecture.

### Lessons learned after completion

- Prompt 07 fit best as a thin extension of the existing shared API layer: one new `AdminUserSummary` contract, one authenticated admin-user client, one factory surface, and one BFF route. No broader auth/session changes were required.
- Reusing the existing `PagedResults<T>` and paging-parameter shapes kept the admin user listing contract aligned with the admin blog flow, which will make Prompt 08 page work simpler.
- The BFF route should normalize paging inputs before forwarding them to the backend. That keeps browser-facing callers from depending on backend defaults and gives the route a small amount of defensive behavior without changing backend semantics.
- Prompt 07 does not need session-cookie mutation logic. Unlike profile updates, admin user listing is read-only, so the route handler can stay much simpler than `/api/account/me`.
- Focused coverage at the factory and route-handler layers was enough for this step. The high-value checks were authenticated endpoint targeting, token enforcement, paging forwarding, and passthrough of backend `401`/`403` error behavior.

### Completion notes

- Added `AdminUserSummary` to the shared Next.js API contracts.
- Added an authenticated admin-user API client targeting backend `GET /admin/users` with page and page-size support.
- Extended the shared API factory with `adminUser.getAll` using the same token-required flow as other privileged operations.
- Added a protected Next.js BFF route at `/api/admin/users` that forwards admin user-list requests through the authenticated server API client with normalized paging and no-store responses.
- Validation succeeded with focused Vitest coverage for the API factory and `/api/admin/users` route plus a successful `npm run build` production build in `bloglab-ui-next`.

## Prompt 08 - Build a Read-Only Admin Users Page

Create an admin-only page such as `/admin/users` in the alternate UI. Start with a read-only experience first:

- server-side admin guard
- loading and empty states
- clear access-denied behavior
- user summary cards or rows
- visual separation from normal author workspace actions

Do not add destructive mutations in this step.

### Expected outcome

- `/admin/users` exists as a protected, read-only management surface.
- Admins can review users safely before any privileged mutations are introduced.

### Lessons learned after completion

- Prompt 08 worked best as a server-rendered admin page that mirrors the existing `/admin/blogs` access pattern: signed-out users hit the admin auth guard, signed-in non-admin users get an explicit access-denied state, and admins get a read-only listing.
- The shared admin shell needed a small generalization before a second admin page could land cleanly. Adding an active-tab concept and a second admin navigation entry was enough; there was no need for a larger layout rewrite.
- A read-only first pass is easier to keep safe when the page copy makes the constraint explicit. The page now clearly signals that role changes and deletion flows are intentionally withheld until later prompts, which reduces accidental UX drift into privileged mutations.
- The backend contract for Prompt 06 is intentionally lean, so Prompt 08 summaries had to rely on current-page signals rather than timestamps or richer moderation metadata. Counts like visible admins, visible authors, named profiles, and email-domain spread were enough for a first review surface.
- A dedicated loading state matters here because admin pages are dynamic and gated. Adding `/admin/users/loading.tsx` keeps the protected workspace visually consistent with the existing admin blogs experience during data fetches.

### Completion notes

- Added a protected read-only `/admin/users` page in the Next.js alternate UI.
- Reused the shared admin shell and expanded it to support both admin blogs and admin users navigation states.
- Added summary cards, paginated user review cards, empty and out-of-range states, and explicit access-denied/auth-required handling.
- Added a dedicated admin-user page loading state plus a small summary helper with focused test coverage.
- Validation succeeded with focused Vitest coverage for the admin-user summary helper plus a successful `npm run build` production build in `bloglab-ui-next`.

## Prompt 09 - Add an Admin Role-Change Endpoint

Add the smallest safe backend mutation for role management, for example:

- `PATCH /api/admin/users/{applicationUserId}/role`

Support toggling or explicitly setting `IsAdmin`. Add guardrails so an admin cannot accidentally remove the last remaining admin account. Return the updated user summary needed by the admin UI.

### Expected outcome

- The backend supports a narrowly scoped, auditable admin-role mutation.
- Last-admin protection is enforced server-side rather than relying on UI discipline.

### Lessons learned after completion

- Prompt 09 needed a dedicated request model even though the payload is small. Using `ApplicationUserRoleUpdate` with a required nullable `IsAdmin` flag prevents accidental demotions caused by missing request fields defaulting to `false`.
- The biggest backend issue exposed by role changes was stale JWT role claims. Once admin status becomes mutable, privileged routes cannot safely rely only on `User.IsInRole(...)`; they need to verify current admin state from the database.
- Because of that, Prompt 09 was not just a new `PATCH` route. It also required hardening existing privileged backend paths so admin blog review and admin delete-any-blog behavior respect current persisted admin state immediately after a role change.
- Last-admin protection belongs in the backend mutation flow, not in the future UI. Counting current admins before a demotion keeps the guardrail authoritative regardless of which client eventually calls the endpoint.
- Returning the same lean `AdminUserSummary` shape used by Prompt 06 keeps the mutation response immediately usable by later admin UI prompts without introducing a separate mutation-only contract.

### Completion notes

- Added admin-only `PATCH /api/admin/users/{applicationUserId}/role` with explicit `IsAdmin` input and an `AdminUserSummary` response.
- Added backend last-admin protection through the new `Account_CountAdmins` repository/SQL primitive.
- Added `ApplicationUserRoleUpdate` as the minimal request model for admin role changes.
- Hardened privileged backend admin checks to use current persisted admin state for admin blog review, admin user management, and admin delete-any-blog authorization instead of trusting stale JWT role claims alone.
- Validation succeeded with `dotnet build BlogLab.sln --disable-build-servers --artifacts-path tests/artifacts/.artifacts-prompt09`.

## Prompt 10 - Wire Role Changes Through the Next.js BFF

Add the Next.js contracts, API client methods, and protected route-handler support required to call the new admin role-change endpoint. Keep the mutation behind the existing HTTP-only cookie-based auth flow and normalize error handling for `403`, validation failures, and last-admin protection.

### Expected outcome

- The admin UI can trigger role changes without bypassing the current BFF/auth model.
- Expected backend errors are surfaced predictably to the UI.

### Lessons learned after completion

- Prompt 10 fit naturally into the existing Prompt 07 admin-user surface. Extending the same `adminUser` client/factory path with `updateRole` kept listing and mutation behavior in one typed API slice instead of splitting admin-user reads and writes across separate abstractions.
- Supporting role changes required one small shared-infrastructure change: the base API client had to allow `PATCH` requests. That was the only transport-layer expansion needed for this step.
- The BFF route should validate the dynamic `applicationUserId` path segment before calling the backend. That gives predictable `400` behavior for malformed browser requests and keeps the server API client focused on valid admin operations.
- Prompt 10 does not need session-cookie refresh or broad page revalidation. Role changes affect the admin users workspace directly, so revalidating `/admin/users` is sufficient at this stage.
- Focused route-handler coverage was especially valuable here because Prompt 10 is mostly about error normalization. The important cases were token enforcement, invalid route params, successful passthrough, and backend last-admin protection errors.

### Completion notes

- Added `AdminUserRoleUpdateInput` to the shared Next.js API contracts.
- Extended the admin-user API client and shared factory with `adminUser.updateRole` targeting backend `PATCH /admin/users/{applicationUserId}/role`.
- Added a protected Next.js BFF route at `/api/admin/users/[applicationUserId]/role` that validates route params, forwards the mutation through the authenticated server API client, and revalidates `/admin/users` after success.
- Added focused Vitest coverage for the factory role-mutation path and the new dynamic BFF route, including invalid-id, unauthorized, and last-admin-protection cases.
- Validation succeeded with focused Vitest coverage plus a successful `npm run build` production build in `bloglab-ui-next`.

## Prompt 11 - Add Role Management UI to the Admin Users Page

Extend `/admin/users` with a careful admin-role management flow. Add explicit confirmation copy, loading protection, and success/error messaging. Make it visually obvious that this is a privileged action and keep the control separated from read-only user details.

### Expected outcome

- Admins can promote or demote users from `/admin/users` with clear, safe UX.
- Role-management UI is visibly separated from non-privileged account interactions.

### Lessons learned after completion

- Prompt 11 worked best as a small client-side control embedded inside an otherwise server-rendered admin page. The page can keep its authenticated data-loading path, while the privileged mutation stays isolated in a focused browser component.
- The most important correctness issue in this step was self-role changes. When an admin changes their own admin status, the BFF route needs to refresh the session cookie so the UI does not keep a stale `isAdmin` flag after the backend change succeeds.
- Role management needed its own helper layer for confirmation copy and backend-error normalization. That kept the page component from absorbing mutation-specific branching and made the button/dialog behavior easier to test directly.
- The safest UI shape is to visually separate privileged controls from profile review details. Prompt 11 keeps identity information readable while placing promotion/demotion actions in a dedicated, clearly labeled management section.
- Focused tests were most valuable at the helper and BFF route layers for this prompt. Those checks cover the high-risk cases: self-role session refresh, backend error passthrough, and confirmation/error copy shaping.

### Completion notes

- Added a dedicated admin role-management client component for `/admin/users` with confirmation dialog, loading protection, success toast, and normalized error messaging.
- Added small admin-role helpers and a browser-side role client to keep mutation copy, request handling, and error shaping isolated from the server page.
- Updated the Next.js role-change BFF route so self-role changes refresh the session cookie before revalidating `/admin/users`.
- Updated `/admin/users` to surface a clearly separated privileged role-management area on each user card while preserving the existing read-only account summary details.
- Validation succeeded with focused Vitest coverage for the admin-role helpers and role-change BFF route plus a successful `npm run build` production build in `bloglab-ui-next`.

## Prompt 12 - Design and Implement Safe User Deletion Orchestration

Implement the backend service/repository workflow required for admin deletion of a user and their related artifacts. Because the schema has foreign-key references from photos, blogs, comments, and likes back to the user, do not implement this as a single direct delete.

Design a deletion flow that safely handles dependent data in the correct order, including remote photo cleanup if needed. At minimum, account for:

- blog likes by the user
- blog comments by the user
- blogs owned by the user
- likes/comments attached to blogs being deleted if required by referential constraints
- photos owned by the user
- the user row itself

Add guardrails for self-delete and last-admin delete behavior.

### Expected outcome

- A backend deletion workflow exists that can safely remove a user and dependent artifacts in the correct order.
- The highest-risk destructive behavior is centralized and protected by guardrails.

### Lessons learned after completion

- Prompt 12 needed a real orchestration boundary rather than a controller-level delete. The clean split is service-level guardrails plus repository-level SQL cleanup: admin/self/last-admin checks live in `AdminUserDeletionService`, while ordered relational cleanup lives in `Account_DeleteWithDependencies`.
- The first pass exposed an important schema reality: because `Blog`, `BlogComment`, `BlogLike`, and `Photo` all hold foreign keys to `ApplicationUser`, a soft-delete-only approach is not enough. The final stored procedure has to delete dependent relational rows in FK-safe order before deleting the user row.
- Comment cleanup has to consider thread descendants, not just comments authored by the target user. Seeding comment deletion from both the user's authored comments and comments attached to the user's blogs, then expanding recursively through child comments, keeps the delete path from leaving broken discussion trees behind.
- Remote photo cleanup cannot share the SQL transaction. The safer tradeoff for this prompt is to commit the relational delete first, then attempt Cloudinary cleanup from the pre-fetched photo list so database state is never left half-deleted because of an external media call.
- Returning a compact `ApplicationUserDeletionResult` with deleted counts by artifact type is useful at the orchestration layer itself, because Prompt 13 can expose that response shape directly without reopening the stored procedure contract.

### Completion notes

- Added `ApplicationUserDeletionResult` plus `IAdminUserDeletionService` and `AdminUserDeletionService` as the dedicated backend orchestration layer for admin user deletion.
- Added repository support for `DeleteWithDependenciesAsync` backed by the new `Account_DeleteWithDependencies` stored procedure.
- Added self-delete and last-admin guardrails in the service before any destructive work begins.
- Implemented ordered dependent-row deletion in both `docker/db/init/01-schema.sql` and `docker/db/init/03-reconcile-schema.sql`, covering user likes, user-owned/blog-owned comment trees, user-owned blogs, photos, and finally the user row.
- Moved remote photo cleanup to run after successful relational deletion and downgraded Cloudinary cleanup failures to warning logs so the database delete path remains authoritative.
- Validation succeeded with `dotnet build BlogLab.sln --disable-build-servers --artifacts-path tests/artifacts/.artifacts-prompt12`.

## Prompt 13 - Add the Admin User-Deletion Endpoint

Expose the deletion orchestration through a dedicated admin-only backend endpoint such as `DELETE /api/admin/users/{applicationUserId}`. Return a compact response that the UI can use to confirm success and refresh the list.

### Expected outcome

- Admin user deletion is exposed through one explicit backend endpoint rather than scattered low-level operations.
- The UI has a stable contract for delete confirmations and refresh behavior.

### Lessons learned after completion

- Prompt 13 should stay thin at the route layer. The delete endpoint works best when it only extracts the authenticated caller, invokes `IAdminUserDeletionService`, and normalizes the expected `401`/`403`/`400` error cases instead of re-implementing deletion policy in the route.
- Reusing `ApplicationUserDeletionResult` as the delete response shape keeps the contract compact while still giving later UI work enough detail to confirm what was removed and refresh the list predictably.
- A destructive path like this benefits from a smoke test before any UI wiring. Creating a temporary target user plus a second interacting user was enough to verify deletion of the target user, their blog, attached comment tree, and cross-user likes without needing a full test framework first.
- The photo branch is still environment-sensitive because it depends on working Cloudinary credentials. In the current local environment, the new smoke test had to run with `-SkipPhotoUpload` after Cloudinary returned `Invalid api_key`, so relational deletion is verified live while remote-photo cleanup remains configuration-blocked at runtime here.

### Completion notes

- Added admin-only `DELETE /api/admin/users/{applicationUserId}` to `AdminUserEndpointRouteBuilderExtensions`.
- The endpoint now delegates to `IAdminUserDeletionService` and returns the compact `ApplicationUserDeletionResult` contract directly on success.
- Added focused destructive smoke coverage in `scripts/smoke-test-admin-user-delete.ps1`, which creates temporary users and dependent artifacts, deletes the target as admin, verifies cleanup, and removes the remaining helper user.
- Validation succeeded with `dotnet build BlogLab.sln --disable-build-servers --artifacts-path tests/artifacts/.artifacts-prompt13`.
- Live smoke validation succeeded against a host-run API on `http://127.0.0.1:5002` using `pwsh ./scripts/smoke-test-admin-user-delete.ps1 -BaseUrl 'http://127.0.0.1:5002' -SkipPhotoUpload`; full photo-covered runtime validation is currently blocked by invalid local Cloudinary credentials.

## Prompt 14 - Wire User Deletion Through the Next.js BFF

Add the typed contract, authenticated API client method, and protected route-handler/BFF endpoint needed for admin user deletion. Revalidate the admin user list and any relevant admin pages after success.

### Expected outcome

- The Next.js app can perform admin user deletion through the same secure mutation path used elsewhere.
- Successful deletes trigger correct page revalidation and list refreshes.

### Lessons learned after completion

- Prompt 14 fit cleanly into the existing `adminUser` API slice. Extending the shared typed contracts, authenticated client, and factory with `adminUser.remove` kept admin-user listing, role changes, and deletion in one consistent surface instead of scattering privileged user-management mutations across separate clients.
- The dynamic BFF route should validate `applicationUserId` before contacting the backend. Returning a local `400` for malformed ids keeps the server API client focused on real admin operations and gives the UI predictable failure behavior.
- Delete wiring did not need session-cookie mutation. Unlike Prompt 11 self-role changes, deleting another user only needs route-level passthrough plus `revalidatePath("/admin/users")` so the management page refreshes against current backend state.
- Prompt 14 needs explicit passthrough for backend guardrail errors. Preserving plain-text `400`/`403` responses such as self-delete and last-admin protection keeps the later UI prompt free to render precise destructive-action feedback instead of reverse-engineering generic failures.
- Focused route and factory tests were necessary but not sufficient on their own. Production-build validation exposed a contract import mistake in `admin-user-client.ts`, which was then corrected by sourcing `ApplicationUserDeletionResult` from the shared contracts module instead of the transport client module.

### Completion notes

- Added `ApplicationUserDeletionResult` to the shared Next.js API contracts for admin-user delete responses.
- Extended the authenticated admin-user API client and shared API factory with `adminUser.remove` targeting backend `DELETE /admin/users/{applicationUserId}`.
- Added a protected Next.js BFF route at `/api/admin/users/[applicationUserId]` that validates route params, forwards delete requests through the authenticated server API client, returns `no-store` responses, and revalidates `/admin/users` after success.
- Added focused Vitest coverage for the delete route and shared factory wiring, including success, invalid-id, unauthorized, and backend guardrail error cases.
- Validation succeeded with `npm run test -- src/app/api/admin/users/[applicationUserId]/route.test.ts src/lib/api/factory.test.ts` and `npm run build` in `bloglab-ui-next` after fixing the shared-contract import for the delete client.

## Prompt 15 - Add User Deletion UX to the Admin Users Page

Extend `/admin/users` with a high-friction delete flow only after the backend orchestration exists. Use strong confirmation copy that makes it clear the action removes the user and their related artifacts. Add loading states, success/error toasts, and clear handling for protected cases such as last-admin deletion.

### Expected outcome

- `/admin/users` supports a deliberate, high-friction delete flow for administrators.
- Destructive behavior is obvious, guarded, and consistent with backend protections.

### Lessons learned after completion

- Prompt 15 worked best as a focused client component inside the existing server-rendered admin users page. The page can stay responsible for authenticated data loading, while the destructive mutation lives in an isolated button/dialog flow with its own pending state and toast handling.
- A typed-confirmation requirement is enough friction for this MVP when the confirmation token is the target username and the dialog spells out the dependent-artifact cleanup. That makes the destructive scope obvious without introducing a heavier multi-step wizard.
- Delete UX needed its own helper layer for copy shaping and backend-error normalization. Keeping that logic in `admin-delete.ts` and `admin-delete-client.ts` prevents the page component from absorbing destructive-action branching and makes protected-case messages such as self-delete and last-admin failures easier to keep consistent.
- The safest UI behavior is to block obviously invalid cases before the request is sent while still relying on backend guardrails as the authority. In this prompt, self-delete stays disabled in the UI, and backend `400`/`403` responses still flow through to the toast path for protected cases that only the server can decide conclusively.
- Prompt 15 did not need bespoke page invalidation logic in the browser. A success toast plus `router.refresh()` is sufficient because Prompt 14 already revalidates `/admin/users` in the BFF route after a successful delete.

### Completion notes

- Added `AdminUserDeleteButton` as a high-friction delete control with a destructive confirmation dialog, typed username confirmation, pending state, and success/error toast handling.
- Added `admin-delete.ts` and `admin-delete-client.ts` to isolate delete copy, backend error normalization, and the browser-side call to the existing `/api/admin/users/[applicationUserId]` BFF route.
- Updated `/admin/users` to present the delete action in a clearly separated destructive section on each user card, alongside explicit copy about dependent-artifact cleanup and backend protections.
- The current account cannot be deleted from this UI path; the delete control stays disabled for the signed-in admin while the backend remains authoritative for self-delete and last-admin protection.
- Validation succeeded with `npm run test -- src/lib/users/admin-delete.test.ts src/app/api/admin/users/[applicationUserId]/route.test.ts src/lib/api/factory.test.ts` and `npm run build` in `bloglab-ui-next`.

## Prompt 16 - Add Targeted Tests for Account and Admin User Management

Add focused tests around the highest-risk behavior:

- current-user profile read/update
- admin-only access to user-list endpoints
- admin role changes
- last-admin protection
- user deletion orchestration
- Next.js session and route-guard behavior for `/me/profile` and `/admin/users`

Prefer narrow, deterministic coverage first.

### Expected outcome

- The highest-risk backend and UI behaviors have focused automated coverage.
- Regressions around auth, role protection, and destructive mutations become easier to catch early.

### Lessons learned after completion

- Prompt 16 was most effective when it extended the test seams that already existed instead of introducing a full new integration harness. The Next.js route-handler tests already covered profile/account and admin-user mutations well, so the main gaps were server-page guard behavior and backend deletion-service guardrails.
- The backend did not yet have a reusable web-host test setup, but `AdminUserDeletionService` was already a strong seam for high-risk coverage. A small `BlogLab.Services.Tests` project was enough to lock down admin authorization, self-delete protection, last-admin protection, and the post-delete remote-photo cleanup loop.
- Server-rendered Next.js pages can be tested narrowly with `renderToStaticMarkup` and mocked client components. That kept Prompt 16 focused on route-guard and protected-page behavior for `/me/profile` and `/admin/users` without pulling in a browser-oriented component test framework.
- Existing route-handler tests remain the main automated coverage for current-user profile read/update, admin-only user-list access, role changes, and last-admin error passthrough. Prompt 16 complements those tests rather than replacing them.
- The highest remaining runtime-sensitive branch is still remote Cloudinary cleanup during user deletion. Automated backend tests now cover the orchestration contract and photo-public-id filtering, while full end-to-end media cleanup still depends on valid local Cloudinary credentials.

### Completion notes

- Added `BlogLab.Services.Tests` with focused `AdminUserDeletionService` coverage for unauthorized delete attempts, self-delete protection, last-admin protection, and successful dependency cleanup plus remote-photo deletion filtering.
- Added Next.js server-page tests for `/me/profile` and `/admin/users`, covering auth-guard behavior plus successful protected rendering for signed-in users/admins.
- Kept the existing focused Next.js route-handler and helper tests as the primary automated coverage for `/api/account/me`, `/api/admin/users`, role changes, and delete passthrough behavior.
- Validation succeeded with `dotnet test .\BlogLab.Services.Tests\BlogLab.Services.Tests.csproj --disable-build-servers --artifacts-path tests/artifacts/.artifacts-tests-prompt16` and the focused Next.js Vitest suite plus `npm run build` in `bloglab-ui-next`.

## Prompt 17 - Update Documentation and Local Admin Workflow Notes

Update the repository docs with the minimum guidance needed to run and verify the new profile and admin user-management features locally. Include:

- how to sign in as an admin
- how to reach `/admin/users` and `/me/profile`
- any new environment variables or SQL/bootstrap assumptions
- known limitations in the first release, such as username-edit restrictions if they remain out of scope

### Expected outcome

- Local verification steps for profile and admin user management are documented.
- Future contributors can run, test, and reason about the feature without reverse-engineering the implementation.

### Lessons learned after completion

- Prompt 17 needed updates in contributor-facing operational docs, not just in the prompt tracker. The highest-value places were `docs/docker-local-development.md` for full-stack workflows and `bloglab-ui-next/README.md` for the alternate UI’s route surface and focused test commands.
- Local admin guidance is clearer when it starts from the seeded default admin account and then explains the manual promotion fallback. That avoids unnecessary SQL edits for the common local path while still documenting how persisted environments can recover.
- Contributor docs need to separate the self-service and admin surfaces explicitly: `/me/profile` is user-scoped, while `/admin/users` and `/admin/blogs` are privileged workspaces with different risks and verification steps.
- The first-release limitations are important operational knowledge, not just planning notes. Username edits remaining read-only, deferred password/email flows, and Cloudinary-dependent photo cleanup verification all belong in the local workflow docs so later contributors do not infer missing behavior as regressions.

### Completion notes

- Updated `docs/docker-local-development.md` with admin/profile route guidance, a local verification checklist, focused automated test commands, and current MVP limitations.
- Updated `bloglab-ui-next/README.md` with the `/me/profile` and `/admin/users` surfaces, seeded-admin guidance, destructive delete behavior notes, and focused verification commands.
- Kept the prompt tracker aligned with the actual repository docs so Prompt 17 now records the contributor-facing documentation outcome rather than only implementation history.

## Recommended Stop Points

Safe review checkpoints:

1. after Prompt 03, when backend self-service profile APIs exist
2. after Prompt 08, when `/admin/users` is read-only but working
3. after Prompt 11, when role management is working but delete is not yet enabled
4. after Prompt 15, when the full admin user-management MVP is complete

## Go/No-Go Guidance

Proceed now if the goal is a practical MVP for admin and profile management.

Defer if you require, in the same slice:

- password reset flows
- audit logging
- bulk moderation tools
- admin editing of arbitrary user-owned content
- soft-delete/recovery workflows

Those are reasonable follow-ons, but they should not be bundled into the first implementation.