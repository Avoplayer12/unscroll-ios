# Unscroll for iPhone

A native SwiftUI app to spend less time scrolling. iOS 17 or later.

- **Focus**: a timer that keeps the screen on and counts every time you leave the app. Sends a notification when it ends.
- **Train**: one-minute drills: math sprint, number memory, box breathing.
- **Track**: log your daily Screen Time and see 14 days in a chart against your goal.
- **Gate**: a 10-second pause before TikTok, Instagram and other apps, started by an iPhone Shortcuts automation.
- **More**: notification setting, delete all data, privacy.

No account, no ads, no tracking. Data is saved on the iPhone only.

## Files

| File | What it is |
| --- | --- |
| `project.yml` | Project settings. XcodeGen turns it into `Unscroll.xcodeproj`. |
| `Unscroll/*.swift` | The app code. |
| `Unscroll/Assets.xcassets` | App icon and accent color. |
| `.github/workflows/build.yml` | Builds the app on a free GitHub Mac to check that it compiles. |
| `codemagic.yaml` | Builds and uploads to the App Store with Codemagic. |

## Check that it builds (free, no Mac)

1. Create a new GitHub repository called `unscroll-ios` and upload everything in this folder, including the `.github` folder.
2. Open the **Actions** tab. The "Build iOS app" job runs on a GitHub Mac. A green check means the app compiles.

## Publish to the App Store (needs an Apple Developer account, $99 a year)

1. Join the Apple Developer Program at developer.apple.com.
2. In App Store Connect, create a new app with bundle ID `com.avoplayer12.unscroll`.
3. In App Store Connect → Users and Access → Integrations, create an API key (role: App Manager).
4. Sign up at codemagic.io with GitHub, add the `unscroll-ios` repository, and add the API key under Team integrations → Developer Portal. Name it `Unscroll API key`.
5. Start the **Unscroll to App Store** workflow. The build appears in TestFlight. Test it, then submit it for review in App Store Connect.

## How the gate works

The Shortcuts automation for each app runs **Should Show Gate** (an Unscroll action). If it returns true, it opens `unscroll://gate?app=TikTok`. When you choose *Open anyway*, Should Show Gate returns false for 5 minutes, so the gate doesn't loop.

## Not in version 1

Real app blocking needs Apple's Family Controls permission, which must be requested from Apple. It's planned for version 2.
