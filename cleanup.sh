#!/bin/bash
# DevCleaner v2 - Comprehensive Mac Developer Cache Cleaner
# Kullanim: ./cleanup.sh [--auto] [--dry-run] [--min-size 100M] [--json-log]
#
# Flags:
#   --auto       Secim sormadan hepsini sil
#   --dry-run    Sadece goster, silme
#   --min-size   Minimum boyut filtresi (ornek: 50M, 1G). Default: 1M
#   --json-log   Her temizligi ~/.devcleaner.log dosyasina kaydet
#   --downloads-age N  Downloads'tan N+ gunluk dosyalari sil (default: 30)

set -euo pipefail

# --- Config ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

AUTO=false
DRY_RUN=false
JSON_LOG=false
MIN_BYTES=1048576        # 1MB default
DOWNLOADS_AGE=30         # gun
NM_STALE_DAYS=7          # node_modules icin

# --- Arg Parse ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --auto)    AUTO=true; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    --json-log) JSON_LOG=true; shift ;;
    --min-size)
      shift
      raw="$1"
      if [[ "$raw" =~ ^([0-9]+)[Gg]$ ]]; then
        MIN_BYTES=$(( ${BASH_REMATCH[1]} * 1073741824 ))
      elif [[ "$raw" =~ ^([0-9]+)[Mm]$ ]]; then
        MIN_BYTES=$(( ${BASH_REMATCH[1]} * 1048576 ))
      elif [[ "$raw" =~ ^([0-9]+)[Kk]$ ]]; then
        MIN_BYTES=$(( ${BASH_REMATCH[1]} * 1024 ))
      else
        MIN_BYTES=$(( raw ))
      fi
      shift ;;
    --downloads-age)
      shift; DOWNLOADS_AGE="$1"; shift ;;
    --nm-age)
      shift; NM_STALE_DAYS="$1"; shift ;;
    -h|--help)
      echo "Kullanim: $0 [--auto] [--dry-run] [--min-size 50M] [--json-log] [--downloads-age 30] [--nm-age 7]"
      exit 0 ;;
    *) echo "Bilinmeyen flag: $1"; exit 1 ;;
  esac
done

# --- Helpers ---
human_size() {
  local bytes=$1
  if (( bytes >= 1073741824 )); then
    printf "%.1f GB" "$(echo "scale=1; $bytes / 1073741824" | bc)"
  elif (( bytes >= 1048576 )); then
    printf "%.1f MB" "$(echo "scale=1; $bytes / 1048576" | bc)"
  elif (( bytes >= 1024 )); then
    printf "%.0f KB" "$(echo "scale=0; $bytes / 1024" | bc)"
  else
    printf "%d B" "$bytes"
  fi
}

dir_bytes() {
  local path="$1"
  if [[ -d "$path" ]]; then
    du -sk "$path" 2>/dev/null | awk '{print $1 * 1024}' || echo 0
  else
    echo 0
  fi
}

glob_bytes() {
  local pattern="$1"
  local total=0
  for d in $pattern; do
    [[ -d "$d" ]] && total=$(( total + $(dir_bytes "$d") ))
  done
  echo "$total"
}

# Downloads: sadece N+ gunluk dosyalar
downloads_old_bytes() {
  local total=0
  if [[ -d "$HOME/Downloads" ]]; then
    while IFS= read -r line; do
      local sz
      sz=$(stat -f %z "$line" 2>/dev/null || echo 0)
      total=$(( total + sz ))
    done < <(find "$HOME/Downloads" -maxdepth 1 -mtime +"$DOWNLOADS_AGE" -not -name ".localized" -not -name ".DS_Store" 2>/dev/null)
  fi
  echo "$total"
}

# tmp: belirli pattern'ler
tmp_dev_bytes() {
  local total=0
  for d in /tmp/dante-* /tmp/metro-* /tmp/react-* /tmp/haste-* /tmp/expo-* /tmp/xcode-* /tmp/bun-* /tmp/npm-* /tmp/watchman-*; do
    [[ -e "$d" ]] && total=$(( total + $(dir_bytes "$d") ))
  done
  echo "$total"
}

