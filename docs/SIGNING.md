# SlighRes — Signing & Notarization Notes

## For Personal Use (Simplest)

If you only run the app on your own Mac, ad-hoc signing is sufficient:

```bash
# Build in Xcode (Release), then:
codesign --force --deep --sign - \
  ~/Library/Developer/Xcode/DerivedData/SlighRes-*/Build/Products/Release/SlighRes.app
```

Or just run directly from Xcode — it signs with your local development
certificate automatically.

### Gatekeeper bypass (first launch)

If macOS blocks the app:

1. **System Settings → Privacy & Security** → scroll down → click
   "Open Anyway" next to the SlighRes warning.
2. Or: right-click the `.app` → **Open** → confirm.

---

## For Sharing with Others

If you distribute the app outside the App Store (e.g. via GitHub Releases),
you need:

1. **Apple Developer ID certificate** ($99/year Apple Developer Program).
2. **Hardened Runtime** (already enabled in the project).
3. **Notarization** via `notarytool`.

### Step-by-step

```bash
# 1. Archive
xcodebuild -project SlighRes.xcodeproj \
           -scheme SlighRes \
           -configuration Release \
           -arch arm64 \
           archive -archivePath build/SlighRes.xcarchive

# 2. Export
xcodebuild -exportArchive \
           -archivePath build/SlighRes.xcarchive \
           -exportPath build/export \
           -exportOptionsPlist ExportOptions.plist

# 3. Create DMG or ZIP
cd build/export
ditto -c -k --keepParent SlighRes.app SlighRes.zip

# 4. Notarize
xcrun notarytool submit SlighRes.zip \
     --apple-id you@example.com \
     --team-id YOURTEAMID \
     --password @keychain:AC_PASSWORD \
     --wait

# 5. Staple (so offline installs work)
xcrun stapler staple SlighRes.app
```

### ExportOptions.plist (minimal)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOURTEAMID</string>
</dict>
</plist>
```

---

## Entitlements

The app ships with sandbox **disabled** (`com.apple.security.app-sandbox =
false`) because `CGConfigureDisplayWithDisplayMode` does not work inside the
sandbox. Hardened Runtime is still enabled for notarization compatibility.

## No Special Permissions Needed

CoreGraphics display configuration APIs do not require TCC permissions
(no Accessibility, Screen Recording, etc. prompts).
