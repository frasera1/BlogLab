# BlogLab User Manual

## Purpose

This manual explains how to use the current BlogLab application from a user perspective.

It focuses on the active Next.js experience in `bloglab-ui-next`, because that is where the latest profile and admin-user-management features are available.

For local development, the main user-facing URLs are:

- Next.js UI: `http://localhost:3001` when running in Docker, or `http://localhost:3000` when running on the host
- API: `http://localhost:5000`
- Legacy Angular UI: `http://localhost:4200`

The Angular UI is still available locally, but the newest account and admin flows described here are part of the Next.js UI.

## Access Levels

BlogLab currently has three practical access levels:

- Public visitor: can browse published content without signing in
- Signed-in author: can manage their own posts, media, and profile
- Administrator: can access admin blog review and admin user management tools

## Getting Started

### Open the application

1. Start the local stack if it is not already running.
2. Open the Next.js UI at `http://localhost:3001` for Docker or `http://localhost:3000` for a host-run UI.
3. Confirm the browser tab shows the BlogLab favicon.
4. Land on the homepage and use the shared public header to move into public, author, or admin areas.

### Understand the shared public shell

The public-facing routes now share a consistent site shell.

On public pages such as `/`, `/blogs`, and `/blogs/[blogId]`, expect to see:

- a sticky header with the BlogLab logo
- primary public navigation for `Home` and `Blogs`
- authentication actions in the header
- a shared footer with public and session-aware recovery links

The footer is intentionally lighter than the header. It helps you orient yourself without duplicating the full set of account actions.

### Use the theme toggle

The Next.js UI includes a light/dark theme toggle in the public header.

- on desktop, it appears in the header utility area
- on mobile, it appears inside the expanded menu panel

Your theme choice is remembered locally in the browser.

### Create an account

1. Open the homepage.
2. Use the existing authentication flow to register a new account.
3. Sign in with the username and password you created.

Normal registration creates a non-admin account.

### Sign in as a local admin

For local development only, the Docker database seed creates a default administrator account:

- Username: `adminlab`
- Password: `Admin12345!`

Use this account when you need to test the admin workspaces.

## Public Browsing

### View the homepage

The homepage introduces the application and now sits inside the shared public shell.

From the homepage you can:

- use the header logo to return to `/`
- open the public blog feed from the header or page calls to action
- sign in or register without leaving the page
- move into your writing workspace after authentication

### Browse blogs

1. Open `/blogs`.
2. Review the paginated list of published blog posts.
3. Open any post to view its full content.

### Read a blog post

1. Open `/blogs/[blogId]` by selecting a post from the public feed.
2. Read the full article.
3. Review the associated comments on the same page.

Depending on the current UI state and whether you are signed in, interactive actions such as commenting or liking may require authentication.

### Use the public header and footer

Across public routes, the shared chrome behaves as follows:

- signed-out users see the BlogLab logo, `Home`, `Blogs`, and `Login` and `Register` actions
- signed-in authors see workspace shortcuts for `My posts`, `My media`, and `Profile`
- signed-in admins also see `Admin users` and `Admin blogs`
- the footer always keeps `Explore` links visible and only expands `Workspace` and `Admin` sections when your session allows them

This keeps public browsing simple while still giving signed-in users a fast route back to their work.

### Use the mobile menu

On smaller screens, the public header collapses into a compact layout.

Expected mobile behavior:

- the BlogLab logo remains visible
- the menu button opens the main navigation panel
- `Home` and `Blogs` appear at the top of the panel
- workspace and admin links appear inside the panel only when you are signed in
- logout remains separated from the navigation links

If the menu is open, page scrolling is intentionally locked until you close it.

## Signed-In Author Features

After signing in with a normal account, you gain access to the protected author workspace.

### Manage your posts

Open `/me/posts` to work with your own blog content.

Typical tasks in this area include:

- reviewing your existing posts
- creating a new post
- editing your own post content
- deleting your own post when appropriate

The author workspace is intentionally scoped to your own content. It is not an admin moderation surface.

### Manage your media

Open `/me/media` to work with your uploaded media assets.

Typical tasks in this area include:

