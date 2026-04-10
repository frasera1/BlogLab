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

Documentation rule for the full sequence:

- after each prompt is completed, record a short `Lessons learned after completion` section before starting the next prompt
- keep those lessons concrete and implementation-specific so later prompts build on verified decisions rather than assumptions

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

### Prompt 02 lessons learned after completion

- A public-only route group was the cleaner first move than changing the root layout because it preserved the existing provider setup while creating a clear place for shared browse-page chrome.
- Using `src/app/(public)/...` keeps public URLs unchanged and makes the shell boundary explicit in the file system, which lowers the risk of accidental coupling with `/me/*` and `/admin/*`.
- Adding a minimal `src/app/(public)/layout.tsx` now is useful even before header/footer code exists because it establishes the architectural seam Prompt 02 and Prompt 03 will build on.
- The author and admin areas already have strong local shells, so keeping them out of the new route group avoids duplicated navigation and keeps Prompt 01 intentionally low-risk.

### Prompt 02 completion notes

- Moved `/`, `/blogs`, and `/blogs/[blogId]` into `src/app/(public)/...` without changing route URLs.
- Added `src/app/(public)/layout.tsx` as the public-shell boundary while keeping `src/app/layout.tsx` provider-only.
- Updated this plan to record `(public)` as the chosen route-group naming convention.
- Verified the reorganization with `npm run build` in `bloglab-ui-next`.

### Prompt 02 - Extract reusable auth actions for site chrome

Refactor the existing homepage auth controls in `src/components/auth/auth-shell.tsx` into a reusable header-friendly component or components.

Deliverable:

- reusable login/register/logout controls that can render inside a shared header
- reuse existing `authClient`, session state, and `AuthDialog` behavior instead of creating a new auth mechanism

Success criteria:

- sign-in, registration, and sign-out continue to work
- the homepage no longer owns the only copy of auth-entry UI logic

### Lessons learned after completion

- The safest Prompt 02 split was to extract both a reusable control component and a shared client hook. The control component alone was not enough because homepage CTA buttons outside the header still need to open the same auth dialog state.
- Keeping `AuthDialog` owned by the page-level shell while moving login/register/logout rendering into a reusable `SiteAuthControls` component preserved flexibility for later header work without hiding dialog state inside the control component.
- A small pure helper layer for site-chrome auth concerns was useful. `getSiteWorkspaceLinks` and `getSiteDisplayName` now give the future shared header a stable source of truth for auth-aware labels and shortcuts, and they were easy to validate with focused Vitest coverage.
- After the earlier route-group move, Next.js build validation needed a clean `.next` directory because stale generated validator output under `.next/dev` can survive structural route changes and produce misleading type errors unrelated to current source files.

### Completion notes

- Added reusable site-chrome auth helpers in `src/lib/auth/site-chrome.ts` plus focused tests in `src/lib/auth/site-chrome.test.ts`.
- Added `SiteAuthControls` as the reusable header-friendly auth control component and `useSiteAuthSession` as the shared client hook for dialog/session/logout state.
- Refactored the homepage `AuthShell` to use the extracted auth helpers, hook, and reusable control component while keeping homepage CTA buttons connected to the same auth dialog flow.
- Validation succeeded with `npm run test -- src/lib/auth/site-chrome.test.ts` and `npm run build` in `bloglab-ui-next` after clearing stale `.next` output generated before the route-group restructure.

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

### Prompt 03 lessons learned after completion

- The header needed to own `AuthDialog` directly rather than relying on `SiteAuthControls` to do it, because Prompt 02 intentionally moved the dialog/session state into shared page-or-shell-level ownership. That kept the extracted controls reusable while still making the standalone header fully functional.
- A small shared navigation definition in `src/lib/site/navigation.ts` was worth adding early. It gives Prompt 04 and Prompt 05 a single source of truth for the stable public nav instead of duplicating `Home` and `Blogs` link decisions in multiple components.
- Building the desktop-capable header before the mobile menu pass kept Prompt 03 focused. The current header already stacks and wraps responsibly, while Prompt 04 can now concentrate specifically on collapsed mobile behavior instead of also inventing the visual language.
- The strongest low-risk boundary for this prompt was to implement the header component without attaching it to the public layout yet. That let the component and its auth behavior validate cleanly before any browse-page rollout changes land in Prompt 06.