# --- Category Definitions ---
# Format: "group|label|path|type|risk"
# type: dir, glob, cache-only (silmeden once cache/ icini hedefle)
# risk: low, medium, high
declare -a CATEGORIES=(
  # =============== XCODE / iOS ===============
  "Xcode|DerivedData|$HOME/Library/Developer/Xcode/DerivedData|dir|low"
  "Xcode|Archives|$HOME/Library/Developer/Xcode/Archives|dir|low"
  "Xcode|iOS DeviceSupport|$HOME/Library/Developer/Xcode/iOS DeviceSupport|dir|low"
  "Xcode|watchOS DeviceSupport|$HOME/Library/Developer/Xcode/watchOS DeviceSupport|dir|low"
  "Xcode|Previews Cache|$HOME/Library/Developer/Xcode/UserData/Previews|dir|low"
  "Xcode|Xcode Cache|$HOME/Library/Caches/com.apple.dt.Xcode|dir|low"
  "Xcode|CoreSimulator Caches|$HOME/Library/Developer/CoreSimulator/Caches|dir|low"
  "Xcode|CoreSimulator Devices|$HOME/Library/Developer/CoreSimulator/Devices|dir|medium"
  "Xcode|CocoaPods Cache|$HOME/Library/Caches/CocoaPods|dir|low"
  "Xcode|Carthage Cache|$HOME/Library/Caches/org.carthage.CarthageKit|dir|low"
  "Xcode|Swift Package Cache|$HOME/Library/Caches/org.swift.swiftpm|dir|low"
  "Xcode|Swift PM Repos|$HOME/Library/org.swift.swiftpm|dir|low"

  # =============== JS / NODE ===============
  "JS/Node|npm cache|$HOME/.npm|dir|low"
  "JS/Node|pnpm store (~/.pnpm)|$HOME/.pnpm-store|dir|low"
  "JS/Node|pnpm store (Library)|$HOME/Library/pnpm/store|dir|low"
  "JS/Node|yarn cache|$HOME/Library/Caches/Yarn|dir|low"
  "JS/Node|yarn global|$HOME/.config/yarn/global|dir|low"
  "JS/Node|bun install cache|$HOME/.bun/install/cache|dir|low"
  "JS/Node|node-gyp cache|$HOME/Library/Caches/node-gyp|dir|low"
  "JS/Node|node cache (XDG)|$HOME/.cache/node|dir|low"
  "JS/Node|tsx cache|$HOME/.cache/tsx|dir|low"
  "JS/Node|turbo cache|$HOME/.cache/turbo|dir|low"
  "JS/Node|metro cache|$HOME/.cache/metro|dir|low"

  # =============== AI CLI / TOOLS ===============
  "AI/CLI|Claude Code versions|$HOME/.local/share/claude/versions|dir|low"
  "AI/CLI|Claude downloads|$HOME/.claude/downloads|dir|low"
  "AI/CLI|Claude shell-snapshots|$HOME/.claude/shell-snapshots|dir|low"
  "AI/CLI|Claude debug logs|$HOME/.claude/debug|dir|low"
  "AI/CLI|Claude telemetry|$HOME/.claude/telemetry|dir|low"
  "AI/CLI|Claude file-history|$HOME/.claude/file-history|dir|low"
  "AI/CLI|Claude plugins|$HOME/.claude/plugins|dir|medium"
  "AI/CLI|Claude App Support|$HOME/Library/Application Support/Claude|dir|medium"
  "AI/CLI|Cursor Agent versions|$HOME/.local/share/cursor-agent/versions|dir|low"
  "AI/CLI|Cursor extensions|$HOME/.cursor/extensions|dir|low"
  "AI/CLI|Cursor worktrees|$HOME/.cursor/worktrees|dir|low"
  "AI/CLI|Cursor ai-tracking|$HOME/.cursor/ai-tracking|dir|low"
  "AI/CLI|GitHub Copilot cache|$HOME/.cache/github-copilot|dir|low"
  "AI/CLI|GitHub Copilot config|$HOME/.config/github-copilot|dir|low"
  "AI/CLI|OpenCode data|$HOME/.local/share/opencode|dir|low"
  "AI/CLI|OpenCode cache|$HOME/.cache/opencode|dir|low"
  "AI/CLI|chrome-devtools-mcp|$HOME/.cache/chrome-devtools-mcp|dir|low"
  "AI/CLI|Dia App Support|$HOME/Library/Application Support/Dia|dir|medium"
  "AI/CLI|Dia Cache|$HOME/Library/Caches/Dia|dir|low"

  # =============== IDE ===============
  "IDE|JetBrains App Data|$HOME/Library/Application Support/JetBrains|glob|low"
  "IDE|JetBrains Caches|$HOME/Library/Caches/JetBrains|glob|low"
  "IDE|JetBrains Logs|$HOME/Library/Logs/JetBrains|glob|low"
  "IDE|VSCode extensions|$HOME/.vscode/extensions|dir|low"
  "IDE|VSCode Cache|$HOME/Library/Caches/com.microsoft.VSCode|dir|low"
  "IDE|Zed Cache|$HOME/Library/Caches/dev.zed.Zed|dir|low"
  "IDE|Zed App Data|$HOME/Library/Application Support/Zed|dir|medium"
  "IDE|nvim data|$HOME/.local/share/nvim|dir|low"
  "IDE|nvim cache|$HOME/.cache/nvim|dir|low"

  # =============== TERMINAL ===============
  "Terminal|Warp App Data|$HOME/Library/Application Support/dev.warp.Warp-Stable|dir|medium"
  "Terminal|Warp Cache|$HOME/Library/Caches/dev.warp.Warp-Stable|dir|low"
  "Terminal|Warp Group Container|$HOME/Library/Group Containers/group.dev.warp.Warp-Stable.SharedContainer|dir|low"
  "Terminal|Warp Logs|$HOME/Library/Logs/warp.log|dir|low"
  "Terminal|tabby data|$HOME/Library/Application Support/tabby|dir|low"

  # =============== PYTHON ===============
  "Python|pip cache|$HOME/Library/Caches/pip|dir|low"
  "Python|uv cache|$HOME/.cache/uv|dir|low"
  "Python|uv data|$HOME/.local/share/uv|dir|low"
  "Python|pyinstaller|$HOME/Library/Application Support/pyinstaller|dir|low"
  "Python|mypy cache|$HOME/.cache/mypy|dir|low"
  "Python|ruff cache|$HOME/.cache/ruff|dir|low"
  "Python|pre-commit cache|$HOME/.cache/pre-commit|dir|low"
  "Python|pipx cache|$HOME/.cache/pipx|dir|low"

  # =============== JAVA / ANDROID ===============
  "Java/Android|Gradle caches|$HOME/.gradle/caches|dir|low"
  "Java/Android|Gradle wrapper|$HOME/.gradle/wrapper|dir|low"
  "Java/Android|Maven repository|$HOME/.m2/repository|dir|low"
  "Java/Android|Android SDK system-images|$HOME/Library/Android/sdk/system-images|dir|medium"
  "Java/Android|Android SDK NDK|$HOME/Library/Android/sdk/ndk|dir|medium"
  "Java/Android|Android SDK emulator|$HOME/Library/Android/sdk/emulator|dir|medium"
  "Java/Android|Android cache|$HOME/.android/cache|dir|low"
  "Java/Android|Android AVD|$HOME/.android/avd|dir|medium"

  # =============== RUBY ===============
  "Ruby|gem cache|$HOME/.gem/cache|dir|low"
  "Ruby|bundler cache|$HOME/.bundle/cache|dir|low"

  # =============== RUST ===============
  "Rust|cargo registry|$HOME/.cargo/registry|dir|low"
  "Rust|cargo git|$HOME/.cargo/git|dir|low"
  "Rust|rustup toolchains|$HOME/.rustup/toolchains|dir|medium"

  # =============== GO ===============
  "Go|go mod cache|$HOME/go/pkg/mod|dir|low"
  "Go|go build cache|$HOME/.cache/go-build|dir|low"

  # =============== DEVTOOLS ===============
  "DevTools|Homebrew Cache|$HOME/Library/Caches/Homebrew|dir|low"
  "DevTools|Docker Desktop|$HOME/Library/Containers/com.docker.docker|dir|medium"
  "DevTools|Docker config|$HOME/.docker|dir|medium"
  "DevTools|Expo web-build-cache|$HOME/.expo/web-build-cache|dir|low"
  "DevTools|Expo cache|$HOME/.cache/expo|dir|low"
  "DevTools|Trunk cache|$HOME/.cache/trunk|dir|low"
  "DevTools|Prisma engines|$HOME/.cache/prisma|dir|low"
  "DevTools|Terraform plugins|$HOME/.terraform.d/plugin-cache|dir|low"
  "DevTools|Hoppscotch|$HOME/Library/Application Support/io.hoppscotch.desktop|dir|low"
  "DevTools|maestro-studio|$HOME/Library/Application Support/maestro-studio|dir|low"
  "DevTools|Navicat|$HOME/Library/Application Support/PremiumSoft CyberTech|dir|medium"
  "DevTools|herd-lite|$HOME/.config/herd-lite|dir|low"
  "DevTools|icedtea-web cache|$HOME/.cache/icedtea-web|dir|low"

  # =============== BROWSER ===============
  "Browser|Edge Updater|$HOME/Library/Application Support/Microsoft/EdgeUpdater|dir|low"
  "Browser|Edge Cache|$HOME/Library/Caches/Microsoft Edge|dir|low"
  "Browser|Edge SW Cache|$HOME/Library/Application Support/Microsoft Edge/Default/Service Worker/CacheStorage|dir|low"
  "Browser|Chrome Cache|$HOME/Library/Caches/Google/Chrome|dir|low"
  "Browser|Chrome SW Cache|$HOME/Library/Application Support/Google/Chrome/Default/Service Worker/CacheStorage|dir|low"
  "Browser|Chrome GPU Cache|$HOME/Library/Application Support/Google/Chrome/Default/GPUCache|dir|low"
  "Browser|Safari Cache|$HOME/Library/Caches/com.apple.Safari|dir|low"
  "Browser|Firefox Cache|$HOME/Library/Caches/Firefox|dir|low"
  "Browser|Brave Cache|$HOME/Library/Caches/BraveSoftware|dir|low"
  "Browser|WebKit Cache|$HOME/Library/WebKit|dir|low"
  "Browser|GeoServices Cache|$HOME/Library/Caches/GeoServices|dir|low"

  # =============== APP CACHE ===============
  "App|Spotify cache|$HOME/Library/Caches/com.spotify.client|dir|low"
  "App|Slack data|$HOME/Library/Application Support/Slack|dir|medium"
  "App|Zoom data|$HOME/Library/Application Support/zoom.us|dir|low"
  "App|Raycast data|$HOME/Library/Application Support/com.raycast.macos|dir|medium"
  "App|Raycast extensions|$HOME/.config/raycast/extensions|dir|low"
  "App|WhatsApp data|$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared|dir|medium"
  "App|Skype data|$HOME/Library/Application Support/Microsoft/Skype for Desktop|dir|low"
  "App|Discord cache|$HOME/Library/Application Support/discord|dir|low"
  "App|Telegram cache|$HOME/Library/Application Support/Telegram Desktop|dir|low"

  # =============== SYSTEM ===============
  "System|Trash|$HOME/.Trash|dir|low"
  "System|User Logs|$HOME/Library/Logs|dir|low"
  "System|CrashReporter|$HOME/Library/Logs/DiagnosticReports|dir|low"
  "System|Saved App State|$HOME/Library/Saved Application State|dir|low"
  "System|Apple Music Artwork|$HOME/Library/Containers/com.apple.AMPArtworkAgent|dir|low"
  "System|CloudKit Cache|$HOME/Library/Caches/CloudKit|dir|low"
  "System|Wallpaper Cache|$HOME/Library/Application Support/com.apple.wallpaper|dir|low"
)

