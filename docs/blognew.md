# bloglab-new Migration Plan

## Goal

Create a new repository named `bloglab-new` that contains the complete current BlogLab backend and support structure, plus the current `bloglab-ui-next` application, while excluding the legacy Angular project `BlogLab-UI`.

The intended contents of `bloglab-new` are:

- `BlogLab.Web`
- `BlogLab.Models`
- `BlogLab.Identity`
- `BlogLab.Services`
- `BlogLab.Services.Tests`
- `BlogLabRepository`
- `bloglab-ui-next`
- `docker`
- `docs`
- `scripts`
- `tests`
- `images`
- `Postman`
- root files such as `BlogLab.sln`, `docker-compose.yml`, `.gitignore`, and `.env.example`

The new repository should not contain:

- `BlogLab-UI`
- Angular-specific Docker or script references after cleanup
- nested git metadata under `bloglab-ui-next`
- local caches, generated output, or secret-only machine-specific files unless intentionally recreated locally

## Important Constraints

- The current root repository is a git repository.
- The current `bloglab-ui-next` folder is also its own nested git repository.
- The current root repo tracks `bloglab-ui-next` as a gitlink entry rather than as normal files.
- Because of that, the safest migration is a fresh snapshot-style copy into `bloglab-new`, not a casual folder copy.

## Recommended Outcome

`bloglab-new` should become a single normal git repository with one git root, where `bloglab-ui-next` is just a normal tracked directory.

## Step 1 - Prepare the new local repo and local env files

Create and prepare the local `bloglab-new` working folder before copying any code.

### 1.1 Clone the already-created empty GitHub repository

Use a sibling location, not a folder inside the current `BlogLab` repo.

Example target:

- source: `H:\dev\bloglab\BlogLab`
- destination: `H:\dev\bloglab-new`

Recommended commands:

```powershell
Set-Location 'H:\dev'
git clone https://github.com/<your-account>/bloglab-new.git
Set-Location '.\bloglab-new'
git status --short --branch
```

Expected result:

- `bloglab-new` exists as a clean new local clone
- its `.git` belongs only to the new repo

### 1.2 Decide your local env strategy up front

For `bloglab-new`, plan to use two local env files:

1. root `.env.local`
2. `bloglab-ui-next/.env.local`

Use them for local overrides and secrets. Keep them ignored.

Recommended intent:

- root `.env` or `.env.example` remains the shared baseline for Docker and API settings
- root `.env.local` holds machine-specific local overrides for the new repo
- `bloglab-ui-next/.env.local` holds Next.js-specific local configuration

### 1.3 Create the root `.env.local` for `bloglab-new`

The current Docker stack already supports an optional root `.env.local`. In the new repo, use it for values that should stay local to your machine.

Suggested starting content:

```dotenv
BLOGDB_SA_PASSWORD=BlogLab!DevSa2026
BLOGDB_APP_USER=bloguser
BLOGDB_APP_PASSWORD=Bl0gUs3r!!

# Optional API override values
Jwt__Key=A$Fd3vL0ng@$$p@!!W0rd#

# Optional Cloudinary configuration
CLOUDINARY_URL=
```

Notes:

- If you do not want local secrets in the repo, do not commit this file.
- Prefer storing real Cloudinary secrets only in `.env.local`, not in shared tracked files.

### 1.4 Create `bloglab-ui-next/.env.local` for `bloglab-new`

Copy from `bloglab-ui-next/.env.example` and then keep local-only values there.

Suggested starting content for host-run development:

```dotenv
NEXT_PUBLIC_BLOGLAB_API_BASE_URL=http://localhost:5000/api
BLOGLAB_SERVER_API_BASE_URL=http://localhost:5000/api
BLOGLAB_AUTH_TOKEN_COOKIE_NAME=bloglab-auth-token
BLOGLAB_AUTH_SESSION_COOKIE_NAME=bloglab-auth-session
BLOGLAB_AUTH_COOKIE_MAX_AGE_SECONDS=1800
BLOGLAB_AUTH_COOKIE_SECURE=false
BLOGLAB_OLLAMA_ENABLED=true
BLOGLAB_OLLAMA_HOST_URL=http://localhost:11434
BLOGLAB_OLLAMA_MODEL=llama3.2
BLOGLAB_OLLAMA_TIMEOUT_MS=30000
BLOGLAB_OLLAMA_API_KEY=
```

Notes:

- For Dockerized Next.js runs, Compose can still override `BLOGLAB_SERVER_API_BASE_URL` to `http://api:5000/api`.
- Keep `.env.local` out of version control.

### 1.5 Verify ignore rules before copying code

