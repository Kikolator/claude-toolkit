# CLAUDE.md

<!-- Copy this template into your project root and fill in the sections. -->
<!-- Claude Code reads this file to understand your project conventions. -->
<!-- This template is for front-end marketing / landing page projects. -->

## Project Overview

<!-- Brief description of the project, its purpose, and target audience. -->

TODO: Describe your project here.

## Tech Stack

- **Framework:** Next.js (App Router)
- **Language:** TypeScript (strict mode)
- **Styling:** Tailwind CSS + shadcn/ui
- **Animations:** Framer Motion
- **Testing:** Vitest (unit/integration), Playwright (E2E)
- **Deployment:** Vercel
- **CMS:** TODO: Sanity / Contentful / Storyblok / other

## Project Structure

```
app/
  layout.tsx                    # Root layout (fonts, metadata, analytics)
  page.tsx                      # Homepage
  (marketing)/                  # Marketing page group
    about/page.tsx
    pricing/page.tsx
    blog/
      page.tsx                  # Blog index
      [slug]/page.tsx           # Blog post (CMS-driven)
  api/
    og/route.tsx                # Dynamic OG image generation
    revalidate/route.ts         # CMS webhook revalidation endpoint

components/
  ui/                           # shadcn/ui components
  sections/                     # Page sections (hero, features, pricing, cta, testimonials)
  layout/                       # Header, footer, navigation
  animations/                   # Framer Motion wrapper components

lib/
  cms.ts                        # CMS client and query helpers
  constants.ts                  # Site metadata, nav links, config
  utils.ts                      # General utilities (cn, formatDate, etc.)

content/                        # Static content, CMS schemas, or MDX files
public/                         # Static assets, images, favicons

*.test.ts                       # Colocated unit tests (Vitest)
e2e/                            # Playwright E2E tests
vitest.config.ts
playwright.config.ts
```

## Conventions

### Code Style
- Use Server Components by default
- Use `'use client'` only for interactive components, animations, or browser APIs
- Push `'use client'` boundaries as far down the component tree as possible
- Use TypeScript strict mode — avoid `any`

### SEO
- Every page must export `metadata` or `generateMetadata`
- Use semantic HTML elements (`<main>`, `<section>`, `<article>`, `<nav>`, `<header>`, `<footer>`)
- Add JSON-LD structured data for key pages (Organization, WebSite, Article, FAQ)
- Generate dynamic OG images via `app/api/og/route.tsx`
- Include a `sitemap.ts` and `robots.ts` in the app root

### Performance
- Use `next/image` for all images — never use raw `<img>` tags
- Use `next/font` for font loading (Geist or project fonts) — no external font stylesheets
- Avoid layout shift: set explicit `width`/`height` on images, use font `display: swap`
- Optimize Core Web Vitals: target LCP < 2.5s, CLS < 0.1, INP < 200ms
- Prefer static generation (SSG) and ISR over SSR for marketing pages
- Lazy-load below-the-fold sections and heavy components

### Styling
- Tailwind CSS utility-first — avoid custom CSS unless necessary
- Use shadcn/ui for interactive components (dialogs, dropdowns, accordions, etc.)
- Use CSS variables for theming (colors, spacing, radii) — define in `globals.css`
- Mobile-first responsive design: start with mobile, scale up with `sm:`, `md:`, `lg:`
- Use `cn()` utility (clsx + tailwind-merge) for conditional classes

### Animations
- Use Framer Motion for scroll-triggered and enter animations
- Wrap animated components in `'use client'` boundary — keep the wrapper thin
- Respect `prefers-reduced-motion`: disable or simplify animations for users who opt out
- Keep animations subtle and purposeful — no gratuitous motion

### Content
- Dynamic content comes from the headless CMS
- Use ISR with `revalidate` for CMS-driven pages
- Set up a `/api/revalidate` webhook endpoint for on-demand CMS revalidation
- Keep CMS queries in `lib/cms.ts` — components should not contain query logic

### Accessibility
- Use semantic HTML elements over generic `<div>`s
- Add ARIA attributes only where HTML semantics are insufficient
- Ensure keyboard navigation works for all interactive elements
- Maintain color contrast ratio of at least 4.5:1 (WCAG AA)
- Test with screen reader and keyboard-only navigation

### Naming
- Files: `kebab-case.ts`
- Components: `PascalCase.tsx`
- Utilities: `camelCase`
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
NEXT_PUBLIC_SITE_URL=            # Canonical site URL (used in metadata, OG images, sitemap)

# CMS — TODO: replace with your provider's keys
CMS_API_TOKEN=                   # Server-only CMS read token
CMS_REVALIDATION_SECRET=        # Webhook secret for on-demand ISR
NEXT_PUBLIC_CMS_PROJECT_ID=     # Public CMS project identifier (if needed)

# Analytics — TODO: add if applicable
NEXT_PUBLIC_GA_ID=               # Google Analytics
NEXT_PUBLIC_POSTHOG_KEY=         # PostHog (or other analytics)
```

TODO: Add any project-specific environment variables.

## Common Patterns

### Page Metadata
```typescript
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'Page Title | Site Name',
  description: 'Page description for search engines and social sharing.',
  openGraph: {
    title: 'Page Title | Site Name',
    description: 'Page description for search engines and social sharing.',
    images: [{ url: '/api/og?title=Page+Title' }],
  },
}
```

### Animated Section Wrapper
```typescript
'use client'
import { motion } from 'framer-motion'

export function FadeInSection({ children }: { children: React.ReactNode }) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: '-100px' }}
      transition={{ duration: 0.5 }}
    >
      {children}
    </motion.div>
  )
}
```

### CMS Data Fetching with ISR
```typescript
// app/blog/[slug]/page.tsx
import { getPost } from '@/lib/cms'

export const revalidate = 3600 // Revalidate every hour

export default async function BlogPost({ params }: { params: Promise<{ slug: string }> }) {
  const { slug } = await params
  const post = await getPost(slug)
  // ... render post
}
```

TODO: Add project-specific patterns here.
