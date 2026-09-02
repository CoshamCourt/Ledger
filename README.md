# Resident Personal Allowance Ledger

A web app for recording and tracking residents' personal allowance (petty cash) accounts at Cosham Court Nursing Home. Management record cash in and out and print signed ledger sheets; care staff can check balances at a glance.

## Running it

**Open https://coshamcourt.github.io/Ledger/ and log in.** Nothing to install — it runs in any current browser on a PC, tablet or phone, and needs an internet connection.

Your login determines what you see. If you're told your account hasn't been given access yet, it needs a role assigning — see [DOCS.md](DOCS.md#adding-a-user).

## Key features

- **Per-resident ledgers** — cash in and out with a running balance, receipt numbers, and A4 print-outs for signing, plus a daily balance summary for all residents.
- **Three access levels** — Admin and Manager have full access; Staff see only a read-only list of room, name and balance. This is enforced by the database itself, not just hidden in the app.
- **Permanent audit log** — every change is recorded with who made it and when, including the full details of anything deleted. Entries can't be edited or erased from inside the app.
- **Top-up emails** — drafts an email to a resident's family requesting a top-up, with the bank details filled in automatically.
- **Bulk entries and backups** — apply one transaction across many residents at once, and download a complete copy of the data whenever you want.

## More information

See **[DOCS.md](DOCS.md)** for how it's built, the security model, the database structure, how to add users or change the bank details, and how to rebuild everything from scratch if needed.
