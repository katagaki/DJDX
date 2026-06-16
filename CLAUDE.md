# Code Style

- Do not add explanatory/verbose comments. No doc-comment blocks describing what a
  type does, no inline comments narrating what the next line does, no rationale prose.
  Write code that reads on its own. `// MARK:` section markers are fine.
- Match the comment density of the surrounding file, which is essentially none.

# Project Notes

- The Xcode project uses synchronized root groups (Xcode 16). New source files added
  under the source folders are picked up automatically — do not edit `project.pbxproj`.
- `Shared/Localizable.xcstrings` is a JSON string catalog (source language `ja`,
  locales `en`/`ja`). Edit it by hand to preserve Xcode's formatting (2-space indent,
  spaces around colons, raw unicode, alphabetically sorted keys). Do not rewrite it via
  a JSON serializer — that reorders/re-escapes the whole file into a massive diff.
- Build/verify with:
  `xcodebuild build -project DJDX.xcodeproj -scheme DJDX -destination 'generic/platform=iOS Simulator' -configuration Debug`
- The four web importers (DDR, SDVX, Polaris Chord, IIDX) share one structure: a
  SwiftUI wrapper over a `UIViewRepresentable` `WKWebView` + a `WKNavigationDelegate`
  coordinator. Changes to import behavior usually need applying to all four.
