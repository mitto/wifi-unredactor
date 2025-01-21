#!/bin/bash

APP_NAME="wifi-unredactor"
DEST_DIR="$HOME/Applications"
APP_DIR="$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

echo "ビルドディレクトリを準備中..."
mkdir -p "$MACOS_DIR"

echo "Swift Package Managerでビルド中..."
swift build -c release
if [ $? -ne 0 ]; then
    echo "ビルドに失敗しました。"
    exit 1
fi

echo "実行ファイルをコピー中..."
cp ".build/release/$APP_NAME" "$MACOS_DIR/"

# Info.plistが存在しない場合は作成
if [ ! -f "$CONTENTS_DIR/Info.plist" ]; then
    echo "Info.plistを作成中..."
    cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.example.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>11.0</string>
    <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
    <string>WiFi情報を取得するために位置情報へのアクセスが必要です。</string>
</dict>
</plist>
EOF
fi

echo "$APP_NAMEを$DEST_DIRにインストール中..."
mkdir -p "$DEST_DIR"
rm -rf "$DEST_DIR/$APP_DIR"
cp -R "$APP_DIR" "$DEST_DIR"

echo "インストールが完了しました。$APP_NAMEは$DEST_DIRで利用可能です。"
