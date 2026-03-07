# BlogLab Alternate UI Implementation Plan

## Objective

Add a new **alternate UI project** alongside the existing Angular app, using the **latest stable Next.js + React**, **Tailwind CSS**, and **shadcn/ui**, while preserving compatibility with the current ASP.NET Core API and leaving the legacy UI intact during rollout.

## Current Codebase Baseline

- Backend: `BlogLab.Web` on **ASP.NET Core 3.1** with JWT authentication.
- Current UI: `BlogLab-UI` on **Angular 11**.
- Existing reusable API areas:
  - `POST /api/account/register`
  - `POST /api/account/login`
  - `GET/POST/DELETE /api/blog`
  - `GET /api/blog/{blogId}`
  - `GET /api/blog/user/{applicationUserId}`
  - `GET /api/blog/famous`
  - `GET/POST/DELETE /api/blogcomment`
  - `GET/POST/DELETE /api/photo`
- Existing blog editing already uses a **POST upsert pattern** via `BlogCreate.BlogId` rather than a dedicated `PUT` endpoint.
- Current gaps for the alternate UI scope:
  - No Like feature in backend or UI.
  - No Ollama integration.
  - No Next.js-specific auth/session handling.
  - Existing UI uses page-based auth/editing rather than modals.

## Recommended Delivery Strategy

1. Create a separate UI project, e.g. `BlogLab-UI-Next`.
2. Keep the Angular app working during development and rollout.
3. Reuse current API contracts where practical.
4. Add only the backend changes required for:
   - Likes
   - Optional AI generation
   - Any CORS/session support needed for the new UI
5. Build the new UI incrementally so public browsing works first, then auth, then authoring, then advanced features.

## Recommended Technical Approach

### Frontend

- **Next.js App Router**
- **React** with TypeScript
- **Tailwind CSS**
- **shadcn/ui** for dialogs, forms, buttons, cards, dropdowns, sheets, alerts, and toasts
- **react-hook-form + zod** for modal forms
- **TanStack Query** for API fetching/caching/mutations

### Auth Strategy

Recommended approach for the new UI:

- Use the existing login/register API endpoints.
- Store the JWT in a **secure HTTP-only cookie** managed through Next.js route handlers or a thin BFF layer.
- Forward the token to the ASP.NET API as a Bearer token from the server side where possible.
- Use client state only for display/session awareness, not as the source of truth for security.

This is preferable to repeating the Angular `localStorage` token pattern.

### Backend Strategy

- Keep existing account, blog, comment, and photo endpoints available.
- Add CORS support for the Next.js dev/prod origins.
- For blog editing, either:
  - keep using the current POST upsert contract for MVP, or
  - introduce a clearer `PUT /api/blog/{id}` later without breaking current behavior.
- Add new endpoints/contracts for Likes and AI generation.

## Phase-by-Phase Plan

### Phase 0 - Decisions and Guardrails

- Confirm project name and location for the alternate UI.
- Decide whether the new UI will be a long-term side-by-side app or a migration target.
- Confirm package manager; `npm` is the safest default because the current UI already uses it.
- Decide whether auth is cookie-backed via Next route handlers from day one or introduced after MVP.

### Phase 1 - Scaffold the Alternate UI Project

- Create a new Next.js app with TypeScript and App Router.
- Add Tailwind and baseline lint/format tooling.
- Add environment variable support for the API base URL.
- Add a README for local development.
- Ensure the Angular UI remains untouched.

### Phase 2 - Establish the Design System

- Install and configure shadcn/ui.
- Define typography, color tokens, spacing, layout containers, and reusable card patterns.
- Build a modern blog shell with:
  - top navigation
  - featured hero section
  - blog cards
  - responsive footer
  - toast/notification system
- Prepare consistent modal, alert, and loading patterns.

### Phase 3 - Build a Typed API Layer

- Create typed DTOs matching the current API contracts.
- Build centralized clients for account, blog, comment, and photo APIs.
- Normalize API error handling so modal workflows can show clear messages.
- Add server/client-safe fetch helpers for authenticated and anonymous requests.

### Phase 4 - Public Reading Experience

- Build the home page with a modern editorial layout.
- Add a featured/famous posts section using `GET /api/blog/famous`.
- Add a paginated blog feed using `GET /api/blog`.
- Build the blog detail page using `GET /api/blog/{id}`.
- Keep comments visible and modernize their presentation using the existing comment endpoints.