### Prompt 03 completion notes

- Added shared public navigation definitions in `src/lib/site/navigation.ts`.
- Added `src/components/site/public-site-header.tsx` with the BlogLab logo, primary public nav, auth-aware utility controls, and theme toggle.
- Wired the shared header component to the extracted auth/session hook plus `AuthDialog`, so login/register/logout flows remain functional inside the header itself.
- Validation succeeded with `npm run build` in `bloglab-ui-next`.

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

### Prompt 04 lessons learned after completion

- The mobile header needed a more compact brand treatment than desktop. Keeping the logo visible while hiding the tagline on the smallest widths was the simplest way to protect space for the menu trigger and the highest-priority auth action.
- Prompt 04 worked best as a lightweight menu-panel pattern inside the existing header component instead of introducing a full drawer dependency. The existing editorial card styling already gave the panel enough visual separation for a first pass.
- Locking page scroll while the mobile menu is open matters for usability on long public pages. Without that, the sticky header and expanded menu can feel unstable during touch scrolling.
- Reusing the same public and workspace link sources inside the mobile menu keeps the responsive state aligned with desktop behavior and avoids a second navigation definition drifting later.

### Prompt 04 completion notes

- Extended `PublicSiteHeader` with a collapsed mobile menu that exposes public navigation, session-aware workspace links, theme toggle access, and login/register/logout actions.
- Added mobile-specific brand compaction so the logo stays visible without crowding the header controls on narrow widths.
- Added page-scroll locking while the mobile menu is open so the panel behaves predictably on long pages.
- Validation succeeded with `npm run build` in `bloglab-ui-next`.

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

### Prompt 05 lessons learned after completion

- The footer worked best as a public-shell component that stays lighter than the header. Explore links are always visible, while workspace and admin sections only expand when the session actually makes them relevant.
- Signed-out footer behavior is more usable when it avoids duplicating login and register buttons. Keeping auth entry in the header preserves a single obvious action path on mobile instead of turning the footer into a second control surface.
- Reusing the same shared public-nav and workspace-link helpers in the footer prevents header/footer drift and keeps Prompt 05 aligned with the navigation rules already locked earlier in this plan.

### Prompt 05 completion notes

- Added a session-aware shared footer component for the public shell with Explore, Workspace, and Admin sections when relevant.
- Kept the signed-out footer intentionally lighter by replacing workspace/admin links with concise guidance instead of duplicating header auth actions.
- Implemented responsive stacked footer groupings plus a persistent copyright/status row.
- Validation succeeded with `npm run build` in `bloglab-ui-next`.

### Prompt 06 - Apply the public route-group shell to browse pages

Integrate the shared header and footer through the new public route-group layout.

Deliverable:

- public-facing pages such as `/`, `/blogs`, and `/blogs/[blogId]` render inside the new shell
- existing page-specific hero and content sections still read well beneath the shared header

Success criteria:

- pages have a consistent top and bottom frame
- the homepage no longer needs to fake a site header inside its own content block
- route transitions keep a stable look and feel

### Prompt 06 lessons learned after completion

- Prompt 06 needed a shared client-side shell state rather than separate header and homepage auth state. Without that, signing in from the shared header would have left homepage CTA content stale until a refresh.
- The cleanest attachment point was the existing `(public)` route-group layout. That kept the root layout provider-only and preserved the intentional separation between browse pages and the `/me/*` and `/admin/*` workspaces.
- After the shared shell took ownership of the site chrome, the public pages needed to drop their own `min-h-screen` wrappers so the footer could sit naturally at the bottom of the route-group layout instead of below an extra full-viewport page block.

### Prompt 06 completion notes

- Turned `src/app/(public)/layout.tsx` into the real shared browse-page shell by loading the current session and wrapping public pages in a shared public-site shell component.
- Added a shared public-shell auth context so the header, homepage CTA surface, and footer all stay in sync after login/logout without waiting for a refresh.
- Removed the homepage-owned top chrome and let the shared header/footer frame `/`, `/blogs`, and `/blogs/[blogId]` consistently.
- Adjusted public page wrappers so the shell owns full-height layout behavior cleanly.
- Validation succeeded with `npm run build` in `bloglab-ui-next`.

### Prompt 07 - Reconcile author/admin workspace behavior

