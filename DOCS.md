# Technical & Administrative Documentation

Reference notes for the [Resident Personal Allowance Ledger](README.md).

- [Who can do what](#who-can-do-what)
- [How it's built](#how-its-built)
- [Security](#security)
- [Database structure](#database-structure)
- [Repository contents](#repository-contents)
- [Making changes](#making-changes)
- [Day-to-day admin](#day-to-day-admin)
- [Rebuilding from scratch](#rebuilding-from-scratch)

---

## Who can do what

Access is decided by the role attached to each login account.

| | Admin | Manager | Staff |
|---|---|---|---|
| View resident balances | Yes | Yes | Yes |
| View individual ledgers and transaction history | Yes | Yes | No |
| Add / delete transactions | Yes | Yes | No |
| Add / edit / archive residents | Yes | Yes | No |
| Print ledgers and balance summary | Yes | Yes | Summary only |
| Draft top-up email to family | Yes | Yes | No |
| Back up and restore data | Yes | Yes | No |
| View audit log | Yes | Yes | No |

**Admin and Manager have identical permissions.** They're kept as separate roles only so the ledger can show which kind of user made each entry.

**Staff see one screen only:** a read-only list of Room, Name and Balance. They have no access to transaction history, receipts, family contact details or bank details — not just hidden in the app, but blocked at the database level.

---

## How it's built

Deliberately simple, so it stays maintainable without a developer on hand:

- **One file, no build step.** The whole app is a single HTML file. There's nothing to compile, install or bundle — editing the file and pushing it is all that's needed to release a change.
- **React and Tailwind load from a CDN** at page load, so there are no dependencies committed to this repo and no `node_modules`.
- **[Supabase](https://supabase.com) holds all the data** (a hosted PostgreSQL database with built-in login accounts). The app talks to it directly from the browser.
- **Hosted free on GitHub Pages** from the `main` branch.

Because the data lives in Supabase and the app is just the interface, everyone sees the same live data on any device, and updating the app can never affect resident records.

---

## Security

The important principle: **security is enforced by the database, not by the app's screens.**

Every table has PostgreSQL Row Level Security policies attached. Even if someone bypassed the app entirely and queried the database directly with the public key, the database itself would refuse to return anything they're not entitled to. Hiding a button is not what keeps Staff out of the transaction records — the database rejecting the request is.

Specifically:

- **Logged-out users get nothing.** All access is revoked for anonymous requests.
- **Staff can only read the `balance_summary` view** (room, name, balance). They have no permission on the underlying `residents` or `transactions` tables at all.
- **Admin/Manager access is granted through a single database function**, `is_admin()`, which every policy is built on. Roles can't drift out of step, because there's only one place that decides.
- **No sensitive data is hardcoded in the app.** Bank/BACS details live in the `org_settings` table (Admin-only) and are fetched after login — they are never present in the page source. Resident names and family contact details only ever arrive from the database after logging in. The app starts with an empty resident list.
- **The audit log cannot be tampered with.** It has no update or delete permission granted to anyone, so entries can't be edited or erased from inside the app — including by an Admin.

### About the key in the source code

The app contains a Supabase URL and a "publishable" (anon) key. **This is intentional and safe.** That key only identifies the project; it grants no access on its own. Everything it can reach is governed by the Row Level Security policies above, which require a valid logged-in account. It is designed by Supabase to be published in client-side code.

The service role key — the one that *does* bypass security — is not in this repository and must never be added to it.

Note also that **this repository is public**, so no account email addresses, passwords or bank details should ever be committed to it.

---

## Database structure

Defined in [`supabase-schema.sql`](supabase-schema.sql).

| Object | Purpose |
|---|---|
| `residents` | Name, room, family contact details, archived flag |
| `transactions` | Cash in/out entries linked to a resident: date, reason, type, amount, receipt number, who entered it |
| `user_roles` | Maps each login account to `admin`, `manager` or `staff` |
| `org_settings` | Single row holding the BACS bank details used in the top-up email |
| `audit_log` | Append-only record of every change: who, what, when |
| `balance_summary` | Read-only view exposing only room, name and balance for active residents — the only thing Staff can read |
| `is_admin()` | Helper function returning true for `admin` and `manager`; all access policies are built on it |

Balances are always calculated from the transactions, never stored as a figure that could drift out of step.

---

## Repository contents

| File | What it is |
|---|---|
| `index.html` | The entire application. Served as `index.html` on the `main` branch so the site works from the plain address |
| `supabase-schema.sql` | Database structure and all security policies, for reference or rebuilding from scratch |
| `README.md` | Short overview |
| `DOCS.md` | This file |

---

## Making changes

The `main` branch is what's live. GitHub Pages republishes the site automatically within a minute or two of a change being pushed to `main`.

Changes are developed and tested on a working branch first, then copied across to `main` to go live. If a change appears not to have taken effect, hard-refresh the browser (`Ctrl`+`Shift`+`R`, or `Cmd`+`Shift`+`R` on a Mac) to bypass the cache.

Pushing app changes **never** affects resident data — the code and the data are stored in completely separate places.

---

## Day-to-day admin

### Transaction ordering

On screen, the newest transaction appears at the top so there's no scrolling through a long history. Printed ledgers deliberately keep the traditional oldest-first order with the running balance building down the page.

### Adding a user

Create the account in Supabase → Authentication → Users (tick *Auto Confirm User*), then add its role:

```sql
select id, email from auth.users;   -- copy the new account's id

insert into user_roles (user_id, role) values ('<uuid-from-above>', 'staff')
on conflict (user_id) do update set role = 'staff';
```

Until that role row exists, the account can log in but will be told it hasn't been given access yet.

### Changing the bank details

These are read from `org_settings` and used in the top-up email:

```sql
update org_settings set
  bacs_account_name   = '...',
  bacs_bank_name      = '...',
  bacs_sort_code      = '...',
  bacs_account_number = '...'
where id = 1;
```

If that row is missing or incomplete, the Draft Email still works — it just asks the family to contact the office for bank details instead of printing them.

### Backups

Supabase holds the live data, but the *Backup Data* button downloads a complete JSON copy that you hold yourself. Worth doing regularly and keeping somewhere other than one computer. *Restore from Backup* reads that same file back in — note that it **replaces all data** in the database, and asks for confirmation first.

---

## Rebuilding from scratch

If the Supabase project were ever lost, this is the whole recovery path:

1. Create a new Supabase project.
2. In **SQL Editor**, run the contents of `supabase-schema.sql`.
3. In **Authentication → Users**, create the login accounts (tick *Auto Confirm User*).
4. Add a `user_roles` row for each account, as shown above.
5. Fill in the `org_settings` row:
   ```sql
   insert into org_settings (id, bacs_account_name, bacs_bank_name, bacs_sort_code, bacs_account_number)
   values (1, '...', '...', '...', '...')
   on conflict (id) do update set
     bacs_account_name = excluded.bacs_account_name,
     bacs_bank_name = excluded.bacs_bank_name,
     bacs_sort_code = excluded.bacs_sort_code,
     bacs_account_number = excluded.bacs_account_number;
   ```
6. Update `SUPABASE_URL` and `SUPABASE_ANON_KEY` near the top of `index.html` to point at the new project, and push to `main`.
7. Restore the data from your most recent JSON backup using *Restore from Backup*.

To host it elsewhere, or set up GitHub Pages again: **Settings → Pages → Source: Deploy from a branch → `main` / `/ (root)`**. Any static web host works — it's a single file with no server-side component.