### Phase 5 - Authentication via Modals

- Replace separate login/register pages in the alternate UI with modal-driven flows.
- Build login and register dialogs using shadcn `Dialog`.
- Add client/server validation, loading states, and toast feedback.
- Support "auth required" modal prompts when users try protected actions.

### Phase 6 - Author Dashboard and Modal-Based Editing

- Add protected pages for:
  - My posts
  - My media/photos
- Use `GET /api/blog/user/{applicationUserId}` for the current user's posts.
- Use existing photo endpoints for media selection/upload.
- Implement create/edit blog workflows in modals rather than full-page forms.
- Add delete confirmations with `AlertDialog`.
- Reuse the current POST upsert behavior first, while isolating the API call so it can later move to an explicit update endpoint if desired.

### Phase 7 - Photo and Media Experience

- Add a media picker modal tied to the current Cloudinary-backed photo API.
- Show image previews, upload progress, and delete protection messages.
- Keep the current backend rule that photos attached to blogs cannot be deleted.

### Phase 8 - Add the Like Feature

Backend work:

- Add a new Like model and persistence path.
- Add repository methods and controller endpoints to toggle likes.
- Expose `likeCount` and `likedByCurrentUser` in blog list/detail responses.

Recommended API shape:

- `POST /api/blog/{blogId}/like/toggle`
- Or equivalent `POST/DELETE` endpoints if preferred

Frontend work:

- Add Like buttons to blog cards and blog detail pages.
- Use optimistic updates for a modern feel.
- If unauthenticated, open the auth modal instead of failing silently.

### Phase 9 - Optional Ollama AI Blog Generation

Recommended architecture:

- Do **not** call Ollama directly from the browser.
- Add a server-side proxy endpoint in ASP.NET Core or Next.js.
- Protect it behind a feature flag and environment variables.

Recommended AI workflow:

- Open an "AI Draft" modal from the editor.
- Let the user choose topic, tone, length, and optional keywords.
- Generate a draft using Ollama.
- Let the user preview, insert, replace, or append content.
- Make the feature optional and never block manual authoring.

### Phase 10 - UX Polish, Accessibility, and SEO

- Add skeleton loading states and empty states.
- Ensure keyboard-friendly modal interactions and focus management.
- Add SEO metadata for public blog pages.
- Add responsive behavior for mobile/tablet/desktop.
- Add not-found and error boundaries.

### Phase 11 - Testing and Verification

- Unit test form validation, auth state helpers, and API clients.
- Integration test modal auth flows, blog create/edit flows, and like toggling.
- Add end-to-end coverage for the main reader and author journeys.
- Validate against the existing backend, not just mocks.

### Phase 12 - Documentation and Rollout

- Document local setup for running the API + Angular + Next.js together.
- Add environment variable examples for API base URL and Ollama configuration.
- Add rollout notes for staging and production.
- Decide whether the alternate UI will live behind a new route, port, subdomain, or reverse-proxy path.

## Suggested Folder Direction for the New UI

- `app/` for public pages, protected pages, and route handlers
- `components/` for blog cards, dialogs, editor UI, navbar, footer, loaders
- `features/auth/` for auth modals and session helpers
- `features/blogs/` for queries, mutations, editor flows, like actions
- `features/media/` for photo upload and selection
- `features/ai/` for Ollama prompt generation and insertion flows
- `lib/` for API clients, env parsing, utilities, constants

## Key Risks and Constraints

- The backend is on **.NET Core 3.1**, so any new cross-origin/session behavior should be implemented carefully.
- Existing blog persistence appears to be stored-procedure-driven; the Like feature will likely require schema and repository updates outside the UI.
- The current edit flow is built around POST upsert, so the alternate UI should not assume a clean REST update contract exists yet.
- Ollama availability, response time, and model size should be treated as optional infrastructure, not a hard dependency for authoring.

## Definition of Done

The alternate UI effort is complete when:

- A separate Next.js app runs successfully beside the Angular app.
- Public users can browse blogs with a modern design.
- Authentication works via modals.
- Authors can create and edit blogs via modals.
- Users can like/unlike blogs with visible counts.
- Optional AI draft generation works through Ollama when enabled.
- Core flows are covered by targeted tests and basic documentation.