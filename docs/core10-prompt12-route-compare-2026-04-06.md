# BlogLab API Prompt 12 Route Comparison - 2026-04-06

## Context

- Validation was run after removing MVC controller infrastructure from the `net10.0` minimal-only host.
- The API was host-run against Docker SQL using `sa` and Cloudinary settings exported from `.env` into the process environment.
- Unlike the original baseline, this comparison used valid authenticated users and a working local schema so route behavior could be checked after the migration rather than against the earlier drifted environment.

## Route comparison

| Route | Prompt 01 baseline | Prompt 12 current | Notes |
| --- | --- | --- | --- |
| `POST /api/account/register` | `500` | `200` | Improved after account-schema drift reconciliation; request/response contract is preserved. |
| `POST /api/account/login` | `400` after failed register | `200` | Improved because registration now succeeds in the validated local environment. |
| `GET /api/blog` | `200` | `200` | Public list route remains reachable. |
| `GET /api/blog/{blogId}` | `204` for missing id | `200` for existing blog, `204` for missing id | Minimal endpoint was adjusted to preserve the missing-blog `204` baseline behavior. |
| `GET /api/blog/user/{applicationUserId}` | `200` | `200` | User blog list remains reachable. |
| `GET /api/blog/famous` | `200` | `200` | Famous-blog list remains reachable. |
| `POST /api/blog` | `401` anonymous | `200` authenticated, `401` anonymous | Auth gate remains intact and valid authenticated create now succeeds. |
| `POST /api/blog/{blogId}/like/toggle` | `401` anonymous | `200` authenticated, `401` anonymous | Auth gate remains intact and valid authenticated toggle now succeeds. |
| `GET /api/blogcomment/{blogId}` | `200` | `200` | Public comment list remains reachable. |
| `POST /api/blogcomment` | `401` anonymous, `500` authenticated | `200` authenticated | Improved after reconciling `ParentBlogCommentId` nullability with the request contract. |
| `GET /api/photo/{photoId}` | `204` for missing id | `200` for existing photo, `204` for missing id | Minimal endpoint preserves the missing-photo `204` behavior. |
| `GET /api/photo` | `401` anonymous, `200` authenticated | `401` anonymous, `200` authenticated | Auth gate remains intact. |
| `POST /api/photo` | `401` anonymous, `400` authenticated | `200` authenticated | Improved once valid Cloudinary credentials from `.env` were supplied to the host-run process. |
| `GET /api/admin/blog` | `401` anonymous, `403` non-admin, `200` admin | `401` anonymous, `403` non-admin, `200` admin | Admin-only behavior is preserved on the minimal route. |

## Summary

- Removing `AddControllers()` and `MapControllers()` did not break the migrated route surface.
- Anonymous protection and admin gating still behave as expected on the minimal-only host.
- The main differences from Prompt 01 are improvements caused by local schema reconciliation and valid Cloudinary configuration, not regressions introduced by removing MVC.