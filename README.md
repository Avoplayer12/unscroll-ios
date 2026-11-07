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


## How the gate works

The Shortcuts automation for each app runs **Should Show Gate** (an Unscroll action). If it returns true, it opens `unscroll://gate?app=TikTok`. When you choose *Open anyway*, Should Show Gate returns false for 5 minutes, so the gate doesn't loop.

## Not in version 1

Real app blocking needs Apple's Family Controls permission, which must be requested from Apple. It's planned for version 2.
