# Migrations

One-off fixes for existing installs when Firelink changes in a way that leaves
something behind: a renamed or removed unit, a moved state file, a generated
file that's no longer used. `install.sh` (so `firelink update` too) runs the
ones that haven't run yet, in name order, and records each in
`~/.local/state/firelink/migrations/`.

- Name them `YYYYMMDDHHMM-what-it-does.sh` (`date +%Y%m%d%H%M`).
- New installs run every migration too, so each one checks for the old state
  and does nothing without it.
- They run with `bash -euo pipefail` and get `$firelink` (the install),
  `$state` (`~/.local/state/firelink`) and `$config` (`~/.config`).
- Once one is pushed, don't edit or rename it (machines that ran it won't run
  it again); add another.
- No sudo, and never overwrite or delete a user's file in `~/.config`. Generated
  theme files and the copied `firelink-*` units are fine to remove.
- One that fails stops the install; it runs again on the next one.