# --- Parallel Scan ---
echo -e "${BOLD}DevCleaner v2 - Sistem Taramasi${RESET}"
disk_free=$(df -h / | awk 'NR==2{print $4}')
disk_total=$(df -h / | awk 'NR==2{print $2}')
disk_pct=$(df -h / | awk 'NR==2{gsub(/%/,"",$5); print $5}')
echo -e "${DIM}Disk: ${disk_free} bos / ${disk_total} toplam (%${disk_pct} dolu)${RESET}"
echo -e "${DIM}Min boyut filtresi: $(human_size $MIN_BYTES)${RESET}"
echo ""
echo -e "${YELLOW}Taraniyor (paralel)...${RESET}"

# Paralel tarama: her kategoriyi background'da tara, sonuclari tmpfile'a yaz
SCAN_TMP=$(mktemp /tmp/devcleaner_scan.XXXXXX)
trap 'rm -f "$SCAN_TMP"' EXIT

for i in "${!CATEGORIES[@]}"; do
  (
    IFS='|' read -r group label path type risk <<< "${CATEGORIES[$i]}"
    case "$type" in
      glob) bytes=$(glob_bytes "${path}*") ;;
      *)    bytes=$(dir_bytes "$path") ;;
    esac
    if (( bytes >= MIN_BYTES )); then
      echo "$i|$bytes|$group|$label|$path|$risk"
    fi
  ) &
