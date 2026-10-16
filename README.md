# Firelink

A scrollable-tiling desktop for Fedora, built on [niri](https://github.com/YaLTeR/niri):
Waybar, fuzzel menus, mako, swaylock/swayidle, a volume/brightness OSD, clipboard
history, night light, screenshots and recording, all themed with one
[Catppuccin](https://catppuccin.com) flavor you can switch at any time.

An [Estus Labs](https://estuslabs.com) project. Site: https://firelink.estuslabs.com

## Install

On Fedora 44 (with GDM), as your normal user:

```bash
curl -fsSL https://firelink.estuslabs.com/install | bash
```

That clones this repo into `~/.local/share/firelink` and runs `install.sh`, which:

1. installs the Fedora packages in `packages/dnf.txt` that are missing (the only
   step that uses sudo). Alacritty is the only terminal, and no other apps are
   installed.
2. downloads [Satty](https://github.com/Satty-org/Satty) into `~/.local/bin` and
   the wallpapers into `wallpapers/`, each pinned and checked by sha256
3. links the `firelink` command into `~/.local/bin`
4. creates starter configs in `~/.config` (from `skel/`), only where none exist
5. installs the session services and enables them for niri only
6. applies the theme

Then log out and pick **Niri** at the login screen. Re-running is safe; every step
skips what's already done.

## Using it

- `firelink theme [latte|frappe|macchiato|mocha]` switches the flavor
  (or **Mod+Ctrl+Shift+T**)
- `firelink update` pulls the latest Firelink and re-runs the installer
- **Mod+Shift+/** lists the keybinds

## Your configs

Firelink's defaults live in `~/.local/share/firelink/config/`. The files in
`~/.config` are yours: they include Firelink's and add your changes on top, so
updates never overwrite them.

| App | Your file | How it pulls in Firelink |
| --- | --- | --- |
| niri | `~/.config/niri/config.kdl` | `include`; later settings and binds override |
| waybar | `~/.config/waybar/config.jsonc`, `style.css` | `"include"`; CSS `@import` |
| fuzzel | `~/.config/fuzzel/fuzzel.ini` | `include=` |
| mako | `~/.config/mako/config` | `include=` (add criteria sections after it) |
| alacritty | `~/.config/alacritty/alacritty.toml` | `import` |
| swayidle | `~/.config/swayidle/config` | none: copy Firelink's there to change it |

Set your monitors in `~/.config/niri/config.kdl` (names from `niri msg outputs`).

## Theme

Colors come from `theme/palettes/<flavor>`. `theme/templates/` holds the color
part of each app's config with `{{color}}` placeholders; `bin/theme-set` renders
them into `~/.config/<app>/theme.*` (included after Firelink's defaults), sets the
wallpaper and GTK's light/dark preference, and reloads what's running. The
current flavor is in `~/.local/state/firelink/flavor`.

Neovim isn't themed by Firelink, but `theme-set` sends running instances SIGUSR1,
so an `init.lua` can follow along:

```lua
local function apply_theme()
  local f = io.open(vim.fn.expand '~/.local/state/firelink/flavor')
  vim.cmd.colorscheme('catppuccin-' .. (f and f:read '*l' or 'mocha'))
  if f then f:close() end
end
apply_theme()
vim.api.nvim_create_autocmd('Signal', { pattern = 'SIGUSR1', callback = vim.schedule_wrap(apply_theme) })
```

## Session services

Systemd user units in `systemd/`, copied to `~/.config/systemd/user/` and wanted
by `niri.service` (not `graphical-session.target`, which GNOME also starts, so a
GNOME login on the same machine is left alone). Waybar and mako use Fedora's units.

| Unit | What |
| --- | --- |
| `firelink-swayidle` | lock at 5 min, screens off at 6, suspend at 15 on battery |
| `firelink-swaybg` | wallpaper, or the theme's base color without one |
| `firelink-polkit` | password prompts for GUI apps |
| `firelink-cliphist` | clipboard history (**Mod+Ctrl+V**) |
| `firelink-wlsunset` | night light, 4000K from 19:30 to 07:00 |
| `firelink-wob.socket` | volume/brightness OSD |
| `firelink-battery-watch` | low-battery alerts for wireless keyboards and mice |

## Website

`site/` is the static site at firelink.estuslabs.com, deployed by Cloudflare
Pages (build output directory `site`, no build command). `site/install` is the
bootstrap script that `curl … | bash` runs.

## Credits

Wallpapers by [orangc](https://github.com/orangci/walls-catppuccin-mocha),
downloaded at install time. Colors by [Catppuccin](https://catppuccin.com).
