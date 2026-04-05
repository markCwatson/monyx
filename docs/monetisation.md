# Monetisation

The app is free with ads (AdMob). A "Atlix Pro" monthly subscription removes ads and unlocks additional features.

## Ads (Google AdMob)

Banner ads are shown at the bottom of the map screen for free-tier users.

| Item                       | Value                                                                                      |
| -------------------------- | ------------------------------------------------------------------------------------------ |
| **AdMob App ID (iOS)**     | `ca-app-pub-8357274860394786~5697764011`                                                   |
| **Banner Ad Unit (iOS)**   | `ca-app-pub-8357274860394786/3355400651`                                                   |
| **Test/Release switching** | Automatic — `kReleaseMode` in [lib/services/ad_service.dart](lib/services/ad_service.dart) |
| **Banner type**            | Anchored adaptive (auto-sizes to device width)                                             |

**How it works:**

- Debug / simulator builds use Google's test ad unit ID → shows a "Test Ad" label, safe to tap.
- Release builds (`flutter build ipa`) use the real ad unit ID → real ads served.
- The App ID in `ios/Runner/Info.plist` (`GADApplicationIdentifier`) is always the real one — only ad _unit_ IDs switch.
- Pro subscribers never see ads — the banner is not loaded when `SubscriptionCubit` reports `SubscriptionPro`.

## Subscription (In-App Purchase)

| Item           | Value                                                  |
| -------------- | ------------------------------------------------------ |
| **Product ID** | `atlix_pro_monthly`                                    |
| **Type**       | Auto-renewable subscription, 1 month                   |
| **Price**      | $4.99/mo (configure in App Store Connect)              |
| **Benefits**   | No ads, unlimited rifle/ammo profiles, animal track ID |

The subscription is managed by `SubscriptionService` → `SubscriptionCubit`. Free users see a single profile, a banner ad, and no track ID access. Pro users see a profile list, no ads, and full access to animal track identification.

**For production**, the subscription is configured in **App Store Connect** — you create the product there with the same product ID (`atlix_pro_monthly`), set the price, and submit for review. The app code talks to the real App Store automatically; no code changes are needed.

## Testing Subscriptions Locally (Xcode StoreKit)

Xcode's StoreKit Configuration lets you simulate purchases **locally in the simulator** without an App Store Connect account or sandbox tester. This is **only for development/testing** — it has no effect on production builds.

### One-time setup

The StoreKit config file must be created inside Xcode (hand-authored JSON won't work reliably):

1. Open the Xcode workspace:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. **File → New → File** (⌘N) → search for **StoreKit** → select **StoreKit Configuration File** → **Next**.
3. Name it `AtlixProducts`, set Group to `Runner`, ensure the target is checked → **Create**.
4. In the visual editor, click **+** → **Add Auto-Renewable Subscription**:
   - **Group name**: `Atlix Pro`
   - **Reference Name**: `Atlix Pro Monthly`
   - **Product ID**: `atlix_pro_monthly` ← must match exactly
   - **Price**: `2.99`
   - **Duration**: `1 Month`
   - Add a display name/description in the Localization section.
5. Set the scheme to use it: **Product → Scheme → Edit Scheme** (⌘⇧<) → **Run → Options** → **StoreKit Configuration** → select `AtlixProducts.storekit`.

### Running with StoreKit

**Important:** `flutter run` does not apply Xcode scheme settings. To test IAP you must launch from Xcode:

1. First, generate the dart-define config (only needed when `.env` changes):
   ```bash
   flutter run --dart-define-from-file=.env
   ```
   Then stop the app (`q`).
2. In Xcode, press **⌘R** to build and run. Xcode applies the StoreKit config at launch.
3. In the app, tap the FAB (profile button) → tap the **★ Upgrade to Pro** banner → tap **Subscribe**.
4. Xcode's StoreKit test environment handles the purchase immediately — no Apple ID needed.
5. The app should hide the banner ad and unlock unlimited profiles.

For everything else (map, ballistics, ads), `flutter run --dart-define-from-file=.env` works fine.

### Manage test transactions

In Xcode: **Debug → StoreKit → Manage Transactions**. From here you can:

- **Approve / decline** pending transactions
- **Refund** a purchase (test the downgrade flow)
- **Delete** all transactions (reset to free tier)
- **Force renewal** to simulate a subscription renewing

### Expire or cancel

In the transaction manager, select the subscription and click **Cancel Subscription** or **Request Refund** to test what happens when a user downgrades.

> **Note:** The `.storekit` file is only for local testing. It has no secrets and no effect on production. Real subscriptions are managed entirely in App Store Connect.
