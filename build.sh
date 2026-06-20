#!/bin/bash
set -e
cd "$(dirname "$0")"

APP="WorklogBuddy.app"
BIN="WorklogBuddy"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

echo "Compiling…"
swiftc -swift-version 5 -O Sources/main.swift -o "$APP/Contents/MacOS/$BIN" -framework AppKit -framework ServiceManagement

cp Info.plist "$APP/Contents/Info.plist"

echo "Built $APP"
echo "Run with: open $APP   (or ./$APP/Contents/MacOS/$BIN to see logs)"
