#!/bin/bash

set -ouex pipefail

log() { echo "=== $* ==="; }
RELEASE="$(rpm -E %fedora)"

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

# enable COPR repos
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

# Terra Repo
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
  matugen
  nwg-look

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
systemctl disable gdm.service
systemctl enable greetd.service
systemctl enable podman.socket
systemctl enable greeter-group-setup.service
systemctl enable realtime-group-setup.service
