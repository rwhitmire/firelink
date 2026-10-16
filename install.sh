#!/usr/bin/env bash
# Install Firelink, a niri desktop for Fedora: packages, the tools Fedora doesn't
# package, wallpapers, starter configs, session services and theme.
#
#   curl -fsSL https://firelink.estuslabs.com/install | bash   (clones, then runs this)
#   ./install.sh                                                (from a checkout)
#
# Run as your normal user; it asks for sudo only to install missing packages.
# Safe to re-run: every step skips what's already done (`firelink update` does
# exactly that). It never overwrites your own configs in ~/.config.
set -euo pipefail

src=$(cd "$(dirname "$0")" && pwd)
home=$HOME/.local/share/firelink   # every config and unit refers to this path
state=${XDG_STATE_HOME:-$HOME/.local/state}/firelink
config=${XDG_CONFIG_HOME:-$HOME/.config}

# Satty (screenshot annotation) isn't in Fedora: pinned release, checked by sha256
satty_version=0.22.0
satty_url=https://github.com/Satty-org/Satty/releases/download/v$satty_version/satty-x86_64-unknown-linux-gnu.tar.gz
satty_sha256=eb7a028c4a5ce331c2f355add8e2b807a7d697fe4495f7e1965786a4f6bcd5b8

wallpaper_base=https://raw.githubusercontent.com/orangci/walls-catppuccin-mocha

step() { printf '\n\033[1;33m==> %s\033[0m\n' "$*"; }
note() { printf '    %s\n' "$*"; }

# Package names from a list file, without comments and blank lines
list() { sed -E 's/#.*//; s/[[:space:]]+$//; /^$/d' "$1"; }

if [ "$(id -u)" -eq 0 ]; then
    echo "firelink: run as your normal user, not root (it uses sudo where needed)" >&2
    exit 1
fi
if ! grep -q '^ID=fedora$' /etc/os-release; then
    echo "firelink: Firelink is for Fedora (package names and paths are Fedora's)" >&2
    exit 1
fi

step "Firelink files"
# Everything refers to ~/.local/share/firelink. Running from a checkout somewhere
# else (e.g. while working on Firelink) links that path to the checkout.
if [ "$src" != "$home" ] && [ "$(readlink -f "$home")" != "$src" ]; then
    if [ -e "$home" ] && [ ! -L "$home" ]; then
        echo "firelink: $home already exists and isn't this checkout ($src)" >&2
        exit 1
    fi
    mkdir -p "$(dirname "$home")"
    ln -sfn "$src" "$home"
    note "linked $home -> $src"
else
    note "using $home"
fi

step "Fedora packages"
mapfile -t pkgs < <(list "$home/packages/dnf.txt")
mapfile -t missing < <(rpm -q "${pkgs[@]}" | sed -nE 's/^package (.+) is not installed$/\1/p')
if [ "${#missing[@]}" -gt 0 ]; then
    note "installing: ${missing[*]}"
    sudo dnf install -y "${missing[@]}"
else
    note "all ${#pkgs[@]} installed"
fi

step "Satty"
mkdir -p ~/.local/bin
if [ -x ~/.local/bin/satty ] && ~/.local/bin/satty --version 2>/dev/null | grep -qF "$satty_version"; then
    note "satty $satty_version already installed"
else
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/satty.tar.gz" "$satty_url"
    echo "$satty_sha256  $tmp/satty.tar.gz" | sha256sum -c --quiet
    tar -xzf "$tmp/satty.tar.gz" -C "$tmp"
    install -m 755 "$tmp/satty" ~/.local/bin/satty
    rm -rf "$tmp"
    note "installed satty $satty_version"
fi

step "Wallpapers"
commit=$(sed -nE 's/^# commit ([0-9a-f]+)$/\1/p' "$home/theme/wallpapers.txt")
mkdir -p "$home/wallpapers"
while read -r sha file; do
    dest=$home/wallpapers/$file
    if [ -f "$dest" ] && echo "$sha  $dest" | sha256sum -c --quiet 2>/dev/null; then
        continue
    fi
    if curl -fsSL -o "$dest.tmp" "$wallpaper_base/$commit/$file" &&
        echo "$sha  $dest.tmp" | sha256sum -c --quiet; then
        mv "$dest.tmp" "$dest"
        note "downloaded $file"
    else
        rm -f "$dest.tmp"
        note "couldn't download $file; that flavor will use a plain background"
    fi
done < <(list "$home/theme/wallpapers.txt")

step "The firelink command"
ln -sfn "$home/bin/firelink" ~/.local/bin/firelink
note "~/.local/bin/firelink (firelink help)"

step "Your configs"
# Starter configs that include Firelink's defaults. Only created when missing:
# once they exist they're yours, and updates change only what they include.
for skel in $(cd "$home/skel" && find . -type f -printf '%P\n'); do
    dest=$config/$skel
    if [ -e "$dest" ]; then
        note "kept ~/.config/$skel"
        continue
    fi
    mkdir -p "$(dirname "$dest")"
    sed "s|@HOME@|$HOME|g" "$home/skel/$skel" > "$dest"
    note "created ~/.config/$skel"
done

step "Session services"
# Copied, not linked: systemd deletes a linked unit file when it's disabled.
# Wanted by niri.service, not graphical-session.target, which GNOME starts too.
units=()
for unit in "$home"/systemd/*; do
    install -D -m 644 "$unit" "$config/systemd/user/${unit##*/}"
    grep -q '^WantedBy=' "$unit" && units+=("${unit##*/}")
done
systemctl --user daemon-reload
systemctl --user enable "${units[@]}"
# Fedora's waybar and mako units say WantedBy=graphical-session.target, so
# they're attached to niri instead of enabled
systemctl --user add-wants niri.service waybar.service mako.service
note "enabled: ${units[*]} waybar.service mako.service"

step "Theme"
mkdir -p "$state"
"$home/bin/theme-set"
note "Catppuccin $(cat "$state/flavor") (switch with Mod+Ctrl+Shift+T or firelink theme <flavor>)"

step "Done"
if [ "${XDG_CURRENT_DESKTOP:-}" = niri ]; then
    # Already in niri (an update): start anything new, restart the rest so
    # changed units take effect
    systemctl --user restart "${units[@]}"
    note "Firelink is up to date."
else
    note "Log out and pick Niri at the login screen."
fi
