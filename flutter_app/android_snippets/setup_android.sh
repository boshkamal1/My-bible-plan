#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."
GRADLE=android/app/build.gradle
[ -f "$GRADLE" ] || GRADLE=android/app/build.gradle.kts
PKG=$(grep -E 'namespace' "$GRADLE" | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
[ -n "$PKG" ] || { echo "package not found"; exit 1; }
DIR=android/app/src/main/kotlin/$(echo "$PKG" | tr . /)
RES=android/app/src/main/res
mkdir -p "$DIR" "$RES/layout" "$RES/drawable" "$RES/xml"
sed "s/PACKAGE_NAME/$PKG/" android_snippets/BibleWidgetProvider.kt > "$DIR/BibleWidgetProvider.kt"
cp android_snippets/bible_widget.xml "$RES/layout/bible_widget.xml"
cp android_snippets/bible_widget_bg.xml "$RES/drawable/bible_widget_bg.xml"
cp android_snippets/bible_widget_info.xml "$RES/xml/bible_widget_info.xml"
echo "Widget files copied for package $PKG"
echo "Now merge android_snippets/AndroidManifest_additions.xml into android/app/src/main/AndroidManifest.xml"