Review `/me/*` and `/admin/*` after the public shell is introduced and confirm that they should:

- keep their current focused workspace shells untouched
- not inherit the public header/footer in this pass
- optionally add a lightweight link back to public browsing only if it improves usability without duplicating workspace nav

Success criteria:

- no duplicated navigation layers
- admin and author pages still feel purpose-built for work, not just browsing

### Prompt 07 lessons learned after completion

- The existing author and admin shells were already the right abstraction boundary for Prompt 07. They stay outside the `(public)` route group and keep their own focused navigation, summary areas, and guard states.
- A lightweight link back to public browsing was already present in the workspace shells and guard states through `Home` and `Public feed`, so Prompt 07 did not need new chrome. Adding the public header/footer on top would have created exactly the duplicated navigation this prompt was meant to avoid.
- The most useful change for this prompt was verification rather than redesign: focused shell tests now lock in that author/admin workspaces keep distinct local nav while still offering a clear path back to the public surface.

### Prompt 07 completion notes

- Confirmed `/me/*` and `/admin/*` remain outside the `(public)` route-group shell and therefore do not inherit the shared public header/footer.
- Kept the existing focused author/admin shells unchanged because they already provide lightweight public-browsing links without duplicating the public-shell navigation.
- Added focused tests for `AuthorPageShell`, `AuthorAuthGuard`, `AdminPageShell`, `AdminAuthGuard`, and `AdminAccessDenied` to lock in the current separation and browse-back affordances.
- Validation succeeded with focused Vitest coverage for the author/admin shell tests and `npm run build` in `bloglab-ui-next`.

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

### Prompt 08 lessons learned after completion

- The public header already had the right collapsed-menu architecture, so Prompt 08 was mostly about density control rather than a new navigation pattern. Shrinking the mobile brand block and slightly tightening the menu panel padding protected the logo/menu row without weakening the editorial look.
- The public pages needed more top breathing room under the shared sticky header. A small increase to route-level top padding plus slightly reduced mobile display sizes kept the homepage, feed, and story detail heroes from feeling crowded.
- The main usability gap on small screens was action density rather than content structure. Converting key CTA rows and pagination controls to full-width-first mobile buttons made profile, feed, story, and admin actions easier to reach without changing route behavior.
- The author and admin workspace shells were already structurally sound for mobile once their nav pills stayed non-wrapping and horizontally scrollable. Prompt 08 only needed targeted shell/title/action refinements rather than a shell redesign.

### Prompt 08 completion notes

- Tightened the shared public header and footer for smaller screens with a lighter mobile brand treatment, roomier full-width footer links, and preserved collapsed-menu behavior.
- Added more breathing room and better button sizing across `/`, `/blogs`, and `/blogs/[blogId]`, including less crowded mobile hero typography and more reachable CTA/pagination controls.
- Refined `/me/profile` and `/admin/users` small-screen behavior by improving shell spacing, keeping nav pills readable in horizontal scroll, widening utility controls, and making admin mutation/status blocks stack more cleanly.
- Validation succeeded with focused Vitest coverage for the public/layout and author/admin shell tests plus `npm run build` in `bloglab-ui-next`.

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

### Prompt 09 lessons learned after completion

- The most durable Prompt 09 coverage stayed close to shell boundaries rather than deep page snapshots. Server-rendered tests for the public header, footer, and route-group layout were enough to lock in the new public chrome without making the suite brittle to unrelated content changes inside individual pages.
- Header auth-state regressions were best covered as three explicit states: signed out, signed in non-admin, and signed in admin. That kept the role-sensitive navigation contract readable and ensured admin-only links remain opt-in rather than accidentally leaking into the public surface.
- The mobile menu needed one focused jsdom interaction test instead of broad responsive snapshots. Verifying open and close behavior, session-aware menu content, and body scroll locking captured the material client-side risk introduced by the collapsed navigation pattern.

### Prompt 09 completion notes

- Added focused regression tests for the public header covering signed-out, signed-in, and admin auth states.
- Added focused regression tests for the public footer so signed-out fallback content and signed-in workspace and admin sections stay intentional.
- Added a jsdom interaction test for the mobile navigation menu to verify session-aware links render when expanded and page scroll locking is restored when the menu closes.
- Validation succeeded with targeted Vitest coverage for the public layout, header, footer, and mobile-menu tests.

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
