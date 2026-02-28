# XomFit Web App

Browser-based companion to the XomFit iOS app. Built with Next.js 15, TypeScript, Tailwind CSS, and Supabase.

## What It Is

The web app is **read-heavy** — workout logging stays on iOS. The web gives you:

- 📊 **Dashboard** — recent workouts, quick stats, welcome back
- 👤 **Public Profiles** — shareable profile pages with stats and PRs
- 📜 **Workout History** — searchable list and detailed set/rep view
- 📈 **Analytics** — progress charts for all major lifts (recharts)
- 👥 **Social Feed** — see what your crew is lifting
- 🔐 **Auth** — Google SSO or email/password via Supabase

## Tech Stack

- **Framework:** Next.js 15 (App Router)
- **Language:** TypeScript
- **Styling:** Tailwind CSS (dark theme, green accents)
- **Auth & DB:** Supabase
- **Charts:** Recharts

## Getting Started

```bash
cd web
cp .env.local.example .env.local
# Fill in your Supabase URL and anon key

npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000).

## Project Structure

```
web/
├── app/
│   ├── page.tsx                    # Landing page (marketing)
│   ├── dashboard/page.tsx          # Authenticated dashboard
│   ├── login/page.tsx              # Auth (Google + email)
│   ├── profile/[username]/page.tsx # Public profile
│   ├── workouts/page.tsx           # Workout history list
│   ├── workouts/[id]/page.tsx      # Workout detail
│   ├── analytics/page.tsx          # Progress charts
│   └── feed/page.tsx               # Social feed
├── components/
│   ├── Navigation.tsx              # Top nav with auth
│   ├── WorkoutCard.tsx             # Compact workout summary
│   ├── ExerciseChart.tsx           # Recharts line chart
│   ├── PRBadge.tsx                 # Personal record display
│   └── StatCard.tsx                # Key metric card
└── lib/
    └── supabase.ts                 # Supabase client + types
```

## Environment Variables

| Variable | Description |
|---|---|
| `NEXT_PUBLIC_SUPABASE_URL` | Your Supabase project URL |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | Supabase anonymous key |

## Supabase Setup

1. Create a Supabase project
2. Enable Google OAuth in Authentication → Providers
3. Set the site URL to your domain
4. Add redirect URL: `https://yourdomain.com/dashboard`

See the iOS app's Supabase schema for table definitions.
