# BlogLab Alternate UI Implementation Prompts

## How to Use These Prompts

- Execute them in order.
- Keep each change set small and reviewable.
- Do not remove or break the existing `BlogLab-UI` Angular application.
- Validate each prompt before moving to the next one.

## Prompt 01 - Create the Alternate UI Project

Create a new project named `BlogLab-UI-Next` at the repository root using the latest stable **Next.js + React** with **TypeScript**, **App Router**, **Tailwind CSS**, and standard linting. Keep the current Angular app untouched. Add a README and `.env.example` with the ASP.NET API base URL.

## Prompt 02 - Add shadcn/ui and App Foundations

Install and configure **shadcn/ui** for the new app. Add the base design system, utility helpers, theme tokens, fonts, toast support, and a responsive application shell with navbar, content container, and footer. Aim for a modern editorial blog look.

## Prompt 03 - Inventory and Model the Existing API Contracts

Inspect the current ASP.NET Core API and create typed frontend models/clients for account, blog, comment, and photo operations. Reuse the existing endpoints where possible and document any mismatches that require backend changes for the new UI.

## Prompt 04 - Implement the API Client Layer

Build a centralized API layer for anonymous and authenticated requests. Add consistent error parsing, request helpers, and support for server-side and client-side usage in Next.js. Keep the API calls isolated so later backend changes do not ripple through the UI.

## Prompt 05 - Implement the Session/Auth Strategy

Add a session strategy for the Next.js app using the existing login/register endpoints. Prefer a secure HTTP-only cookie flow via Next.js route handlers or a BFF-style proxy rather than storing the JWT directly in localStorage. Expose a clean auth API for the UI layer.

## Prompt 06 - Build Login and Register Modals

Create **Login** and **Register** modal dialogs using shadcn `Dialog`, `react-hook-form`, and `zod`. Connect them to the current `POST /api/account/login` and `POST /api/account/register` endpoints. Add validation messages, loading states, and success/error toasts.

## Prompt 07 - Build the Public Home Page

Create a modern home page for the alternate UI with a hero section, a featured/famous posts section backed by `GET /api/blog/famous`, and a latest posts preview. Use polished card layouts and responsive spacing.

## Prompt 08 - Build the Blog Listing Experience

Create the main blog feed page using `GET /api/blog` with pagination, loading skeletons, empty states, and a clean card-based layout. Include room in each card for metadata, image, summary text, and a Like control placeholder.

## Prompt 09 - Build the Blog Detail Experience

Create the blog detail page using `GET /api/blog/{blogId}`. Include title, author metadata, publish/update dates, hero image handling, content layout, and a modern comments section using the existing blog comment endpoints.

## Prompt 10 - Add Protected Author Pages

Create protected pages for the signed-in user to manage their content and media. Use `GET /api/blog/user/{applicationUserId}` for the user's posts and `GET /api/photo` for their uploaded images. Add empty states and auth guards.

## Prompt 11 - Implement Modal-Based Blog Create/Edit

Implement create and edit blog workflows using modals instead of dedicated pages. Reuse the current backend POST upsert behavior for MVP by sending `BlogId` in the payload, but keep the frontend abstraction ready for a future explicit update endpoint.

## Prompt 12 - Implement Photo Upload and Selection UX

Build the media workflow for blog editing using the existing photo API. Support image upload, gallery selection, preview, and delete messaging. Respect the backend rule that photos attached to published blogs cannot be deleted.

## Prompt 13 - Add Delete Confirmation and Safer Mutations

Add confirmation dialogs for deleting blogs and photos using shadcn `AlertDialog`. Ensure mutation buttons have loading/disabled states and that the UI refreshes correctly after success.

## Prompt 14 - Add Backend Support for Likes

Implement the full backend Like feature in the .NET solution. Add the necessary domain model(s), repository methods, controller endpoint(s), and data access changes so users can like/unlike a blog and blog responses can include `likeCount` and `likedByCurrentUser`.

## Prompt 15 - Wire the Frontend Like Experience

Connect the new Next.js UI to the Like API. Add Like buttons to blog cards and the blog detail page with optimistic updates, visible counts, loading protection, and an auth-modal prompt when an anonymous user tries to like a post.

## Prompt 16 - Add an Optional Ollama Proxy Endpoint

Implement an optional server-side integration for **Ollama**. Do not call Ollama directly from the browser. Add a feature-flagged endpoint and configuration for model name, host URL, timeout, and disabled-state handling.

## Prompt 17 - Add AI Draft Generation to the Editor

Create an **AI Draft** modal in the blog editor. Let the user enter topic, tone, keywords, and desired length, then call the server-side Ollama integration. Allow the user to preview the generated text and insert, replace, or append it into the editor.

## Prompt 18 - Improve UX, Accessibility, and SEO

Refine the alternate UI to feel production-ready: responsive layouts, focus-safe modal interactions, keyboard support, accessible form errors, metadata for public pages, 404/error states, and polished loading/empty states.

## Prompt 19 - Add Targeted Tests

Add targeted tests for auth modals, protected-route behavior, blog create/edit modal flows, Like toggling, and AI draft generation enabled/disabled behavior. Prefer the smallest practical scope first, then add a few end-to-end checks for the main user journeys.

## Prompt 20 - Document Local Development and Rollout

Update the repository docs with instructions for running the ASP.NET API, the legacy Angular UI, and the new Next.js alternate UI together. Include environment variable guidance, Ollama setup notes, and a suggested rollout strategy.