done
wait > /dev/null 2>&1 || true

# Parallel isler bitene kadar bekle ve sonuclari topla
for i in "${!CATEGORIES[@]}"; do
  (
    IFS='|' read -r group label path type risk <<< "${CATEGORIES[$i]}"
    case "$type" in
      glob) bytes=$(glob_bytes "${path}*") ;;
      *)    bytes=$(dir_bytes "$path") ;;
    esac
    if (( bytes >= MIN_BYTES )); then
      echo "$i|$bytes|$group|$label|$path|$risk"
    fi
  ) >> "$SCAN_TMP" &
done
wait

declare -a FOUND_IDX=()
declare -a FOUND_BYTES=()
declare -a FOUND_LABEL=()
declare -a FOUND_GROUP=()
declare -a FOUND_PATH=()
declare -a FOUND_RISK=()

while IFS='|' read -r idx bytes group label path risk; do
  FOUND_IDX+=("$idx")
  FOUND_BYTES+=("$bytes")
  FOUND_LABEL+=("$label")
  FOUND_GROUP+=("$group")
  FOUND_PATH+=("$path")
  FOUND_RISK+=("$risk")
done < "$SCAN_TMP"

# --- node_modules scan ---
nm_bytes=0
nm_paths=()
nm_skipped=0
if [[ -d "$HOME/Desktop/Projects" ]]; then
  while IFS= read -r line; do
    kb=$(echo "$line" | awk '{print $1}')
    p=$(echo "$line" | awk '{$1=""; print substr($0,2)}')
    project_dir=$(dirname "$p")

    last_activity=0
    for check_file in "$project_dir/package.json" "$project_dir/bun.lockb" "$project_dir/package-lock.json" "$project_dir/yarn.lock" "$project_dir/pnpm-lock.yaml"; do
      if [[ -f "$check_file" ]]; then
        file_epoch=$(stat -f %m "$check_file" 2>/dev/null || echo 0)
        (( file_epoch > last_activity )) && last_activity=$file_epoch
      fi
    done
    if [[ -d "$project_dir/src" ]]; then
      src_epoch=$(stat -f %m "$project_dir/src" 2>/dev/null || echo 0)
      (( src_epoch > last_activity )) && last_activity=$src_epoch
    fi

    now_epoch=$(date +%s)
    stale_threshold=$(( now_epoch - NM_STALE_DAYS * 86400 ))

    if (( last_activity < stale_threshold )); then
      nm_bytes=$(( nm_bytes + kb * 1024 ))
      nm_paths+=("$p")
    else
      nm_skipped=$(( nm_skipped + 1 ))
    fi
  done < <(find "$HOME/Desktop/Projects" -maxdepth 5 -name "node_modules" -type d -prune -exec du -sk {} \; 2>/dev/null | sort -rn)
