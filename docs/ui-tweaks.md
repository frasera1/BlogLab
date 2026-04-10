# BlogLab UI Tweaks Plan

## Request summary

The requested `bloglab-ui-next` layout work is:

- create a header area with `bloglab-logo.png`, navbar, and login/register/logout controls
- create a footer with nav links and copyright text
- use a layout page where it helps enforce a site-wide consistent look and feel
- make the site mobile friendly

This document is intentionally planning-only. It is the implementation brief to use before writing any UI code.

## Current app state

Relevant files and facts from the current codebase:

- `bloglab-ui-next/public/bloglab-logo.png` already exists and can be used directly.
- `bloglab-ui-next/src/app/layout.tsx` currently only applies fonts, theme bootstrapping, `ThemeProvider`, and `ToastProvider`.
- `bloglab-ui-next/src/app/page.tsx` renders the homepage through `AuthShell`.
- `bloglab-ui-next/src/components/auth/auth-shell.tsx` already contains working login/register/logout behavior and current-session UI that can likely be reused rather than rebuilt.
- public routes such as `/` and `/blogs` currently render their own top sections instead of sharing a site-wide header/footer shell.
- protected routes such as `/me/*` and `/admin/*` already use dedicated workspace shells, so any shared site chrome needs to avoid creating awkward double-navigation.

## Design constraints

- Keep the existing editorial visual language already used in `bloglab-ui-next`.
- Reuse existing auth/session plumbing instead of introducing a second auth flow.
- Prefer a shared shell for public-facing routes first.
- Avoid forcing admin and author workspace pages into a header/footer structure that conflicts with their current focused layouts.
- Treat responsive behavior as part of the initial implementation, not as a later polish pass.

## Recommended implementation approach

The cleanest path is to introduce a reusable public site shell that handles:

- logo placement
- primary navigation
- auth actions
- footer links
- mobile navigation behavior

Use a public-only route group for this shell rather than putting the site header and footer directly in `src/app/layout.tsx`.

Recommended structure:

- keep `src/app/layout.tsx` limited to global providers, fonts, theme bootstrapping, and document-level metadata
- add a public route group layout for browse-oriented pages such as `/`, `/blogs`, and `/blogs/[blogId]`
- keep `/me/*` and `/admin/*` on their dedicated workspace shells for now

Chosen route-group naming for implementation:

- use `src/app/(public)/...` for the browse-oriented shell
- keep URL paths unchanged by relying on Next.js route groups rather than path renames

Why this is the preferred plan:

- it avoids forcing author and admin workspaces into a second navigation system
- it keeps the root layout stable and low-risk
- it makes the public browsing experience consistent without reopening protected workspace architecture
- it gives a clean expansion path later if additional public marketing or discovery routes are added

Opinionated decision for this plan:

- do not put the shared site header/footer in the root layout for the first implementation pass
- implement the new chrome in a public-only route group first
- treat any reuse inside `/me/*` or `/admin/*` as a separate follow-up decision, not part of the initial shell rollout

## Refined link strategy

The header and footer should not expose the same navigation density.

Recommended rule of thumb:

- header = primary wayfinding plus session-aware utility actions
- footer = lightweight orientation and recovery links
- author/admin workspace links should appear in the header only when the session makes them relevant
- footer should stay simpler than the header so it does not become a second overloaded control surface

### Header link model

Split the header into three zones:

- brand zone: BlogLab logo linking to `/`
- primary nav zone: stable route links for browsing
- utility/action zone: auth actions, theme toggle, and session-aware workspace shortcuts

Recommended primary nav links:

- Home -> `/`
- Blogs -> `/blogs`

Recommended utility/action links for signed-out users:

- Login -> opens existing auth dialog
- Register -> opens existing auth dialog

Recommended utility/action links for signed-in non-admin users:

- My posts -> `/me/posts`
- My media -> `/me/media`
- Profile -> `/me/profile`
- Logout -> existing logout action

Recommended utility/action links for signed-in admins:

- My posts -> `/me/posts`
- My media -> `/me/media`
- Profile -> `/me/profile`
- Admin users -> `/admin/users`
- Admin blogs -> `/admin/blogs`
- Logout -> existing logout action

Recommended priority order when horizontal space is tight:

- keep logo always visible
- keep Home and Blogs visible as the stable primary nav
- move workspace and admin links into the utility area or mobile menu first
- keep logout available but do not let it displace the primary public nav on small screens

### Footer link model

The footer should favor stable, low-noise links and avoid mirroring the entire header.

Recommended footer sections for first pass:

- Explore
- Workspace
- Admin

Recommended footer links:

- Explore section: Home -> `/`, Blogs -> `/blogs`
- Workspace section when signed in: My posts -> `/me/posts`, My media -> `/me/media`, Profile -> `/me/profile`
- Admin section only when signed in as admin: Admin users -> `/admin/users`, Admin blogs -> `/admin/blogs`

Recommended footer fallback when signed out:

- keep only the Explore section visible
- use a short auth callout line near the copyright area instead of repeating Login and Register as full footer nav items

### Mobile behavior guidance for links

For the first implementation pass:

- show logo + menu trigger + highest-priority auth action in the collapsed header
- place all workspace and admin links inside the mobile menu panel
- keep Home and Blogs at the top of the mobile menu
- keep logout separated from navigational links so destructive session-ending behavior is not mixed into wayfinding

### What to avoid

- do not place `/admin/*` links in the primary public nav for all users
- do not duplicate the full author/admin workspace tab structure inside the shared public header
- do not make the footer more feature-dense than the header
- do not rely on wrapped multi-line desktop nav as the mobile strategy

## Small-prompt implementation plan

Use the following prompts in order. Each one is intentionally narrow and should be completed and reviewed before moving to the next.

