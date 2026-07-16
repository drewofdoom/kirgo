#!/bin/bash

set -ouex pipefail

log() { echo "=== $* ==="; }
RELEASE="$(rpm -E %fedora)"

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

# Update os-release metadata for Kirgo
if [ -f /usr/lib/os-release ]; then
    # Source the file to load the existing $OSTREE_VERSION variable into the shell
    source /usr/lib/os-release

    # Fallback defaults in case the environment variables aren't set during manual builds
    BUILD_IMAGE_ID="${IMAGE_ID:-kirgo}"
    BUILD_VARIANT_ID="${VARIANT_ID:-kirgo}"

    sed -i \
        -e "s|^NAME=.*|NAME=\"Kirgo\"|" \
        -e "s|^PRETTY_NAME=.*|PRETTY_NAME=\"Kirgo (Version: ${OSTREE_VERSION})\"|" \
        -e "s|^DEFAULT_HOSTNAME=.*|DEFAULT_HOSTNAME=\"kirgo\"|" \
        -e "s|^ID=.*|ID=\"kirgo\"|" \
        -e "s|^IMAGE_ID=.*|IMAGE_ID=\"${BUILD_IMAGE_ID}\"|" \
        -e "s|^VARIANT_ID=.*|VARIANT_ID=\"${BUILD_VARIANT_ID}\"|" \
        -e "s|^HOME_URL=.*|HOME_URL=\"https://github.com/drewofdoom/kirgo\"|" \
        -e "s|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL=\"https://github.com/drewofdoom/kirgo\"|" \
        -e "s|^SUPPORT_URL=.*|SUPPORT_URL=\"https://github.com/drewofdoom/kirgo/issues/\"|" \
        -e "s|^BUG_REPORT_URL=.*|BUG_REPORT_URL=\"https://github.com/drewofdoom/kirgo/issues/\"|" \
        /usr/lib/os-release
else
    echo "Warning: /usr/lib/os-release not found!"
fi

# Define what MUST stay (used for both DNF exclusion and post-removal verification)
declare -a KEEP_PACKAGES=(
    "nautilus"
    "nautilus-extensions"
    "totem-pl-parser"
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

# 1. BULK REMOVAL FILTERING WITH PROTECTION
log "Filtering packages for removal..."
INSTALLED_PKGS=$(rpm -qa --queryformat '%{NAME}\n')

# Format critical packages into an --exclude rule array for DNF
declare -a EXCLUDE_ARGS=()
for pkg in "${KEEP_PACKAGES[@]}"; do
    EXCLUDE_ARGS+=( "--exclude=$pkg" )
done

declare -a VALID_RM_PKGS=()
for pkg in "${RM_PKGS[@]}"; do
    if echo "$INSTALLED_PKGS" | grep -Fq -x "$pkg"; then
        VALID_RM_PKGS+=("$pkg")
    fi
done

if [[ ${#VALID_RM_PKGS[@]} -gt 0 ]]; then
    log "Removing existing target packages (protecting critical system packages)..."
    # Pass the exclusion arguments along with the target packages to remove
    dnf5 remove -y "${EXCLUDE_ARGS[@]}" "${VALID_RM_PKGS[@]}" || exit 1
else
    log "No target packages are currently installed. Skipping removal."
fi


# 2. BULK KEEP-PACKAGE VERIFICATION
declare -a MISSING_PACKAGES=()
# Re-query RPM database once to verify what we kept
INSTALLED_PKGS=$(rpm -qa --queryformat '%{NAME}\n')

for pkg in "${KEEP_PACKAGES[@]}"; do
    if ! echo "$INSTALLED_PKGS" | grep -Fq -x "$pkg"; then
        MISSING_PACKAGES+=("$pkg")
    fi
done

if [ ${#MISSING_PACKAGES[@]} -gt 0 ]; then
    log "Reinstalling missing critical packages: ${MISSING_PACKAGES[*]}"
    dnf5 install -y "${MISSING_PACKAGES[@]}"
else
    log "All critical packages are safely installed."
fi


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
    papirus-icon-theme

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

# Make group scripts executable
chmod +x /usr/bin/greeter-group-setup
chmod +x /usr/bin/realtime-group-setup

# Setup services
systemctl enable greetd.service
systemctl enable podman.socket
systemctl enable greeter-group-setup.service
systemctl enable realtime-group-setup.service
