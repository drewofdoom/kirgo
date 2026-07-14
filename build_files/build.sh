#!/bin/bash

set -ouex pipefail

log() { echo "=== $* ==="; }
RELEASE="$(rpm -E %fedora)"

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

# enable COPR repos
log "Enabling COPR repos..."
COPR_REPOS=(
  avengemedia/dms
  rivenirvana/morewaita-icon-theme
  scottames/ghostty
  tofik/nwg-shell
  ulysg/xwayland-satellite
)
for repo in "${COPR_REPOS[@]}"; do
  dnf5 -y copr enable "$repo"
done

# Terra Repo
log "Adding Terra repo..."
curl -fsSL https://github.com/terrapkg/subatomic-repos/raw/main/terra.repo \
  -o /etc/yum.repos.d/terra.repo

# Repo priorities (lower = higher priority)
echo "priority=1" >>/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:ulysg:xwayland-satellite.repo
echo "priority=1" >>/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:scottames:ghostty.repo
echo "priority=2" >>/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:avengemedia:danklinux.repo
dnf5 -y config-manager setopt '*danklinux*.exclude=ghostty*'
dnf5 -y config-manager setopt 'terra.enabled=1' 'terra*.priority=3' 'terra*.exclude=ghostty matugen*'

# Install packages
PKGS=(
  # Desktop
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
  xwayland-run

  # DMS
  quickshell
  dankcalendar-git
  danksearch
  dgop
  dms
  dms-cli
  dms-greeter
  niri

  # Theming
  matugen
  nwg-look
  adw-gtk3-theme
  morewaita-icon-theme

  # Fonts
  maple-fonts
  material-symbols-fonts

  # Terminal
  ghostty
  ghostty-terminfo
  ghostty-shell-integration
  ghostty-fish-completion
)

REMOVE_PKGS=(
  nautilus-gsconnect
  jetbrains-mono-fonts-all
  gnome-tweaks
  libappindicator-gtk3
  libayatana-appindicator-gtk3
  opendyslexic-fonts
  zsh
)

log "Installing packages..."
dnf5 install -y --setopt=install_weak_deps=False "${PKGS[@]}"

log "Removing unwanted packages..."
dnf5 remove -y "${REMOVE_PKGS[@]}"

log "Cleaning up..."
dnf5 clean all

systemctl disable gdm.service
systemctl enable greetd.service