- uploading a photo
- reviewing previously uploaded photos
- removing unused photos

Photo operations depend on the current backend media configuration. In local environments, remote image cleanup may depend on valid Cloudinary credentials.

### Manage your profile

Open `/me/profile` to review and update your current account details.

The current profile page supports:

- updating your `fullname`
- updating your `email`
- viewing your current `username`
- viewing whether your account is an `Author` or `Admin`

Current profile limitations:

- username is read-only
- password reset is not part of this flow
- role changes are not available from self-service profile settings

## Administrator Features

Administrators have access to separate admin workspaces. These are intentionally distinct from the normal author pages.

### Review blogs as an admin

Open `/admin/blogs`.

This area is intended for cross-user blog oversight. Administrators can:

- review blog entries across users
- inspect paginated results
- perform admin-only blog moderation actions supported by the current UI

### Manage users as an admin

Open `/admin/users`.

This area is intended for user administration and currently supports:

- viewing paginated user summaries
- identifying whether a user currently has admin access
- promoting a user to admin
- demoting an admin user when allowed
- deleting a user through a protected, high-friction workflow

### Change a user role

1. Open `/admin/users`.
2. Locate the target user.
3. Use the role-management control in the privileged management section.
4. Confirm the role change when prompted.

Important behavior:

- role changes are admin-only
- backend protections prevent removal of the last remaining admin
- if an admin changes their own role, session state is refreshed to reflect the change

### Delete a user

1. Open `/admin/users`.
2. Locate the target user card.
3. Start the delete action from the destructive section.
4. Read the warning text carefully.
5. Type the target username exactly to confirm deletion.
6. Submit the delete request.

Important behavior:

- self-delete is blocked
- the delete workflow is permanent
- backend cleanup removes the user and related dependent artifacts
- backend protections still apply even if the UI allows you to open the dialog

Artifacts included in the delete workflow can include user-owned blogs, comments, likes, and photo records.

## Common Navigation Map

Use these routes as the primary map for the current Next.js UI:

- `/` — homepage
- `/blogs` — public blog feed
- `/blogs/[blogId]` — blog detail page
- `/me/posts` — signed-in author post management
- `/me/media` — signed-in author media management
- `/me/profile` — signed-in profile management
- `/admin/blogs` — admin blog workspace
- `/admin/users` — admin user workspace

The shared public shell applies to `/`, `/blogs`, and `/blogs/[blogId]`.

The author and admin workspaces keep their own focused shells and do not reuse the public header and footer.

## Known Limitations

The current MVP intentionally leaves some features out of scope:

- username editing
- password reset
- email verification
- audit logging
- soft-delete and restore workflows
- bulk moderation tools
- admin editing of arbitrary user-owned content beyond the current role/delete flows

These omissions are expected and should not be treated as defects in the current release unless the product scope changes.

## Troubleshooting

### I do not see the expected logo, header, or footer on public pages

Make sure you are using the Next.js UI rather than the legacy Angular UI. The shared public shell is part of `bloglab-ui-next`.

### The mobile menu or theme toggle does not appear where I expect

On desktop, the theme toggle is in the header utility area. On smaller screens, it moves into the expanded mobile menu panel.

### The browser tab icon did not update

Refresh the page fully. If the browser still shows an old icon, clear the tab or browser cache and reopen the Next.js UI.

### I can browse the site but cannot open `/me/*`

You are probably not signed in. Sign in first, then return to the protected author route.

### I can sign in but cannot open `/admin/*`

Your account does not currently have admin access. Use the seeded `adminlab` account locally or promote a user in the database for local testing.

### I changed admin status manually in the database and the UI still shows the old role

Sign out and sign back in so a fresh JWT and session cookie are issued.

### Photo deletion behavior is incomplete in local testing

Remote media cleanup depends on valid Cloudinary credentials. Database cleanup can still succeed even if external media verification is unavailable locally.

## Related Docs

- `docs/docker-local-development.md` for setup and local workflow details
- `bloglab-ui-next/README.md` for alternate UI development notes
- `docs/admin-user-and-profile-management-prompts.md` for implementation tracking and scope decisions
