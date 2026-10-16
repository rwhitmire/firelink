#!/usr/bin/env bash
# Install Firelink, a niri desktop for Fedora: packages, the tools Fedora doesn't
# package, wallpapers, starter configs, session services and theme.
#
#   curl -fsSL https://firelink.estuslabs.com/install | bash   (clones, then runs this)
#   ./install.sh                                                (from a checkout)
#
# Run as your normal user; it asks for sudo only to install missing packages
# and, on a machine without a login screen, to set up greetd.
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
# In a VM, its guest agent: without one the screen doesn't follow the size of
# the VM's window (Workstation installs these; a minimal install doesn't)
case $(systemd-detect-virt --vm 2>/dev/null) in
    kvm|qemu) pkgs+=(spice-vdagent) ;;               # GNOME Boxes, virt-manager
    vmware)   pkgs+=(open-vm-tools-desktop) ;;
    oracle)   pkgs+=(virtualbox-guest-additions) ;;
esac
mapfile -t missing < <(rpm -q "${pkgs[@]}" | sed -nE 's/^package (.+) is not installed$/\1/p')
# Older installs may have power-profiles-daemon, which does tuned-ppd's job and
# conflicts with it
if rpm -q --quiet power-profiles-daemon; then
    mapfile -t missing < <(printf '%s\n' "${missing[@]}" | grep -vx -e tuned-ppd -e '')
fi
if [ "${#missing[@]}" -gt 0 ]; then
    note "installing: ${missing[*]}"
    sudo dnf install -y "${missing[@]}"
else
    note "all installed"
fi

step "Login screen"
# GDM (or any other display manager) already lists Niri, so it's left alone. A
# machine without one (Fedora Server, a minimal install) gets greetd.
dm=
if [ -e /etc/systemd/system/display-manager.service ]; then
    dm=$(readlink -f /etc/systemd/system/display-manager.service)
    dm=${dm##*/}
fi
new_login=
if [ -n "$dm" ] && [ "$dm" != greetd.service ]; then
    note "using ${dm%.service}"
else
    mapfile -t missing < <(rpm -q greetd tuigreet | sed -nE 's/^package (.+) is not installed$/\1/p')
    if [ "${#missing[@]}" -gt 0 ]; then
        note "installing: ${missing[*]}"
        sudo dnf install -y "${missing[@]}"
    fi
    # Only replaced while it's the package's default: after that it's the admin's
    verify=$(rpm -V greetd || true)
    if ! grep -q ' /etc/greetd/config.toml$' <<<"$verify"; then
        sudo install -m 644 "$home/config/greetd/config.toml" /etc/greetd/config.toml
        note "set up /etc/greetd/config.toml (tuigreet, starting niri)"
    elif ! grep -q Firelink /etc/greetd/config.toml; then
        note "kept your /etc/greetd/config.toml; its command should start niri-session"
    fi
    if [ "$dm" != greetd.service ]; then
        sudo systemctl enable greetd.service
        new_login=1
    fi
    if [ "$(systemctl get-default)" != graphical.target ]; then
        sudo systemctl set-default graphical.target
        new_login=1
    fi
    note "using greetd"
fi

step "Migrations"
# One-off fixes for installs made before a change to Firelink (a renamed unit, a
# moved file). Each runs once, recorded in $state/migrations; one that fails
# stops the install and runs again next time. See migrations/README.md.
mkdir -p "$state/migrations"
ran=()
for migration in "$home"/migrations/*.sh; do
    [ -e "$migration" ] || continue
    name=${migration##*/}
    [ -e "$state/migrations/$name" ] && continue
    note "running ${name%.sh}"
    firelink=$home state=$state config=$config bash -euo pipefail "$migration"
    touch "$state/migrations/$name"
    ran+=("$name")
done
if [ "${#ran[@]}" -eq 0 ]; then note "none to run"; fi

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
    [ -f "$unit" ] || continue
    install -D -m 644 "$unit" "$config/systemd/user/${unit##*/}"
    grep -q '^WantedBy=' "$unit" && units+=("${unit##*/}")
done
# Drop-ins that change other packages' user units (<unit>.d/firelink.conf)
for dropin in "$home"/systemd/*.d/*.conf; do
    [ -e "$dropin" ] || continue
    install -D -m 644 "$dropin" "$config/systemd/user/${dropin#"$home"/systemd/}"
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

# The commit this run installed, so `firelink update` can skip the installer when
# nothing new was pulled (only after a successful run, so a failed one is retried)
if [ -d "$home/.git" ]; then
    git -C "$home" rev-parse HEAD > "$state/installed"
fi

step "Done"
if [ "${XDG_CURRENT_DESKTOP:-}" = niri ]; then
    # Already in niri (an update): start anything new, restart the rest so
    # changed units take effect. While the screen is locked (an update over
    # SSH) only start them, leaving the lock screen alone.
    if pgrep -u "$USER" -x swaylock >/dev/null; then
        systemctl --user start "${units[@]}"
        note "Firelink is up to date (the screen is locked; changed services restart at your next login)."
    else
        systemctl --user restart "${units[@]}"
        # Re-checks the drop-in's condition, so a running agent stops
        systemctl --user try-restart spice-vdagent.service 2>/dev/null || true
        note "Firelink is up to date."
    fi
elif [ -n "$new_login" ]; then
    note "Reboot, then log in at the new login screen; it starts niri."
else
    note "Log out and pick Niri at the login screen."
fi