Before you copy any files into `bloglab-new`, confirm these are ignored or planned to remain ignored:

- `.env.local`
- `bloglab-ui-next/.env.local`
- `node_modules`
- `.next`
- `bin`
- `obj`
- `.vs`
- `tests/artifacts`

If the ignore rules are incomplete in the new repo, fix them before continuing.

## Step 2 - Copy the source tree into `bloglab-new` without Angular or git metadata

Copy the current working tree from `BlogLab` into `bloglab-new`, but exclude:

- root `.git`
- `BlogLab-UI`
- `bloglab-ui-next/.git`
- generated output such as `.next`, `node_modules`, `bin`, `obj`, `.vs`, coverage output, and local artifacts

Use a copy method that supports explicit exclusions. Do not drag and drop the folder in Explorer.

Recommended approach:

- copy the working tree into the new repo root
- preserve normal files
- exclude all git metadata and excluded build output

## Step 3 - Normalize `bloglab-ui-next` into a normal directory

After the copy, confirm all of the following inside `bloglab-new`:

- `bloglab-ui-next` exists as a normal folder
- there is no `bloglab-ui-next/.git`
- `git status` in the new repo shows normal files under `bloglab-ui-next`, not a gitlink

This is a mandatory check. If this step is wrong, the new repo structure is wrong.

## Step 4 - Remove Angular-specific runtime references

Update the new repo so it no longer assumes the old Angular app exists.

Expected cleanup targets include:

- `docker-compose.yml`
- `scripts/smoke-test-docker-dev.ps1`
- `docs/docker-local-development.md`
- `docs/codebase-index.md`
- any docs still describing Angular as part of the active dev flow

Primary cleanup actions:

- remove the `ui` Compose service
- remove Angular-only volume definitions if no longer needed
- remove Angular start instructions from docs
- remove Angular verification steps from smoke scripts if still present

## Step 5 - Revalidate environment file references in the new repo

Once Angular references are removed, make sure the new repo still has a coherent local setup.

Confirm:

- root `.env.example` is still present for shared setup guidance
- root `.env.local` works for your local Docker and API overrides
- `bloglab-ui-next/.env.example` remains the shareable Next.js template
- `bloglab-ui-next/.env.local` is the local Next.js working file

## Step 6 - Validate the backend and solution in `bloglab-new`

Run a clean backend verification in the new repo.

Minimum checks:

```powershell
dotnet build .\BlogLab.sln
```

If you want isolated artifacts in the new repo as well, keep using the `tests/artifacts/...` convention already adopted in the current workspace.

## Step 7 - Validate the Next.js app in `bloglab-new`

From `bloglab-ui-next`, run:

```powershell
npm install
npm run test
npm run build
```

If you prefer a smaller first-pass check, run the currently important focused suite before the full test run.

## Step 8 - Validate Docker Compose in `bloglab-new`

After removing Angular, verify the new full-stack repo still runs the expected services.

Expected stack after cleanup:

- `db`
- `db-init`
- `api`
- `ui-next`

Run:

```powershell
docker compose up -d --build
docker compose ps
```

Confirm:

- API is reachable on `http://localhost:5000`
- Next.js UI is reachable on `http://localhost:3001` unless you override the host port

## Step 9 - Review the first commit carefully

Before pushing anything:

- inspect `git status`
- inspect staged changes
- confirm `BlogLab-UI` is absent
- confirm no secrets from `.env.local` files are staged
- confirm `bloglab-ui-next` is tracked as normal files

Recommended checks:

```powershell
git status
git diff --cached --stat
```

## Step 10 - Create the initial `bloglab-new` commit and push

After validation passes:

```powershell
git add .
git commit -m "Initial full-stack import without legacy Angular UI"
git push origin <default-branch>
```

## Step 11 - Open `bloglab-new` in a fresh workspace

Only after the initial push succeeds:

- open `bloglab-new` in a new VS Code workspace
- treat it as the new development home for the full-stack app
- keep the old `BlogLab` repo unchanged as a fallback reference until the migration is fully proven

## Recommended Order of Execution

1. Clone empty `bloglab-new`
2. Create `.env.local` files in the new repo
3. Copy the source tree with exclusions
4. Remove Angular references
5. Validate backend, Next.js, and Docker
6. Commit and push
7. Start fresh development from `bloglab-new`

## Notes for Later Follow-up

These are useful follow-ups, but they should not block the initial repo copy:

- rename solution and project identifiers from `BlogLab` to `bloglab-new` if desired
- simplify docs that still describe the Next.js app as an alternate UI rather than the primary UI
- remove outdated Angular-only planning documents if they no longer add value