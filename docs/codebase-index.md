# BlogLab Codebase Index

## Overview

BlogLab is a full-stack blog application composed of:

- **ASP.NET Core 3.1 Web API** in `BlogLab.Web`
- **Angular 11 UI** in `BlogLab-UI`
- **Next.js App Router alternate UI** in `bloglab-ui-next`
- Shared **domain models**, **repositories**, **services**, and **identity** projects

The backend solution is defined in `BlogLab.sln` and references five .NET projects.

## Top-Level Structure

- `BlogLab.sln` — Visual Studio solution for backend projects
- `BlogLab.Web/` — ASP.NET Core API host, controllers, startup/configuration
- `BlogLab.Models/` — Shared domain models and DTOs
- `BlogLabRepository/` — Dapper-based data access layer and repository interfaces
- `BlogLab.Services/` — token generation and photo upload services
- `BlogLab.Identity/` — custom identity user store integration
- `BlogLab-UI/` — Angular client application
- `bloglab-ui-next/` — Next.js alternate client application
- `Postman/` — API collection and environment files
- `images/` — sample/static image assets

## Backend Solution Projects

| Project | Role | Notes |
| --- | --- | --- |
| `BlogLab.Web` | API entrypoint | `netcoreapp3.1`, JWT auth, CORS, controller hosting |
| `BlogLab.Models` | Shared models | Blog, account, comment, photo, paging, settings, exceptions |
| `BlogLab.Repository` | Data access | Dapper + SQL Client repositories/interfaces |
| `BlogLab.Identity` | Identity integration | custom `UserStore` for auth/user management |
| `BlogLab.Services` | Application services | JWT token generation and Cloudinary photo handling |

## Backend Request Flow

Typical flow:

1. `BlogLab.Web/Controllers/*Controller.cs` receives HTTP requests.
2. Controllers use repository/service interfaces registered in `Startup.cs`.
3. `BlogLab.Services` handles token and photo-specific logic.
4. `BlogLabRepository` talks to the database.
5. `BlogLab.Models` provides shared request/response/domain objects.

## API Host (`BlogLab.Web`)

### Key files

- `Program.cs` — host bootstrap using `Startup`
- `Startup.cs` — DI registration, JWT auth, CORS, controller mapping
- `Extensions/ExceptionMiddlewareExtensions.cs` — centralized exception handling middleware
- `appsettings.json` / `appsettings.Development.json` — runtime configuration

### Registered infrastructure in `Startup.cs`

- **Auth:** JWT Bearer authentication
- **Identity:** `AddIdentityCore<ApplicationUserIdentity>()` with custom `UserStore`
- **Services:** `ITokenService`, `IPhotoService`
- **Repositories:** blog, comment, account, photo repositories
- **Settings:** `CloudinaryOptions`

### Controllers and routes

- `AccountController` — `api/account`
  - `POST /register`
  - `POST /login`
- `BlogController` — `api/blog`
  - `POST /` (authorized)
  - `GET /`
  - `GET /{blogId}`
  - `GET /user/{applicationUserId}`
  - `GET /famous`
  - `DELETE /{blogId}` (authorized)
- `BlogCommentController` — `api/blogcomment`
  - `POST /` (authorized)
  - `GET /{blogId}`
  - `DELETE /{blogCommentId}` (authorized)
- `PhotoController` — `api/photo`
  - `POST /` (authorized)
  - `GET /` (authorized)
  - `GET /{photoId}`
  - `DELETE /{photoId}` (authorized)
- `AdminBlogController` — `api/admin/blog`
  - `GET /` (authorized, admin only)

## Shared Models (`BlogLab.Models`)

### Folder map

- `Account/` — user identity, registration, and login models
- `Blog/` — blog entity, create DTO, paging, paged results
- `BlogComment/` — comment entity and create DTO
- `Photo/` — photo entity and upload DTO
- `Settings/` — configuration models such as `CloudinaryOptions`
- `Exception/` — API exception models

This project is referenced across the backend for shared contracts.

## Repository Layer (`BlogLabRepository`)

### Interfaces

- `IAccountRepository.cs`
- `IBlogRepository.cs`
- `IBlogCommentRepository.cs`
- `IPhotoRepository.cs`

### Implementations

- `AccountRepository.cs`
- `BlogRepository.cs`
- `BlogCommentRepository.cs`
- `PhotoRepository.cs`

### Notes

- Uses **Dapper** and `System.Data.SqlClient`
- Appears to provide persistence for accounts, blogs, comments, and photos

## Service Layer (`BlogLab.Services`)

- `ITokenService.cs` / `TokenService.cs` — JWT creation
- `IPhotoService.cs` / `PhotoService.cs` — Cloudinary-backed photo operations

## Identity Layer (`BlogLab.Identity`)

- `UserStore.cs` — custom identity store used by ASP.NET Core Identity

## Frontend (`BlogLab-UI`)

### Next.js stack

- Angular `11.2.x`
- Bootstrap 4, `ngx-bootstrap`, `ngx-toastr`

### Core app files

- `src/app/app.module.ts` — module declarations/imports/interceptors
- `src/app/app-routing.module.ts` — client routes
- `src/environments/` — Angular environment configs

### Route map

- `/` — home
- `/login` — login
- `/blogs` — blog list
- `/blog/:id` — blog detail
- `/photo-album` — protected photo album
- `/dashboard` — protected dashboard
- `/dashboard/:id` — protected blog edit
- `/not-found` — not found page

### App structure

- `src/app/components/`
  - `blog-components/` — blog list/detail/edit/card/famous blog UI
  - `comment-components/` — comment entry and display UI
  - `dashboard/`, `home/`, `login/`, `navbar/`, `not-found/`, `photo-album/`, `register/`
- `src/app/services/`
  - `account.service.ts`
  - `blog.service.ts`
  - `blog-comment.service.ts`
  - `photo.service.ts`
- `src/app/models/`
  - account, blog, blog-comment, and photo models mirroring backend contracts
- `src/app/guards/auth.guard.ts` — route protection
- `src/app/interceptors/`
  - `jwt.interceptor.ts`
  - `error.interceptor.ts`
- `src/app/pipes/summary.pipe.ts` — UI text summarization helper

## Alternate Frontend (`bloglab-ui-next`)

### Stack

- Next.js `16.x`
- React `19.x`
- App Router with server components and route handlers

### Core app areas

- `src/app/` — route tree, layouts, pages, loading states, and route handlers
- `src/components/` — UI components for public, author, auth, admin, and shared flows
- `src/lib/api/` — typed backend API clients and factories
- `src/lib/auth/` — cookie-backed auth/session helpers for server and client code
- `src/lib/ai/` — Ollama proxy integration helpers

### Notable routes

- `/` — public home page
- `/blogs` — paginated public blog list
- `/blogs/[blogId]` — public blog detail with comments
- `/me/posts` — author post management
- `/me/media` — author photo management
- `/admin/blogs` — admin review/delete workspace

## Supporting Assets

- `Postman/BlogLab WebApi.postman_collection.json` — API request collection
- `Postman/Dev.postman_environment.json` — Postman environment config
- `images/` — image assets

## Index notes

- `bin/` and `obj/` folders exist in several .NET projects and are build artifacts rather than source.
- No top-level `docs/` folder existed before this index was added.
- This index is intended as a navigation aid, not a full API or schema reference.