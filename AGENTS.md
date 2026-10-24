# Repository Layout

- `Apple/` — DJDX for iOS, iPadOS and watchOS (Xcode project, SwiftUI).
- `Android/` — DJDXGo, the Android port of the iOS app (Gradle, Kotlin, Jetpack Compose).
- `Studio/` — DJDX PEAK Studio, a macOS tool for labeling IIDX result screens and
  training/exporting the Core ML models used by the iOS app (SwiftPM + Python).

Run build commands from inside the relevant folder.

# Code Style

- Do not add explanatory/verbose comments. No doc-comment blocks describing what a
  type does, no inline comments narrating what the next line does, no rationale prose.
  Write code that reads on its own. `// MARK:` section markers are fine.
- Match the comment density of the surrounding file, which is essentially none.

# Apple

- The Xcode project uses synchronized root groups (Xcode 16). New source files added
  under the source folders are picked up automatically — do not edit `project.pbxproj`.
- `Apple/Shared/Localizable.xcstrings` is a JSON string catalog (source language `ja`,
  locales `en`/`ja`). Edit it by hand to preserve Xcode's formatting (2-space indent,
  spaces around colons, raw unicode, alphabetically sorted keys). Do not rewrite it via
  a JSON serializer — that reorders/re-escapes the whole file into a massive diff.
- Build/verify from `Apple/` with:
  `xcodebuild build -project DJDX.xcodeproj -scheme DJDX -destination 'generic/platform=iOS Simulator' -configuration Debug`
- SwiftLint runs as a build phase using `Apple/.swiftlint.yml`.
- The four web importers (DDR, SDVX, Polaris Chord, IIDX) share one structure: a
  SwiftUI wrapper over a `UIViewRepresentable` `WKWebView` + a `WKNavigationDelegate`
  coordinator. Changes to import behavior usually need applying to all four.
- `Apple/DJDX.xcodeproj/xcshareddata/xcodecloud/` is gitignored and must never be staged.

# Android

- Package versions and SDK targets follow the sibling CirclesGo repository (AGP, Kotlin,
  Compose BOM, SDK 37, minSdk 26).
- No system Java is installed; build from `Android/` with the Android Studio bundled JDK:
  `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleDebug`
- Signing config is read from the gitignored `Android/local.properties`. Never commit it
  or any keystore.
- Strings are localized in EN (default) and JA, split across per-module files
  (`strings.xml`, `strings_iidx.xml`, `strings_games.xml`, `strings_import.xml`,
  `strings_analytics.xml`, `strings_external.xml`) in `values/` and `values-ja/`.
- All four web importers share one WebView structure (`ui/importer` + `importer/ImporterJavaScript.kt`).
  Changes to import behavior usually need applying to all four, and usually mirror the
  iOS importers in `Apple/`.
- The UI follows Material You (dynamic color, tonal cards) rather than the iOS app's
  green accent and translucent cards. Game-semantic colors (clear lamps, difficulties)
  are fixed in `ui/theme/GameColors.kt`.
- `.github/workflows/android-deploy.yml` deploys to the Play Store internal track on
  pushes to `main` that touch `Android/**`.

# Studio

- SwiftPM package with no Xcode project. Build from `Studio/` with `swift build`, or
  `./bundle.sh` to assemble `Outputs/DJDX PEAK Studio.app`.
- Training scripts live in `Studio/Training` and are run with `uv`.
- `Studio/Inputs/` (source photos) and `Studio/Outputs/` (models, crops, previews, the
  app bundle) are gitignored and must never be committed. Only labels are tracked.
- Exported `.mlpackage` models are copied into
  `Apple/DJDX/Games/beatmania IIDX/Sessions/Models/` for the iOS app's result detection.
