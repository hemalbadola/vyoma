#!/usr/bin/env bash
# Build APK, publish to GitHub Releases, rebuild web manifest, deploy Hosting (no APK on Hosting — Spark plan).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

node scripts/sync-release-from-git.mjs
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | sed 's/+.*//')
TAG="v${VERSION}"
REPO=$(git remote get-url origin | sed -E 's/.*github.com[:/](.+)(\.git)?/\1/')

flutter pub get
flutter build apk --release
APK="build/app/outputs/flutter-apk/app-release.apk"
test -f "$APK"

echo "Publishing $TAG to GitHub Releases ($REPO)…"
gh release view "$TAG" 2>/dev/null && gh release delete "$TAG" -y --cleanup-tag || true
NOTES=$(git log -1 --format=%B)
cp "$APK" /tmp/vyoma.apk
gh release create "$TAG" /tmp/vyoma.apk --repo "$REPO" --title "Vyoma $TAG" --notes "$NOTES"

export GITHUB_REPOSITORY="$REPO"
export ANDROID_DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG}/vyoma.apk"
node scripts/sync-release-from-git.mjs

rm -f vyoma-ui/public/vyoma.apk
(cd vyoma-ui && npm ci && npm run build)
firebase deploy --only hosting
echo "APK: $ANDROID_DOWNLOAD_URL"
