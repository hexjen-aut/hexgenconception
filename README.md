# Faby — Marketplace Beauté Maroc

> Next.js 14 · Supabase · Vercel · Stripe

---

## Stack technique

| Couche | Tech |
|--------|------|
| Frontend | Next.js 14 (App Router) |
| Base de données | Supabase (PostgreSQL) |
| Auth | Supabase Auth |
| Storage | Supabase Storage |
| Paiement | Stripe |
| Hébergement | Vercel (région Paris cdg1) |
| Emails | Resend |

---

## Setup local — étapes dans l'ordre

### 1. Cloner et installer

```bash
git clone https://github.com/TON_COMPTE/faby.git
cd faby
npm install
```

### 2. Variables d'environnement

```bash
cp .env.local.example .env.local
```

Remplis `.env.local` avec :
- **Supabase** : Supabase Dashboard > Project Settings > API
- **Stripe** : dashboard.stripe.com > Developers > API keys

### 3. Base de données Supabase

Dans Supabase Dashboard > SQL Editor, exécute le fichier :
```
supabase_migration.sql
```

Ce fichier crée :
- Toutes les tables (users, pros, services, availability, bookings, reviews, portfolios, notifications)
- Les triggers (auto-create user, recalcul rating)
- Toutes les RLS policies
- Les storage buckets (avatars, portfolios)

### 4. Lancer en local

```bash
npm run dev
```

Ouvre [http://localhost:3000](http://localhost:3000)

---

## Déploiement Vercel

### 1. Push sur GitHub

```bash
git init
git add .
git commit -m "feat: initial Faby setup"
git remote add origin https://github.com/TON_COMPTE/faby.git
git push -u origin main
```

### 2. Connecter à Vercel

1. Aller sur [vercel.com](https://vercel.com)
2. "New Project" > Importer le repo GitHub `faby`
3. Framework : Next.js (auto-détecté)
4. Ajouter les variables d'environnement :
   - `NEXT_PUBLIC_SUPABASE_URL`
   - `NEXT_PUBLIC_SUPABASE_ANON_KEY`
   - `STRIPE_SECRET_KEY`
   - `STRIPE_WEBHOOK_SECRET`
   - `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY`
5. Deploy !

### 3. Domaine custom (faby.ma)

Vercel Dashboard > Settings > Domains > Ajouter `faby.ma`

---

## Structure du projet

```
faby/
├── src/
│   ├── app/                    ← Pages Next.js (App Router)
│   │   ├── page.tsx            ← Homepage
│   │   ├── layout.tsx          ← Root layout
│   │   ├── login/              ← Auth
│   │   ├── register/           ← Inscription
│   │   ├── pros/               ← Liste des pros
│   │   ├── pro/[id]/           ← Profil d'une pro
│   │   ├── booking/[proId]/    ← Réservation
│   │   ├── dashboard-pro/      ← Espace pro
│   │   ├── dashboard-client/   ← Espace client
│   │   └── admin/              ← Admin panel
│   ├── components/
│   │   ├── ui/                 ← Composants réutilisables
│   │   ├── layout/             ← Navbar, Footer
│   │   ├── pro/                ← Cards pro, portfolio
│   │   └── booking/            ← Formulaire réservation
│   ├── lib/
│   │   └── supabase/           ← Client, server, middleware
│   ├── hooks/                  ← Custom React hooks
│   ├── types/                  ← TypeScript types
│   └── styles/
│       └── globals.css         ← Design system Faby
├── supabase_migration.sql      ← Migration DB complète
├── vercel.json                 ← Config Vercel
└── .env.local.example          ← Template variables d'env
```

---

## Design System Faby

| Token | Valeur |
|-------|--------|
| `--faby-rose` | `#E8527A` |
| `--faby-gold` | `#C9963C` |
| `--bg` | `#0C0A0F` |
| `--surface` | `#13101A` |
| `--font-display` | Playfair Display (serif italic) |
| `--font-body` | DM Sans |

---

## Commission

8% prélevée par Faby sur chaque transaction.
`commission = total_price * 0.08`
