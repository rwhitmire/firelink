# AGENTS.md

Firelink: a niri desktop for Fedora, installed with
`curl -fsSL https://firelink.estuslabs.com/install | bash`. `README.md` is the
user-facing description; this file is what an agent needs to change it safely.

## Layout

- Installed by cloning this repo to `~/.local/share/firelink`. Every config, unit
  and keybind refers to that path. On a development machine it's a symlink to
  the checkout (`install.sh` makes it when run from elsewhere), so edits here
  are live.
- `install.sh` is the installer; `site/install` is the bootstrap that `curl | bash`
  runs (clone or pull, then `install.sh`). `bin/firelink` is the user's command
  (`theme`, `update`).
- `config/<app>/` holds Firelink's defaults. `skel/<app>/` holds the starter
  configs `install.sh` copies into `~/.config` when missing; they only include
  the defaults. Users own their `~/.config` files, so never change behavior by
  editing `skel/` (existing users never get it); change `config/` instead.
- `bin/` has the scripts the binds, bar and units call: `theme-set`,
  `theme-menu`, `wallpaper`, `osd`, `clipboard-menu`, `bluetooth-menu`,
  `power-menu`, `screenshot`, `screenrecord`, `peripheral-battery-watch`.
- `systemd/` has the units, named `firelink-*`, `WantedBy=niri.service`.
  `install.sh` copies them (never links: `systemctl disable` deletes a linked
  unit file) and attaches Fedora's waybar and mako units with `add-wants`.
  niri spawns nothing at startup, so add new daemons as units here.
- `theme/palettes/`, `theme/templates/`, `theme/wallpapers.txt`: see Theme below.
- `packages/dnf.txt`: the Fedora packages `install.sh` installs.
- `site/`: the static website, served by a Cloudflare Worker with static assets
  (`wrangler.jsonc` points it at `site/`; no build step). Preview with
  `npx wrangler dev`.

## Rules

- **Only what the desktop needs to work.** No other apps (no browsers, chat,
  music, games, Flatpaks), not even as an opt-in. Alacritty is the only
  terminal; don't add or reference another one. Neovim and its build tools stay.
- **Never overwrite a user's file in `~/.config`.** `install.sh` creates
  `skel/` files only when missing. Generated theme files (`theme.kdl`,
  `theme.css`, `theme.toml`, `theme.ini`, mako's `theme`, `wob.ini`, swaylock's
  `config`) are the exception: `theme-set` owns those.
- **Theme files are generated.** Edit `theme/templates/<app>` and run
  `firelink theme`; never edit the generated copy. To theme a new app, add a
  template and an entry in `theme-set`'s `dest` map, and include the generated
  file from the app's `config/` defaults (after the defaults, so it wins).
- **Wallpapers aren't redistributed** (their repo has no license).
  `theme/wallpapers.txt` pins them by commit and sha256; `install.sh` downloads
  them into the gitignored `wallpapers/`. Without one, `bin/wallpaper` uses the
  palette's base color.
- **Keep it hardware-agnostic.** No hard-coded batteries, AC adapters, output
  names or vendor features. Ask UPower (`busctl`, `upower`) and skip what the
  hardware doesn't have. Monitor layouts belong in the user's config.
- **Keep it out of GNOME.** Units are wanted by `niri.service`, never
  `graphical-session.target`.
- **`install.sh` must stay safe to re-run** (`firelink update` does exactly
  that) and use sudo only for `dnf install` of missing packages.
- **Pin downloads.** Anything fetched (Satty, wallpapers) has a fixed version
  or commit and a sha256 check.
- Don't run `sudo`; give the user the exact command instead.

## Checking changes

- niri: `niri validate -c config/niri/firelink.kdl` (and the user's
  `~/.config/niri/config.kdl`). niri reloads on save.
- waybar: `timeout 3 waybar -l debug` and look for errors, then
  `pkill -USR2 -x waybar`.
- Units: `systemd-analyze --user verify systemd/*`. Shell variables in
  `ExecStart` must be written `$$var` (systemd expands `$var` itself).
- Scripts: `bash -n`. The installer: run `./install.sh`; on a machine that has
  everything, it shouldn't prompt for sudo or create/change anything but the
  copied units and theme files.
- New packages: `dnf repoquery --available <name>` before adding them.
- Site: `npx wrangler dev`, then check `/install` comes back as `text/plain`.
  Render it with
  `firefox --headless --no-remote --profile <empty dir> --window-size=1280,2400 --screenshot out.png file://$PWD/site/index.html`,
  and again at `--window-size=390,1800` for phones; no horizontal overflow.

## Style

- Bash scripts start with `#!/usr/bin/env bash` and a comment saying what the
  script does and what opens it (keybind, waybar click or unit). fuzzel menus
  use `--dmenu` with an icon `--prompt`.
- Config comments explain *why*, not what the line does.
- When you add a bind, menu, unit or install step, update `README.md`, and the
  site if it's user-visible.

## Committing

Subjects are short, in the imperative, with an `area:` prefix for changes to one
part (`niri:`, `waybar:`, `install:`, `site:`, `theme:`); a plain sentence for
changes across several. Add a body for anything non-obvious.
