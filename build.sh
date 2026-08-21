#!/bin/bash
set -e
cd "$(dirname "$0")"

APP=Autoclicker.app
IDENTITY="Autoclicker Dev"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -parse-as-library main.swift -O -o "$APP/Contents/MacOS/Autoclicker"
cp Info.plist "$APP/Contents/"
cp Assets/AppIcon.icns "$APP/Contents/Resources/"

if security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
  codesign --force -s "$IDENTITY" "$APP"
else
  # no stable cert -> ad-hoc signature changes every build, so drop stale TCC grant
  codesign --force -s - "$APP"
  tccutil reset Accessibility local.autoclicker || true
fi
echo "Built $APP — run: open $APP"
