# CLAUDE.md — Resident Personal Allowance Ledger

Instructions for Claude when working on this repository. Read this first, every session.

## Who I am and how to work with me

- I'm Paul, admin at **Cosham Court care home**. I'm not a developer.
- Explain things in plain English. Avoid jargon, or explain it when you have to use it.
- **Before making any change, tell me briefly what you plan to do and why**, and point out any risk to data, security or day-to-day use. For anything bigger than a small fix, wait for my OK.
- After a change, give me a short summary: what changed, what I should check, and whether anything needs doing in Supabase (for example, SQL to run).
- If you think a request is a bad idea or there's a simpler way to do it, say so.

## What this app is

A web app the care home uses to record residents' personal allowance (petty cash) accounts.

- **Admin and Manager** (office/management) record cash in and out, print signed A4 ledger sheets, draft top-up emails to families, run backups and view the audit log. Both roles have identical permissions and are kept separate only so the ledger can show who made each entry.
- **Staff** (care staff) see one read-only screen: Room, Name and Balance.
- Live site: https://coshamcourt.github.io/Ledger/
- See `README.md` (overview) and `DOCS.md` (full technical and admin reference). **Keep both up to date** whenever a change affects what they describe.

This is real financial data about vulnerable people, and it is checked by inspectors and families. Accuracy, an audit trail and privacy come before convenience or new features.

## How it's built (keep it this way)

- **One HTML file, no build step.** React, ReactDOM, supabase-js and Tailwind load from CDNs. Don't add npm, bundlers, frameworks or extra files unless I specifically agree.
- **Supabase** holds all data and logins. `supabase-schema.sql` is the single source of truth for the database structure and security policies.
- **GitHub Pages** serves the site from the `main` branch.

### Branches and file names

- Work happens on a working branch (currently `claude/resident-allowance-supabase-j37leq`). On `main`, which is the live site, the same code is served by GitHub Pages.
- The app is `index.html` on both branches, so going live is a straight copy with no renaming.
- Pushing to `main` puts a change live within a minute or two. **Never push to `main` without my explicit OK.** When I approve going live, copy `index.html` from the working branch to `main`.

## Non-negotiable rules

1. **This repository is public.** Never commit resident names, family contact details, email addresses, passwords, bank/BACS details, backup files or any real data. Test data must be obviously fake.
2. **Never add the Supabase service role key.** The publishable (anon) key in the HTML is intentional and safe. The service role key is not.
3. **Security is enforced by the database, not the screens.** Any new table, view or feature must have Row Level Security policies in `supabase-schema.sql`. Hiding a button is never enough on its own.
   - Anonymous users get nothing.
   - Staff may only read `balance_summary`.
   - All Admin/Manager access goes through the single `is_admin()` function. Don't create a second way of checking roles.
4. **The audit log is append-only.** Never grant update or delete on `audit_log`. Every change to residents or transactions must be logged with who, what and when. Deletions must record the full details of what was deleted.
5. **Balances are always calculated from transactions** and never stored as a separate figure.
6. **Sensitive settings live in the database, not the code.** Bank details stay in `org_settings` (Admin-only) and are fetched after login.
7. **Database changes need to be run in Supabase by hand.** Pushing code does not change the database. Whenever you change `supabase-schema.sql`, also give me the exact SQL to paste into the Supabase SQL Editor, and say whether it's safe to run on the live database with existing data.
8. **Don't break existing records or backups.** Changes must keep working with existing data and with JSON backup files made by earlier versions. Remember that *Restore from Backup* replaces all data.

## Behaviour to preserve

- On screen, newest transactions are at the top. Printed ledgers stay oldest-first, with the running balance building down the page.
- The top-up email still works if bank details are missing; it asks the family to contact the office instead.
- The app must work on PCs, tablets and phones in any current browser.
- UK conventions: £, DD/MM/YYYY dates, British spelling.

## Future plans (not built yet — don't start without my OK)

These are being considered. Don't build them unless I ask, but avoid choices now that would make them harder later.

- **Family logins.** A new `family` role so a family member can log in and see only their own resident's balance and transactions. This would need a table linking family accounts to residents, RLS policies so a family account can never see another resident, and rules for who qualifies and how access is removed. Treat this as a data protection and safeguarding change, not just a feature.
- **Online top-ups (e.g. Stripe).** Families paying into a resident's allowance by card. This needs server-side code (e.g. a Supabase Edge Function and a Stripe webhook) to confirm payments before any transaction is recorded. Stripe secret keys must never go in this repo or the HTML file. Card fees, refunds and reconciliation need agreeing with management first.

Other projects, such as the reception TV display, are separate and have their own repositories. Don't add them here.

## Before saying a change is done

- Check the change doesn't let Staff, or a logged-out user, see anything new.
- Check printing still works if the change touches ledgers or the balance summary.
- Check nothing sensitive has been added to the repo.
- Update `DOCS.md` / `README.md` if needed.
- Remind me to hard-refresh (`Ctrl`+`Shift`+`R`) when checking the live site.
