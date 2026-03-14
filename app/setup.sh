#!/bin/bash
set -euo pipefail

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
RESET='\033[0m'

cd "$(dirname "$0")"

echo -e "${BOLD}DevCleaner - macOS Menubar App Setup${RESET}"
echo ""

# 1. Check XcodeGen
if ! command -v xcodegen &>/dev/null; then
  echo -e "${YELLOW}XcodeGen bulunamadi. Kuruluyor...${RESET}"
  brew install xcodegen
fi

# 2. Generate Xcode project
echo -e "Xcode projesi olusturuluyor..."
xcodegen generate --spec project.yml
echo -e "${GREEN}DevCleaner.xcodeproj olusturuldu${RESET}"

# 3. Build
echo ""
echo -e "Derleniyor..."
xcodebuild -project DevCleaner.xcodeproj \
  -scheme DevCleaner \
  -configuration Release \
  -derivedDataPath build \
  -quiet \
  build

# 4. Copy to /Applications
APP_PATH="build/Build/Products/Release/DevCleaner.app"
if [[ -d "$APP_PATH" ]]; then
  echo ""
  echo -e "${GREEN}Build basarili!${RESET}"
  echo -e "App: ${BOLD}$APP_PATH${RESET}"
  echo ""
  read -rp "$(echo -e "${YELLOW}/Applications'a kopyalansin mi? (e/h):${RESET} ")" install
  if [[ "$install" == "e" || "$install" == "E" ]]; then
    cp -R "$APP_PATH" /Applications/
    echo -e "${GREEN}DevCleaner /Applications'a kuruldu!${RESET}"
    echo -e "Menubar'da paintbrush ikonuna tiklayarak kullanabilirsin."
  fi
else
  echo -e "${RED}Build basarisiz. xcodebuild ciktisini kontrol et.${RESET}"
  exit 1
fi
