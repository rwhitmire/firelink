# Firelink

A scrollable-tiling desktop for Fedora, built on [niri](https://github.com/YaLTeR/niri):
Waybar, fuzzel menus, mako, swaylock/swayidle, a volume/brightness OSD, clipboard
history, night light, screenshots and recording, all themed with one
[Catppuccin](https://catppuccin.com) flavor you can switch at any time.

An [Estus Labs](https://estuslabs.com) project. Site: https://firelink.estuslabs.com

## Install

On Fedora 44, as your normal user. Workstation, a spin or a bare Server or
minimal install all work: GNOME isn't needed, and if it's there it's left alone.
For a new machine, the site has
[steps for starting from scratch](https://firelink.estuslabs.com/#scratch):
Workstation if you want GNOME too, or the Everything netinstall with Minimal
Install for niri alone.

```bash
curl -fsSL https://firelink.estuslabs.com/install | bash
```

That clones this repo into `~/.local/share/firelink` and runs `install.sh`, which:

1. installs the Fedora packages in `packages/dnf.txt` that are missing, plus,
   in a VM, its guest agent, so the screen follows the VM window's size (its
   per-session part stays off in niri, where it puts the pointer in the wrong
   place).
   Alacritty is the terminal, Nautilus the file manager (**Mod+E**) and
   Firefox the browser (**Mod+B**); no other apps are installed.
2. sets up a login screen if the machine has none (Server, minimal): greetd with
   tuigreet, which starts niri. GDM or another display manager is kept as is.
   This and the packages are the only steps that use sudo.
3. runs any new migrations: one-off fixes for installs made before a change to
   Firelink (see `migrations/`)
4. downloads [Satty](https://github.com/Satty-org/Satty) into `~/.local/bin` and
   the wallpapers into `wallpapers/`, each pinned and checked by sha256
5. links the `firelink` command into `~/.local/bin`
6. creates starter configs in `~/.config` (from `skel/`), only where none exist
7. installs the session services and enables them for niri only
8. applies the theme

Then log out and pick **Niri** at the login screen (or reboot, if Firelink just
set one up). Re-running is safe; every step
skips what's already done.

## Using it

- **Mod+Space** (or the Fedora logo in the bar) opens the Firelink menu: apps,
  screenshots and recording, toggles for do not disturb, night light and the
  bar, theme, clipboard, Wi-Fi, Bluetooth, default browser, keybinds, update
  and power
- **Browser** in the Firelink menu lists the browsers you have installed and
  makes the one you pick the default, for links and **Mod+B**
- Click the network in the bar for the Wi-Fi menu (nearby networks, passwords
  asked in fuzzel; hidden and enterprise networks and VPNs open
  nm-connection-editor), or the Bluetooth icon to connect and pair devices
  (pairing codes are shown or asked for in fuzzel)
- **Mod+N** dismisses the latest notification, **Mod+Shift+N** all of them, and
  **Mod+Ctrl+N** toggles do not disturb (only critical notifications show until
  it's off; click the bell in the bar to turn it off)
- `firelink theme [latte|frappe|macchiato|mocha]` switches the flavor
  (or **Mod+Ctrl+Shift+T**)
- `firelink update` pulls the latest Firelink and re-runs the installer, or
  says it's up to date when there's nothing new (`--force` re-runs it anyway,
  to repair an install). When there's an update, an icon shows in the bar (its
  tooltip lists what's new); click it, or **Update** in the Firelink menu, to
  run it
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

Set your monitors in `~/.config/niri/config.kdl` (names and modes from
`niri msg outputs`; try a setting first with `niri msg output <name> scale 1.5`).
For your own wallpaper, copy an image to `~/.config/firelink/wallpaper` and run
`systemctl --user restart firelink-swaybg`; it stays across theme switches. The
site has [guides for both](https://firelink.estuslabs.com/#displays).

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
| `firelink-waybar-resume` | restarts waybar after resume, which waybar 0.15 can hang on |
| `firelink-update-check.timer` | `git fetch` 2 minutes after login and every 6 hours; shows the update icon |

## Website

`site/` is the static site at firelink.estuslabs.com, served by a Cloudflare
Worker with static assets (`wrangler.jsonc`; no code and no build step).
`site/install` is the bootstrap script that `curl … | bash` runs, and
`site/_headers` serves it as uncached plain text. Preview locally with
`npx wrangler dev`.

## Credits

Wallpapers by [orangc](https://github.com/orangci/walls-catppuccin-mocha),
downloaded at install time. Colors by [Catppuccin](https://catppuccin.com).