fi

if (( nm_bytes >= MIN_BYTES )); then
  nm_label="node_modules (${#nm_paths[@]} eski proje"
  (( nm_skipped > 0 )) && nm_label+=", ${nm_skipped} aktif korundu"
  nm_label+=")"
  FOUND_IDX+=("NM")
  FOUND_BYTES+=("$nm_bytes")
  FOUND_LABEL+=("$nm_label")
  FOUND_GROUP+=("JS/Node")
  FOUND_PATH+=("NODEMODULES")
  FOUND_RISK+=("low")
fi

# --- Downloads (age-based) scan ---
dl_bytes=$(downloads_old_bytes)
dl_count=0
if (( dl_bytes >= MIN_BYTES )); then
  dl_count=$(find "$HOME/Downloads" -maxdepth 1 -mtime +"$DOWNLOADS_AGE" -not -name ".localized" -not -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
  FOUND_IDX+=("DL")
  FOUND_BYTES+=("$dl_bytes")
  FOUND_LABEL+=("Downloads ${DOWNLOADS_AGE}+ gun (${dl_count} dosya)")
  FOUND_GROUP+=("Downloads")
  FOUND_PATH+=("DOWNLOADS_OLD")
  FOUND_RISK+=("medium")
fi

# --- /tmp dev artifacts scan ---
tmp_bytes=$(tmp_dev_bytes)
if (( tmp_bytes >= MIN_BYTES )); then
  FOUND_IDX+=("TMP")
  FOUND_BYTES+=("$tmp_bytes")
  FOUND_LABEL+=("/tmp dev artifacts")
  FOUND_GROUP+=("System")
  FOUND_PATH+=("TMP_DEV")
  FOUND_RISK+=("low")
fi

# --- Docker system scan ---
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  docker_reclaimable=$(docker system df --format '{{.Reclaimable}}' 2>/dev/null | head -1 || echo "")
  if [[ -n "$docker_reclaimable" ]]; then
    # Docker system prune icin ayri entry
    docker_raw=$(docker system df 2>/dev/null || true)
    if [[ -n "$docker_raw" ]]; then
      FOUND_IDX+=("DOCKER")
      # Tahmini boyut (docker system df output'undan parse et)
      docker_est=0
      while IFS= read -r dline; do
        reclaim_val=$(echo "$dline" | awk '{print $(NF)}' | grep -oE '[0-9.]+' || echo 0)
        reclaim_unit=$(echo "$dline" | awk '{print $(NF)}' | grep -oE '[KMGT]B' || echo "B")
        case "$reclaim_unit" in
          GB) docker_est=$(( docker_est + ${reclaim_val%%.*} * 1073741824 )) ;;
          MB) docker_est=$(( docker_est + ${reclaim_val%%.*} * 1048576 )) ;;
          KB) docker_est=$(( docker_est + ${reclaim_val%%.*} * 1024 )) ;;
        esac
      done <<< "$(echo "$docker_raw" | tail -n +2)"

      if (( docker_est >= MIN_BYTES )); then
        FOUND_BYTES+=("$docker_est")
        FOUND_LABEL+=("Docker (images/containers/volumes/cache)")
        FOUND_GROUP+=("DevTools")
        FOUND_PATH+=("DOCKER_PRUNE")
        FOUND_RISK+=("medium")
      fi
    fi
  fi
