#!/bin/bash

set -ouex pipefail

log() { echo "=== $* ==="; }
RELEASE="$(rpm -E %fedora)"

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

declare -a RM_PKGS=(
    # Fonts
    "google-noto-sans-cjk-vf-fonts"
    "google-noto-sans-mono-cjk-vf-fonts"
    "google-noto-serif-cjk-vf-fonts"
    "google-noto-sans-arabic-vf-fonts"
    "google-noto-sans-naskh-arabic-vf-fonts"
    "google-noto-sans-hebrew-vf-fonts"
    "paktype-naskh-basic-fonts"
    "google-noto-sans-bengali-vf-fonts"
    "google-noto-sans-devanagari-vf-fonts"
    "google-noto-sans-gujarati-vf-fonts"
    "google-noto-sans-gurmukhi-vf-fonts"
    "google-noto-sans-kannada-vf-fonts"
    "google-noto-sans-malayalam-vf-fonts"
    "google-noto-sans-oriya-vf-fonts"
    "google-noto-sans-tamil-vf-fonts"
    "google-noto-sans-telugu-vf-fonts"
    "google-noto-sans-thai-vf-fonts"
    "google-noto-sans-lao-vf-fonts"
    "google-noto-sans-armenian-vf-fonts"
    "google-noto-sans-ethiopic-vf-fonts"
    "google-noto-sans-georgian-vf-fonts"
    "google-noto-sans-khmer-vf-fonts"
    "julietaula-montserrat-fonts"
    "sil-padauk-fonts"
    "rit-meera-new-fonts"
    "rit-rachana-fonts"
    "madan-fonts"
    "stix-fonts"

    # Apps
    "evolution-data-server"
    "evolution-ews-core"
    "evolution-ews-langpacks"
    "epiphany-runtime"
    "cheese"
    "gnome-color-manager"
    "gnome-disk-utility"
    "gnome-software"
    "gnome-software-packagekit-plugin"
    "gnome-weather"
    "gnome-connections"
    "gnome-contacts"
    "gnome-maps"
    "gnome-music"
    "seahorse"
    "gnome-logs"
    "orca"
    "totem"
    "totem-pl-parser"
    "rygel"
    "antiword"
    "evince"
    "gnome-online-accounts"
    "gnome-online-accounts-libs"
    "gnome-remote-desktop"
    "ptyxis"

    # Extra GNOME Core
    "gdm"
    "gnome-shell"
    "gnome-shell-extension-apps-menu"
    "gnome-shell-extension-common"
    "gnome-shell-extension-launch-new-instance"
    "gnome-shell-extension-places-menu"
    "gnome-shell-extension-window-list"
    "gnome-session"
    "gnome-session-wayland-session"
    "mutter"
    "gnome-control-center"
    "gnome-initial-setup"
    "gnome-tour"
    "gnome-user-docs"

    # Bluetooth GUI
    "gnome-bluetooth"
    "blueberry"
)

log "Checking which packages exist..."
declare -a VALID_RM_PKGS=()

for pkg in "${RM_PKGS[@]}"; do
    # Use dnf to check if package exists/is installed
    if dnf5 list installed "$pkg" &>/dev/null; then
        VALID_RM_PKGS+=("$pkg")
        log "✓ $pkg"
    else
        log "⚠ $pkg not found"
    fi
done

# Filter array
RM_PKGS=("${VALID_RM_PKGS[@]}")

log "Removing packages..."
if [[ ${#RM_PKGS[@]} -gt 0 ]]; then
    dnf5 remove -y "${RM_PKGS[@]}" || exit 1
else
    log "Nothing to remove"
fi

# Define what MUST stay
declare -a KEEP_PACKAGES=(
    "nautilus"
    "nautilus-extensions"
    "shared-mime-info"
    "desktop-file-utils"
    "gvfs"
    "gvfs-client"
    "gvfs-fuse"
    "gtk3"
    "gtk4"
    "libadwaita"
    "gsettings-desktop-schemas"
    "dconf"
)

# After all removals, verify and reinstall if needed
for pkg in "${KEEP_PACKAGES[@]}"; do
    if ! rpm -q --quiet "$pkg"; then
        log "Reinstalling critical package: $pkg"
        dnf5 install -y "$pkg"
    fi
done

# Extra repos
log "Enabling COPR repos..."
COPR_REPOS=(
  avengemedia/danklinux
  avengemedia/dms
  rivenirvana/morewaita-icon-theme
  scottames/ghostty
  ulysg/xwayland-satellite
)
for repo in "${COPR_REPOS[@]}"; do
  dnf5 -y copr enable "$repo"
done

log "Adding Terra repo..."
dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release

# Repo priorities (lower = higher priority)
dnf5 -y config-manager setopt '*dms*.priority=1'
dnf5 -y config-manager setopt '*xwayland-satellite*.priority=1'
dnf5 -y config-manager setopt '*ghostty*.priority=1'
dnf5 -y config-manager setopt '*danklinux*.exclude=ghostty*' '*danklinux*.priority=2'
dnf5 -y config-manager setopt 'terra.enabled=1' 'terra*.priority=3' 'terra*.exclude=ghostty matugen*'

# Install packages
PKGS=(
  # Desktop
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
  xwayland-run

  # Niri
  cava
  cliphist
  dankcalendar-git
  danksearch
  dgop
  dms
  dms-cli
  dms-greeter
  niri
  qt6-qtmultimedia
  quickshell

  # Theming
  adw-gtk3-theme
  bibata-cursor-theme
  matugen

  # Terminal
  ghostty
  ghostty-terminfo
  ghostty-shell-integration
  ghostty-fish-completion

  # Containers
  podman-compose
  podman-machine
  podman-tui
)

log "Installing packages..."
dnf5 install -y --setopt=install_weak_deps=False "${PKGS[@]}"

log "Cleaning up..."
dnf5 clean all

# make group scripts executable
chmod +x /usr/bin/greeter-group-setup
chmod +x /usr/bin/realtime-group-setup

# setup services
systemctl enable greetd.service
systemctl enable podman.socket
systemctl enable greeter-group-setup.service
systemctl enable realtime-group-setup.service
