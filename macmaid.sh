#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

# Launch screen
launch_screen() {
cat << "EOF"

 __  __            _      __  __       _     _ 
|  \/  |          (_)    |  \/  |     (_)   | |
| \  / | __ _ _ __ _  ___| \  / | __ _ _  __| |
| |\/| |/ _` | '__| |/ _ \ |\/| |/ _` | |/ _` |
| |  | | (_| | |  | |  __/ |  | | (_| | | (_| |
|_|  |_|\__,_|_|  |_|\___|_|  |_|\__,_|_|\__,_|

        🧹 Welcome to Mac Maid 🧹
     Your Mac's Personal Housekeeper

EOF
sleep 1.5
clear
}

launch_screen

# Colors
if [[ -t 2 ]]; then
  NC='\033[0m'
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  CYAN='\033[0;36m'
else
  NC='' RED='' GREEN='' YELLOW='' CYAN=''
fi

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
}

spinner() {
  local pid=$!
  local delay=0.1
  local spinstr='|/-\'
  while ps -p $pid &>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

sweeping_animation() {
  echo -n "🧹 Sweeping"
  for i in {1..5}; do
    sleep 0.4
    echo -n "."
  done
  echo -e " Done! ✨"
}

msg() {
  echo -e "${1-}${NC}"
}

success() {
  msg "${GREEN}✔ $1"
}

warning() {
  msg "${YELLOW}⚠ $1"
}

error() {
  msg "${RED}✖ $1"
}

section() {
  msg "${CYAN}\n───────────────────────────────────────────────────────────────────────────────\n$1\n───────────────────────────────────────────────────────────────────────────────${NC}"
}

bytesToHuman() {
  local b=${1:-0}
  local d=''
  local s=0
  local S=(Bytes KiB MiB GiB TiB PiB EiB)
  while ((b > 1024)); do
    d="$(printf ".%02d" $((b % 1024 * 100 / 1024)))"
    b=$((b / 1024))
    ((s++))
  done
  echo "$b$d ${S[$s]}"
}

# Default options
update=false
browser_clean=true
deep_clean=false

parse_params() {
  while :; do
    case "${1-}" in
      -h | --help) usage ;;
      -v | --verbose) set -x ;;
      -u | --update) update=true ;;
      -d | --deep) deep_clean=true ;;
      --no-color) NO_COLOR=1 ;;
      -?*) die "Unknown option: $1" ;;
      *) break ;;
    esac
    shift
  done
  return 0
}

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [options]

Options:
  -h, --help             Show this help message and exit
  -v, --verbose          Show detailed script output (debug mode)
  -u, --update           Update and clean Homebrew packages
  -d, --deep             Deep Clean mode (old iOS backups, Steam shaders, etc.)

Example:
  mac-maid -d
EOF
  exit
}

parse_params "$@"

# Mode Banner
if [ "$deep_clean" = true ]; then
  echo -e "\n🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊"
  echo -e "           🌊 DEEP CLEAN MODE 🌊"
  echo -e "🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊🌊\n"
else
  echo -e "\n🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹"
  echo -e "           🧹 BASIC CLEAN MODE 🧹"
  echo -e "🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹🧹\n"
fi

# Cute Sweeping Animation
sweeping_animation

# Request Sudo
section "🔐 Requesting Sudo Access"
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

oldAvailable=$(df / | tail -1 | awk '{print $4}')

# System Cleanup
section "🗑 Emptying Trash and Cleaning Caches"
(
  sudo rm -rfv /Volumes/*/.Trashes/* ~/.Trash/* &>/dev/null
  sudo rm -rfv /Library/Caches/* /System/Library/Caches/* ~/Library/Caches/* &>/dev/null
  sudo rm -rfv /private/var/folders/*/*/*/* &>/dev/null
) & spinner && success "Trash & System Caches Cleaned!"

section "📝 Cleaning Log Files"
(
  sudo rm -rfv /private/var/log/asl/*.asl ~/Library/Logs/CoreSimulator/* &>/dev/null
  sudo rm -rfv ~/Library/Containers/com.apple.mail/Data/Library/Logs/Mail/* &>/dev/null
) & spinner && success "Logs Cleared!"

section "🚀 Cleaning App-Specific Caches"
apps=("Adobe" "Google Chrome" "Dropbox" "Google Drive" "Steam" "Minecraft" "LunarClient" "Teams" "Kite")
for app in "${apps[@]}"; do
  (
    case $app in
      "Adobe") rm -rfv ~/Library/Application\ Support/Adobe/Common/Media\ Cache\ Files/* &>/dev/null ;;
      "Google Chrome") rm -rfv ~/Library/Application\ Support/Google/Chrome/Default/Application\ Cache/* &>/dev/null ;;
      "Dropbox") sudo rm -rfv ~/Dropbox/.dropbox.cache/* &>/dev/null ;;
      "Google Drive") killall "Google Drive File Stream" &>/dev/null; rm -rfv ~/Library/Application\ Support/Google/DriveFS/[0-9a-zA-Z]*/content_cache &>/dev/null ;;
      "Steam") rm -rfv ~/Library/Application\ Support/Steam/{appcache,depotcache,logs,steamapps/shadercache,steamapps/temp,steamapps/download} &>/dev/null ;;
      "Minecraft") rm -rfv ~/Library/Application\ Support/minecraft/{logs,crash-reports,webcache,webcache2} &>/dev/null ;;
      "LunarClient") rm -rfv ~/.lunarclient/{game-cache,launcher-cache,logs,offline/*/logs,offline/files/*/logs} &>/dev/null ;;
      "Teams") rm -rfv ~/Library/Application\ Support/Microsoft/Teams/{IndexedDB,Cache,Application\ Cache,Code\ Cache,blob_storage,databases,gpucache,Local\ Storage,tmp} &>/dev/null ;;
      "Kite") rm -rfv ~/.kite/logs &>/dev/null ;;
    esac
  ) & spinner && success "$app Cache Cleaned"
done

# Browser Clean
section "🌐 Browser Data Cleanup (Safari & Chrome)"
(
  rm -f ~/Library/Safari/History.db ~/Library/Safari/History.db-* ~/Library/Cookies/Cookies.binarycookies
  rm -rf ~/Library/Caches/com.apple.Safari/*
  rm -f ~/Library/Application\ Support/Google/Chrome/Default/History
  rm -f ~/Library/Application\ Support/Google/Chrome/Default/Cookies
  rm -rf ~/Library/Application\ Support/Google/Chrome/Default/Cache/*
) & spinner && success "Browser Histories, Cookies, and Caches Cleared"

# QuickLook
section "📸 Clearing QuickLook Thumbnail Cache"
(
  rm -rf ~/Library/Caches/com.apple.QuickLook.thumbnailcache
  qlmanage -r cache
) & spinner && success "QuickLook Cache Cleared!"

# Sleep Image
section "💤 Removing Sleep Image (Hibernation)"
(
  sudo rm -rf /private/var/vm/sleepimage
) & spinner && success "Sleep Image Removed!"

# Saved States
section "🗂 Clearing Saved Application State"
(
  rm -rf ~/Library/Saved\ Application\ State/*
) & spinner && success "Saved App States Cleared!"

# Font Cache
section "🧼 Clearing Font Cache"
if [[ $(sw_vers -productVersion | cut -d. -f1) -ge 14 ]]; then
  warning "Skipping Font Cache clearing — not needed on macOS 14 or later."
else
  (
    sudo atsutil databases -remove
    sudo atsutil server -shutdown
    sudo atsutil server -ping
  ) & spinner && success "Font Cache Cleared!"
fi

# Broken Preferences
section "📝 Detecting Broken Preferences"
broken_prefs=$(find ~/Library/Preferences -name "*.plist" -size 0)
if [[ -n "$broken_prefs" ]]; then
  echo "$broken_prefs" | while read -r plist; do
    echo "🔶 Found broken preference: $plist"
    mv "$plist" ~/.Trash/
  done
  success "Broken Preferences moved to Trash!"
else
  success "No broken preferences found."
fi

# Deep Mode
if [ "$deep_clean" = true ]; then
  section "🌊 DEEP CLEAN MODE: Extra Heavy Cleaning"
  (
    rm -rf ~/Library/Application\ Support/MobileSync/Backup/* &>/dev/null
    rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/* &>/dev/null
    rm -rf ~/Library/Developer/CoreSimulator/Caches/* &>/dev/null
    rm -rf ~/Library/Application\ Support/Steam/steamapps/shadercache/* &>/dev/null
  ) & spinner && success "Deep Clean Extras Done!"
else
  warning "Deep Clean NOT enabled (use --deep)"
fi

# Final Space Report
section "🏁 FINAL CLEANUP SUMMARY"
newAvailable=$(df / | tail -1 | awk '{print $4}')
count=$((newAvailable - oldAvailable))
saved=$(bytesToHuman $((count * 512)))

if [ "$count" -gt 0 ]; then
  echo -e "\n${GREEN}✅ Mac Maid has finished cleaning!"
  echo -e "🧹 Space Freed: ${saved}${NC}\n"
else
  echo -e "\n${YELLOW}⚠ Cleanup complete, but no extra space was freed.${NC}\n"
fi

# Play a friendly sound
afplay /System/Library/Sounds/Glass.aiff

cleanup

