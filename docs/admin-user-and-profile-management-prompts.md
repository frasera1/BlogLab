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
- Validation succeeded with `dotnet build BlogLab.sln --disable-build-servers --artifacts-path .artifacts-prompt02`.

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
- Validation succeeded with `dotnet build BlogLab.sln --disable-build-servers --artifacts-path .artifacts-prompt03`.

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

## Prompt 07 - Surface Admin User Listing in the Next.js API Layer

Extend the typed contracts, authenticated API client, and BFF route handlers in `bloglab-ui-next` so the alternate UI can fetch the admin user list through the same protected pattern already used for admin blog management.

### Expected outcome

- The Next.js alternate UI can fetch admin user data using the same secure patterns already established for admin blog review.
- Admin user-management pages stay consistent with the rest of the app's API architecture.

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

## Prompt 09 - Add an Admin Role-Change Endpoint

Add the smallest safe backend mutation for role management, for example:

- `PATCH /api/admin/users/{applicationUserId}/role`

Support toggling or explicitly setting `IsAdmin`. Add guardrails so an admin cannot accidentally remove the last remaining admin account. Return the updated user summary needed by the admin UI.

### Expected outcome

- The backend supports a narrowly scoped, auditable admin-role mutation.
- Last-admin protection is enforced server-side rather than relying on UI discipline.

## Prompt 10 - Wire Role Changes Through the Next.js BFF

Add the Next.js contracts, API client methods, and protected route-handler support required to call the new admin role-change endpoint. Keep the mutation behind the existing HTTP-only cookie-based auth flow and normalize error handling for `403`, validation failures, and last-admin protection.

### Expected outcome

- The admin UI can trigger role changes without bypassing the current BFF/auth model.
- Expected backend errors are surfaced predictably to the UI.

## Prompt 11 - Add Role Management UI to the Admin Users Page

Extend `/admin/users` with a careful admin-role management flow. Add explicit confirmation copy, loading protection, and success/error messaging. Make it visually obvious that this is a privileged action and keep the control separated from read-only user details.

### Expected outcome

- Admins can promote or demote users from `/admin/users` with clear, safe UX.
- Role-management UI is visibly separated from non-privileged account interactions.

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

## Prompt 13 - Add the Admin User-Deletion Endpoint

Expose the deletion orchestration through a dedicated admin-only backend endpoint such as `DELETE /api/admin/users/{applicationUserId}`. Return a compact response that the UI can use to confirm success and refresh the list.

### Expected outcome

- Admin user deletion is exposed through one explicit backend endpoint rather than scattered low-level operations.
- The UI has a stable contract for delete confirmations and refresh behavior.

## Prompt 14 - Wire User Deletion Through the Next.js BFF

Add the typed contract, authenticated API client method, and protected route-handler/BFF endpoint needed for admin user deletion. Revalidate the admin user list and any relevant admin pages after success.

### Expected outcome

- The Next.js app can perform admin user deletion through the same secure mutation path used elsewhere.
- Successful deletes trigger correct page revalidation and list refreshes.

## Prompt 15 - Add User Deletion UX to the Admin Users Page

Extend `/admin/users` with a high-friction delete flow only after the backend orchestration exists. Use strong confirmation copy that makes it clear the action removes the user and their related artifacts. Add loading states, success/error toasts, and clear handling for protected cases such as last-admin deletion.

### Expected outcome

- `/admin/users` supports a deliberate, high-friction delete flow for administrators.
- Destructive behavior is obvious, guarded, and consistent with backend protections.

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

## Prompt 17 - Update Documentation and Local Admin Workflow Notes

Update the repository docs with the minimum guidance needed to run and verify the new profile and admin user-management features locally. Include:

- how to sign in as an admin
- how to reach `/admin/users` and `/me/profile`
- any new environment variables or SQL/bootstrap assumptions
- known limitations in the first release, such as username-edit restrictions if they remain out of scope

### Expected outcome

- Local verification steps for profile and admin user management are documented.
- Future contributors can run, test, and reason about the feature without reverse-engineering the implementation.

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