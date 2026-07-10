# Mobile Store Release Guide

Snapshot date: 2026-07-10

The mobile release path is fail-closed. Source configuration and automated
tests now prevent a store artifact from using a local/HTTP API, development
login bypass, missing signing values, a missing keystore, or Android debug
keys. The production upload key, store accounts, and final signed artifacts are
external release inputs and are not stored in this repository.

Current evidence from the 2026-07-10 local pass:

- Android release configuration fails when `AARAST_API_BASE_URL` is missing.
- Android release configuration fails when store signing is missing.
- Android resources, adaptive launcher icon, and native splash compile.
- iOS Release validates the same API/login-bypass rules through an Xcode build
  phase; the shell gate passed a public/local/IPv6/malformed-IP test matrix.
- `flutter analyze` passed and all 418 Flutter tests passed.
- Final AAB generation and certificate verification are intentionally deferred
  at the product owner's request. They are not marked PASS.

## 1. Generate and protect the Android upload keystore

Generate this once, keep at least two encrypted backups, and never commit it:

```powershell
keytool -genkeypair -v `
  -keystore $env:USERPROFILE\aarast-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias aarast-upload
```

`keytool` ships with a JDK. Android Studio also bundles it under
`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe`.

## 2. Configure Android signing

Use one of these two private configuration paths.

Local release workstation: copy `mobile/android/key.properties.example` to the
git-ignored `mobile/android/key.properties` and provide all four values:

```properties
storeFile=C:/Users/you/aarast-upload.jks
storePassword=...
keyAlias=aarast-upload
keyPassword=...
```

CI/private environment: provide the equivalent variables without writing a
properties file:

```text
AARAST_ANDROID_STORE_FILE
AARAST_ANDROID_STORE_PASSWORD
AARAST_ANDROID_KEY_ALIAS
AARAST_ANDROID_KEY_PASSWORD
```

Any missing/placeholder value or nonexistent keystore stops Release during
Gradle configuration. There is no debug-signing fallback.

## 3. Build Android with the production API origin

```powershell
cd mobile
flutter build appbundle --release `
  --dart-define=AARAST_API_BASE_URL=https://aarast-api.shadowgardn.com
```

Release also rejects `AARAST_DEV_BYPASS_LOGIN_GATES=true`. The API URL must be
an explicit public HTTPS host without credentials, query, fragment, localhost,
private IPv4, malformed numeric IPv4, or IPv6 literal.

Expected output after a successful build:
`mobile/build/app/outputs/bundle/release/app-release.aab`.

Flutter requires Android command-line tools, including `apkanalyzer`, to prove
that native debug symbols were stripped into `BUNDLE-METADATA`. A stripping
verification failure is a release blocker even if an AAB file exists; do not
upload that artifact.

## 4. Verify the Android signer

```powershell
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

Confirm the owner is the production upload certificate and never
`CN=Android Debug`. Record the production SHA-256 fingerprint for Play Console
and `assetlinks.json`. Never substitute a temporary verification certificate.

## 5. iOS release gate

Run Archive from a macOS/Xcode host with the real Apple team and provisioning
profile. The Runner target includes:

- `NSContactsUsageDescription` for selected contact import.
- `Runner.entitlements` with `applinks:aarast.shadowgardn.com`.
- a Release-only configuration validation phase for the HTTPS API origin and
  disabled development login bypass.
- branded AppIcon and LaunchImage assets.

Windows static checks cannot prove Xcode signing, archive creation, App Store
validation, or real-device Universal Links. Those remain external release
gates.

## 6. External link association

Before store submission, publish and verify:

- `https://aarast.shadowgardn.com/.well-known/assetlinks.json` using the real
  Android package and production signing fingerprint.
- `https://aarast.shadowgardn.com/.well-known/apple-app-site-association` using
  the real Apple Team ID and bundle ID.

Test both canonical invite forms on real devices:

- `https://aarast.shadowgardn.com/invites/TOKEN`
- `aarast://open/invites/TOKEN`

## 7. Upload sequence

- Increment the `+build` integer in `mobile/pubspec.yaml` for every upload.
- Upload Android to the Play internal-testing track first and enable Play App
  Signing.
- Upload iOS through TestFlight first.
- Complete `STORE_LISTING.md`, `PLAY_DATA_SAFETY.md`, screenshots, privacy
  policy hosting, and store declarations from observed production behavior.

## Pre-submission checklist

- [ ] Production Android upload key generated and backed up
- [ ] Signing secrets configured outside Git
- [ ] Public HTTPS API dart-define supplied; dev bypass disabled
- [ ] `flutter analyze` and full Flutter tests pass on the release commit
- [ ] Android AAB builds without symbol-stripping verification failure
- [ ] AAB signer is the production upload key, not debug/temporary
- [ ] iOS Archive succeeds on macOS with the real team/profile
- [ ] Android App Links and iOS Universal Links pass on physical devices
- [ ] `versionCode`/`CFBundleVersion` incremented
- [ ] Privacy policy, data-safety form, listing text, and screenshots are ready