### Prompt 01 - Create the public route-group shell strategy

Implement the shell architecture using a public-only route group instead of the root layout.

Deliverable:

- keep `src/app/layout.tsx` provider-only
- add `src/app/(public)/layout.tsx` to wrap `/`, `/blogs`, and `/blogs/[blogId]`
- move the homepage and public blog routes into that route group without changing their URLs
- document the route-group decision in code comments or PR notes

Success criteria:

- public pages gain a consistent shell path
- author/admin workspace pages do not end up with duplicated nav bars or visually noisy stacked headers
- the chosen structure makes it obvious that public browsing and protected workspaces are intentionally different shells

### Prompt 02 - Extract reusable auth actions for site chrome

Refactor the existing homepage auth controls in `src/components/auth/auth-shell.tsx` into a reusable header-friendly component or components.

Deliverable:

- reusable login/register/logout controls that can render inside a shared header
- reuse existing `authClient`, session state, and `AuthDialog` behavior instead of creating a new auth mechanism

Success criteria:

- sign-in, registration, and sign-out continue to work
- the homepage no longer owns the only copy of auth-entry UI logic

### Prompt 03 - Build the shared site header

Create a shared header component for the public site.

Required content:

- BlogLab logo from `public/bloglab-logo.png`
- primary nav links
- login/register/logout controls
- optional theme toggle if it still fits the header cleanly

Recommended nav set for first pass:

- primary nav: Home, Blogs
- signed-in utility links: My posts, My media, Profile
- admin-only utility links: Admin users, Admin blogs
- signed-out actions: Login, Register
- signed-in action: Logout

Success criteria:

- the logo is visible and sized appropriately on desktop and mobile
- navigation reflects auth state cleanly
- signed-in and signed-out header states are both intentional, not improvised

### Prompt 04 - Add responsive mobile navigation behavior

Extend the shared header with a mobile-friendly nav pattern.

Deliverable:

- collapsed mobile navigation with clear open/close behavior
- touch-friendly spacing for nav items and auth buttons
- no overflow or cramped wrapping at narrow widths

Recommended first-pass behavior:

- use a simple menu button and panel or drawer pattern
- keep logo visible while collapsed
- keep login/register/logout reachable without requiring desktop width

Success criteria:

- layout remains usable around common small-screen widths
- nav links do not overlap the logo or action controls
- auth actions remain obvious on mobile

### Prompt 05 - Build the shared footer

Create a footer component for the public site shell.

Required content:

- nav links
- copyright line

Recommended footer links for first pass:

- Explore: Home, Blogs
- Workspace when signed in: My posts, My media, Profile
- Admin when signed in as admin: Admin users, Admin blogs
- signed-out state: keep footer nav minimal and avoid duplicating full auth actions as main footer links

Success criteria:

- footer feels consistent with the editorial design language
- link groups stack cleanly on mobile
- spacing works on both long and short pages

### Prompt 06 - Apply the public route-group shell to browse pages

Integrate the shared header and footer through the new public route-group layout.

Deliverable:

- public-facing pages such as `/`, `/blogs`, and `/blogs/[blogId]` render inside the new shell
- existing page-specific hero and content sections still read well beneath the shared header

Success criteria:

- pages have a consistent top and bottom frame
- the homepage no longer needs to fake a site header inside its own content block
- route transitions keep a stable look and feel

### Prompt 07 - Reconcile author/admin workspace behavior

Review `/me/*` and `/admin/*` after the public shell is introduced and confirm that they should:

- keep their current focused workspace shells untouched
- not inherit the public header/footer in this pass
- optionally add a lightweight link back to public browsing only if it improves usability without duplicating workspace nav

Success criteria:

- no duplicated navigation layers
- admin and author pages still feel purpose-built for work, not just browsing

### Prompt 08 - Mobile and responsive pass

Run a focused responsive review across key routes.

Target pages:

- `/`
- `/blogs`
- `/blogs/[blogId]`
- `/me/profile`
- `/admin/users`

Review checklist:

- header wraps or collapses correctly
- footer stacks cleanly
- hero sections do not feel crowded under the new header
- action buttons remain reachable and readable
- typography and spacing still feel deliberate on smaller screens

### Prompt 09 - Validation and regression coverage

Add or update focused tests where the new shell changes behavior materially.

Likely areas:

- server-rendered layout output for public pages
- auth-state rendering in the header
- mobile menu interaction if implemented as a client component

Manual verification checklist:

- signed-out user sees logo, public nav, and login/register
- signed-in user sees logout and relevant workspace links
- admin user sees admin links only when allowed
- footer renders across public pages
- mobile widths remain usable

## Open implementation decisions

These should be resolved before code starts or in Prompt 01:

- whether the theme toggle stays in the header, moves into a menu, or remains page-local
- whether public header auth actions should open the existing dialog everywhere or route to dedicated auth pages later
- whether the footer should show signed-in workspace sections inline or collapse them into a compact account summary block

## Suggested first code target files

If the plan is approved, the most likely files touched first are:

- `bloglab-ui-next/src/app/layout.tsx`
- `bloglab-ui-next/src/app/(public)/layout.tsx`
- `bloglab-ui-next/src/app/(public)/page.tsx`
- `bloglab-ui-next/src/components/auth/auth-shell.tsx`
- new shared shell components under `bloglab-ui-next/src/components/`
- `bloglab-ui-next/src/app/(public)/blogs/page.tsx`
- `bloglab-ui-next/src/app/(public)/blogs/[blogId]/page.tsx`

## Non-goals for this pass

To keep the work small and reviewable, this pass should not include:

- a full redesign of the author/admin workspaces
- auth backend changes
- new account flows beyond reusing existing login/register/logout behavior
- unrelated typography or theming rewrites outside what is needed for the shared shell and responsive polish
