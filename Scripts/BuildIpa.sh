#!/bin/bash
# Builds GlassLookStore-vX.Y.Z.ipa into Build/ on a Mac with Xcode 26 and XcodeGen.
#   Unsigned (for AltStore or Sideloadly):            Scripts/BuildIpa.sh unsigned
#   Signed with your Apple ID team (development):     TEAM_ID=ABCDE12345 Scripts/BuildIpa.sh signed
# Claude runs the same steps on Codemagic (workflow glasslookstore-ipa); you never need to run this yourself.
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-unsigned}"
VERSION=$(grep -m1 'MARKETING_VERSION' project.yml | sed -E 's/.*"([0-9.]+)".*/\1/')
OUT="Build"
ARCHIVE="$OUT/GlassLookStore.xcarchive"
IPA="$OUT/GlassLookStore-v$VERSION.ipa"

command -v xcodegen >/dev/null || { echo "XcodeGen is missing: brew install xcodegen"; exit 1; }
rm -rf "$OUT" && mkdir -p "$OUT"
xcodegen generate --spec project.yml

if [ "$MODE" = "signed" ]; then
  : "${TEAM_ID:?Set TEAM_ID to your Apple ID team id}"
  xcodebuild -project GlassLookStore.xcodeproj -scheme GlassLookStore -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates archive
  cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>debugging</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$OUT/export" \
    -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates
  mv "$OUT"/export/*.ipa "$IPA"
else
  xcodebuild -project GlassLookStore.xcodeproj -scheme GlassLookStore -configuration Release \
    -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" archive
  APP="$ARCHIVE/Products/Applications/GlassLookStore.app"
  # Ad-hoc signature with the App Group so the widget can read the session (the sideloading tool re-signs it).
  codesign -f -s - --entitlements GlassLookStoreWidget/GlassLookStoreWidget.entitlements "$APP/PlugIns/GlassLookStoreWidget.appex"
  codesign -f -s - --entitlements GlassLookStore/GlassLookStore.entitlements "$APP"
  rm -rf "$OUT/Payload" && mkdir -p "$OUT/Payload"
  cp -R "$APP" "$OUT/Payload/"
  (cd "$OUT" && zip -qry "$(basename "$IPA")" Payload && rm -rf Payload)
fi
ls -lh "$IPA"
