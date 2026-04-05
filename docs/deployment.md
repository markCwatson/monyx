# Deploy to App Store Connect

## Prerequisites

- Active [Apple Developer Program](https://developer.apple.com/programs/) membership ($99/yr)
- App record created in [App Store Connect](https://appstoreconnect.apple.com) with bundle ID `dev.markcwatson.atlix`
- Xcode signed with your distribution certificate (Runner → Signing & Capabilities → select your team)

## 1. Bump the build number

Each upload requires a unique build number. Increment the `+N` portion in `pubspec.yaml`:

```yaml
version: 1.0.0+3 # +N must be higher than the last uploaded build
```

## 2. Build the release archive

```bash
flutter clean
flutter pub get
flutter build ipa --release --dart-define-from-file=.env
```

This produces an `.xcarchive` in `build/ios/archive/` and an `.ipa` in `build/ios/ipa/`.

## 3. Upload via Xcode

```bash
open build/ios/archive/Runner.xcarchive
```

This opens the Xcode **Organizer** window:

1. Select the archive and click **Distribute App**
2. Choose **App Store Connect** → **Upload**
3. Follow the signing and validation prompts
4. Wait for the upload to complete

## 4. TestFlight

After upload, the build takes ~10–30 minutes to process in App Store Connect:

1. Go to **App Store Connect → TestFlight**
2. Answer the **Export Compliance** question (select "No" if the app only uses HTTPS)
3. **Internal testers** (up to 100) — available immediately, no review needed
4. **External testers** (up to 10,000) — requires a brief Beta App Review

## 5. Submit for App Store review

1. In App Store Connect, go to your app → **App Store** tab
2. Fill in screenshots, description, keywords, promotional text, privacy policy URL, and support URL
3. Select the build from your TestFlight uploads
4. Click **Submit for Review**

> **Important:** The Mapbox public token is baked in at compile time via `--dart-define-from-file=.env`. If you build or archive from Xcode directly (without the Flutter CLI), the token will be empty and the map will show a black screen. Always use `flutter build ipa` first.
