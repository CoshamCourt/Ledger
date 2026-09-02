Resident Personal Allowance Ledger
A web app for recording and tracking residents' personal allowance (petty cash) accounts at Cosham Court Nursing Home.
Staff see resident balances at a glance; managers record cash in and out, print signed ledger sheets, and email families to request top-ups. Every change is recorded in a permanent audit log.
Live app: https://coshamcourt.github.io/Ledger/
Access levels
	Admin / Manager	Staff
View balances	Yes	Yes
View transaction history, edit records	Yes	No
Print ledgers	Full	Summary only
Email families, back up data	Yes	No
Staff see a read-only Room / Name / Balance list only — no transaction history or contact details. This is enforced by the database itself, not just hidden in the app (see `docs/OPERATIONS.md` for details).
How it's built
Single HTML file, no build step — edit and push, nothing to compile.
React and Tailwind load from a CDN, so there's no `node_modules` in this repo.
Supabase (hosted Postgres + login accounts) holds all the data; the app talks to it directly from the browser.
Hosted free on GitHub Pages from `main`.
Security in one sentence
Every table has Postgres Row Level Security policies, so even a direct database query with the public key returns nothing beyond what that user's role is allowed to see — the app's screens aren't what's keeping data safe, the database is. The key visible in the source code is Supabase's public "anon" key, designed to be published; it grants no access on its own.
Making changes
`main` is live; GitHub Pages republishes within a minute or two of a push. Test on a working branch first. Code and data are stored separately, so app changes never touch resident records.
---
Full setup, database schema, adding users, backups, and disaster recovery steps: `docs/OPERATIONS.md`.