fi

# --- Check if anything found ---
if (( ${#FOUND_IDX[@]} == 0 )); then
  echo -e "${GREEN}Temizlenecek bir sey bulunamadi (min: $(human_size $MIN_BYTES)).${RESET}"
  exit 0
fi

# --- Sort by size (descending) ---
sorted_order=($(
  for i in "${!FOUND_BYTES[@]}"; do
    echo "$i ${FOUND_BYTES[$i]}"
  done | sort -k2 -rn | awk '{print $1}'
))

# --- Display ---
echo ""
echo -e "${BOLD}  #   Boyut      Grup         Kategori                          Risk${RESET}"
echo -e "${DIM}  --- ---------- ------------ --------------------------------- ------${RESET}"

total_all=0
prev_group=""
for rank in "${!sorted_order[@]}"; do
  idx=${sorted_order[$rank]}
  num=$((rank + 1))
  size_str=$(human_size "${FOUND_BYTES[$idx]}")
  group="${FOUND_GROUP[$idx]}"
  risk="${FOUND_RISK[$idx]}"

  # Risk rengi
  case "$risk" in
    high)   risk_color="${RED}" ;;
    medium) risk_color="${YELLOW}" ;;
    *)      risk_color="${GREEN}" ;;
  esac

  if [[ "$group" != "$prev_group" && -n "$prev_group" ]]; then
    echo -e "${DIM}  .${RESET}"
  fi
  prev_group="$group"

  printf "  ${BOLD}%-3d${RESET} ${RED}%-10s${RESET} ${CYAN}%-12s${RESET} %-33s ${risk_color}%-6s${RESET}\n" \
    "$num" "$size_str" "$group" "${FOUND_LABEL[$idx]}" "[$risk]"
  total_all=$(( total_all + FOUND_BYTES[$idx] ))
