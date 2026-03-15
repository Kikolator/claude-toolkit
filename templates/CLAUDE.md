# CLAUDE.md

<!-- Copy this template into your project root and fill in the sections. -->
<!-- Claude Code reads this file to understand your project conventions. -->

## Project Overview

<!-- Brief description of the project, its purpose, and key users. -->

TODO: Describe your project here.

## Tech Stack

- **Framework:** Next.js (App Router)
- **Database:** Supabase (PostgreSQL + Auth + Storage)
- **Language:** TypeScript (strict mode)
- **Testing:** Vitest (unit/integration), Playwright (E2E)
- **Payments:** Stripe
- **Styling:** TODO: Tailwind CSS / CSS Modules / other
- **Deployment:** TODO: Vercel / other

## Project Structure

```
apps/
  web/                          # Next.js App Router (no src/ directory)
    app/                        # Pages, layouts, route handlers
    components/                 # React components
    lib/                        # Utilities, Supabase/Stripe clients
    hooks/                      # Custom React hooks
    types/                      # TypeScript types
    *.test.ts                   # Colocated unit tests (Vitest)
    vitest.config.ts            # Vitest configuration
    playwright.config.ts        # Playwright configuration

packages/
  db/                           # Supabase database package
    supabase/
      migrations/               # SQL migrations
      config.toml               # Supabase project config
    types/
      database.ts               # Generated DB types (supabase gen types)
    docs/
      MT-SCHEMA-SPEC.md         # Multi-tenant schema specification

.claude/                        # Symlinked from claude-toolkit
.github/                        # CI workflows
```

## Conventions

### Code Style
- Use `'use client'` only when the component needs browser APIs or React hooks
- Prefer Server Components by default
- Use Zod for runtime validation at API boundaries
- Use TypeScript strict mode — avoid `any`

### Data Fetching
- Server Components: fetch data directly using Supabase server client
- Client Components: use SWR or React Query with Supabase client
- Server Actions: use for mutations from Server Components
- API Routes: use for webhooks and external integrations

### Database
- All tables must have RLS enabled
- Use migrations for schema changes (`supabase migration new`)
- Never use `service_role` key in client-side code
- Always handle Supabase query errors (check `error` before using `data`)

### Testing
- Unit tests go next to source files: `foo.ts` → `foo.test.ts`
- E2E tests go in `e2e/` or `tests/` directory
- Run tests before committing: `npm test`
- E2E tests must work in CI (headless, no manual setup)

### Naming
- Files: `kebab-case.ts`
- Components: `PascalCase.tsx`
- Utilities: `camelCase`
- Database tables: `snake_case`
- Environment variables: `UPPER_SNAKE_CASE`

## Commands

```bash
npm run dev          # Start dev server
npm run build        # Production build
npm test             # Run Vitest
npm run test:e2e     # Run Playwright tests
npm run lint         # Run ESLint
npx tsc --noEmit     # Type check
```

TODO: Adjust commands to match your package.json scripts.

## Environment Variables

```
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=        # Server-only, never expose to client
STRIPE_SECRET_KEY=                # Server-only
STRIPE_WEBHOOK_SECRET=            # Server-only
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=
```

TODO: Add any project-specific environment variables.

## Common Patterns

### Supabase Server Client (App Router)
```typescript
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'

export async function createClient() {
  const cookieStore = await cookies()
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll(), setAll: (cookies) => cookies.forEach(c => cookieStore.set(c)) } }
  )
}
```

### Protected Server Action
```typescript
'use server'
import { createClient } from '@/lib/supabase/server'

export async function myAction(formData: FormData) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) throw new Error('Unauthorized')
  // ... action logic
}
```

TODO: Add project-specific patterns here.