done

echo -e "${DIM}  --- ---------- ------------ --------------------------------- ------${RESET}"
echo -e "  ${BOLD}Toplam: ${RED}$(human_size $total_all)${RESET}"
echo ""

# --- Dry-run check ---
if $DRY_RUN; then
  echo -e "${YELLOW}[DRY-RUN] Sadece gosterim modu, hicbir sey silinmedi.${RESET}"
  exit 0
fi

# --- Selection ---
declare -a SELECTED=()

if $AUTO; then
  for i in "${!sorted_order[@]}"; do
    SELECTED+=("${sorted_order[$i]}")
  done
  echo -e "${YELLOW}--auto modu: Hepsi secildi.${RESET}"
else
  echo -e "${BOLD}Secim yap:${RESET}"
  echo -e "  ${DIM}Numaralari virgul ile yaz (ornek: 1,3,5)${RESET}"
  echo -e "  ${DIM}Aralik: 1-5  |  'a' = hepsi  |  'l' = sadece low risk  |  'q' = cikis${RESET}"
  echo ""
  read -rp "> " selection

  if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
    echo "Iptal edildi."
    exit 0
  fi

  if [[ "$selection" == "a" || "$selection" == "A" ]]; then
    for i in "${!sorted_order[@]}"; do
      SELECTED+=("${sorted_order[$i]}")
    done
  elif [[ "$selection" == "l" || "$selection" == "L" ]]; then
    for i in "${!sorted_order[@]}"; do
      idx=${sorted_order[$i]}
      if [[ "${FOUND_RISK[$idx]}" == "low" ]]; then
        SELECTED+=("$idx")
      fi
    done
    echo -e "${GREEN}Sadece low-risk ogeler secildi.${RESET}"
  else
    IFS=',' read -ra parts <<< "$selection"
    for part in "${parts[@]}"; do
      part=$(echo "$part" | tr -d ' ')
      if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
        start="${BASH_REMATCH[1]}"
        end="${BASH_REMATCH[2]}"
        for (( n=start; n<=end; n++ )); do
          if (( n >= 1 && n <= ${#sorted_order[@]} )); then
            SELECTED+=("${sorted_order[$((n - 1))]}")
          fi
        done
      elif [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 1 && part <= ${#sorted_order[@]} )); then
        SELECTED+=("${sorted_order[$((part - 1))]}")
      else
        echo -e "${RED}Gecersiz: $part${RESET}"
      fi
    done
  fi
fi

if (( ${#SELECTED[@]} == 0 )); then
  echo "Hicbir sey secilmedi."
  exit 0
fi

# --- Confirm ---
selected_total=0
echo ""
echo -e "${BOLD}Silinecekler:${RESET}"
for idx in "${SELECTED[@]}"; do
  risk="${FOUND_RISK[$idx]}"
  case "$risk" in
    medium|high) warn=" ${YELLOW}⚠${RESET}" ;;
    *)           warn="" ;;
  esac
  echo -e "  ${RED}x${RESET} ${FOUND_GROUP[$idx]}/${FOUND_LABEL[$idx]} ($(human_size "${FOUND_BYTES[$idx]}"))${warn}"
  selected_total=$(( selected_total + FOUND_BYTES[$idx] ))
done
echo -e "  ${BOLD}Kazanilacak alan: ~$(human_size $selected_total)${RESET}"
echo ""
read -rp "Emin misin? (e/h): " confirm

if [[ "$confirm" != "e" && "$confirm" != "E" ]]; then
  echo "Iptal edildi."
  exit 0
fi

# --- Clean ---
echo ""
freed=0
cleaned_items=()

for idx in "${SELECTED[@]}"; do
  label="${FOUND_LABEL[$idx]}"
  path="${FOUND_PATH[$idx]}"
  found_idx="${FOUND_IDX[$idx]}"
  printf "  Temizleniyor: %-40s" "${label}..."

  if [[ "$path" == "NODEMODULES" ]]; then
    for nm in "${nm_paths[@]}"; do
      rm -rf "$nm"
    done
  elif [[ "$path" == "DOWNLOADS_OLD" ]]; then
    find "$HOME/Downloads" -maxdepth 1 -mtime +"$DOWNLOADS_AGE" \
      -not -name ".localized" -not -name ".DS_Store" \
      -exec rm -rf {} + 2>/dev/null || true
  elif [[ "$path" == "TMP_DEV" ]]; then
    for d in /tmp/dante-* /tmp/metro-* /tmp/react-* /tmp/haste-* /tmp/expo-* /tmp/xcode-* /tmp/bun-* /tmp/npm-* /tmp/watchman-*; do
      [[ -e "$d" ]] && rm -rf "$d"
    done
  elif [[ "$path" == "DOCKER_PRUNE" ]]; then
    docker system prune -af --volumes 2>/dev/null || true
  elif [[ "$found_idx" != "NM" && "$found_idx" != "DL" && "$found_idx" != "TMP" && "$found_idx" != "DOCKER" ]]; then
    IFS='|' read -r _g _l _p type _r <<< "${CATEGORIES[$found_idx]}"
    case "$type" in
      glob)
        for d in "${path}"*; do
          [[ -d "$d" ]] && rm -rf "$d"
        done
        ;;
      *)
        if [[ -d "$path" ]]; then
          rm -rf "${path:?}"/*
        fi
        ;;
    esac
  fi

  freed=$(( freed + FOUND_BYTES[$idx] ))
  cleaned_items+=("${FOUND_GROUP[$idx]}/${label}:$(human_size "${FOUND_BYTES[$idx]}")")
  echo -e " ${GREEN}OK${RESET}"
done

# --- Extra cleanup ---
if command -v xcrun &>/dev/null; then
  printf "  Temizleniyor: %-40s" "Unavailable Simulators..."
  xcrun simctl delete unavailable 2>/dev/null || true
  echo -e " ${GREEN}OK${RESET}"
fi

if command -v watchman &>/dev/null; then
  printf "  Temizleniyor: %-40s" "Watchman..."
  watchman watch-del-all 2>/dev/null || true
  echo -e " ${GREEN}OK${RESET}"
fi

# --- JSON Log ---
if $JSON_LOG; then
  log_file="$HOME/.devcleaner.log"
  items_json="["
  first=true
  for item in "${cleaned_items[@]}"; do
    if ! $first; then items_json+=","; fi
    first=false
    items_json+="\"$item\""
  done
  items_json+="]"
  echo "{\"date\":\"$(date -Iseconds)\",\"freed_bytes\":$freed,\"freed_human\":\"$(human_size $freed)\",\"items\":$items_json}" >> "$log_file"
fi

# --- Result ---
echo ""
echo -e "${GREEN}${BOLD}Tamamlandi!${RESET}"
echo -e "Kazanilan alan: ${BOLD}~$(human_size $freed)${RESET}"
new_free=$(df -h / | awk 'NR==2{print $4}')
new_total=$(df -h / | awk 'NR==2{print $2}')
echo -e "Disk durumu:    ${disk_free} -> ${GREEN}${new_free}${RESET} bos / ${new_total} toplam"

if $JSON_LOG; then
  echo -e "${DIM}Log: ~/.devcleaner.log${RESET}"
fi
