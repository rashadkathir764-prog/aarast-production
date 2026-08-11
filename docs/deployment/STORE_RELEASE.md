# Mobile Store Release Guide

Snapshot date: 2026-08-11

The mobile release path is fail-closed. Source configuration and automated
tests now prevent a store artifact from using a local/HTTP API, development
login bypass, missing signing values, a missing keystore, or Android debug
keys. The production upload key, store accounts, and final signed artifacts are
external release inputs and are not stored in this repository.

Historical local evidence from the 2026-07-17 production-origin APK pass is
listed below. It is not current store acceptance, a production deployment, or
proof that the external signing, store-console, asset, Apple, or device gates
have passed:

- Android release configuration fails when `AARAST_API_BASE_URL` is missing.
- Android release configuration fails when store signing is missing.
- Android resources, adaptive launcher icon, and native splash compile.
- iOS Release validates the same API/login-bypass rules through an Xcode build
  phase; the shell gate passed a public/local/IPv6/malformed-IP test matrix.
- `flutter analyze` passed and all 628 Flutter tests passed.
- A production-origin APK (`versionCode=4`) is signed by the dedicated Aarast
  4096-bit upload certificate through APK Signature Scheme v2, is not
  debuggable, and has artifact SHA-256
  `108210A5DEC6723915DEF3A9855B035F51A7D5FF6646B58B7066E8987A7530FE`.
- The upload keystore is outside Git with a local OS-protected secret and a
  second encrypted-keystore backup. Final AAB generation, Play App Signing,
  and physical-device verification remain separate gates.

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

Load the approved Firebase client values and Sentry configuration from the
protected release environment. Do not copy them into this file, source control,
or shell history. `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, and `SENTRY_PROJECT` are
CI/plugin environment values only; never pass the auth token through a Dart
define.

```powershell
cd mobile
$releaseSha = git rev-parse HEAD
$versionMatch = [regex]::Match(
  (Get-Content pubspec.yaml -Raw),
  '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$'
)
if (-not $versionMatch.Success) { throw 'Invalid pubspec version.' }
$buildName = $versionMatch.Groups[1].Value
$buildNumber = $versionMatch.Groups[2].Value
$releaseId = "aarast-mobile@$buildName+$buildNumber-$releaseSha"
$env:SENTRY_RELEASE = $releaseId
flutter build appbundle --release `
  --build-name=$buildName `
  --build-number=$buildNumber `
  --dart-define=AARAST_API_BASE_URL=https://aarast-api.shadowgardn.com `
  --dart-define=AARAST_FIREBASE_API_KEY=$env:AARAST_FIREBASE_API_KEY `
  --dart-define=AARAST_FIREBASE_APP_ID=$env:AARAST_FIREBASE_APP_ID `
  --dart-define=AARAST_FIREBASE_MESSAGING_SENDER_ID=$env:AARAST_FIREBASE_MESSAGING_SENDER_ID `
  --dart-define=AARAST_FIREBASE_PROJECT_ID=$env:AARAST_FIREBASE_PROJECT_ID `
  --dart-define=AARAST_SENTRY_DSN=$env:AARAST_SENTRY_DSN `
  --dart-define=AARAST_ENVIRONMENT=production `
  --dart-define=AARAST_SENTRY_TRACES_SAMPLE_RATE=0.1 `
  --dart-define=SENTRY_RELEASE=$releaseId
```

Release also rejects `AARAST_DEV_BYPASS_LOGIN_GATES=true`. The API URL must be
an explicit public HTTPS host without credentials, query, fragment, localhost,
private IPv4, malformed numeric IPv4, or IPv6 literal. Android Release also
fails closed when any of the four Firebase client values is absent. A
Production store build must use a real Sentry DSN and protected symbol-upload
credentials. Android `bundleRelease` enforces those inputs, a Production
environment, an explicit trace sample rate, and a revision-bound release ID.
An empty DSN is suitable only for local APK Release validation.

Expected output after a successful build:
`mobile/build/app/outputs/bundle/release/app-release.aab`.

For a non-store QA Release that must coexist with an already installed build,
the Android application ID and launcher label may be overridden explicitly:

```powershell
$env:AARAST_ANDROID_APPLICATION_ID = 'com.aarast.aarast_mobile.qa'
$env:AARAST_ANDROID_APP_LABEL = 'اعّرست QA'
flutter build apk --release `
  --dart-define=AARAST_API_BASE_URL=https://your-staging-api.example `
  --dart-define=AARAST_FIREBASE_API_KEY=$env:AARAST_FIREBASE_API_KEY `
  --dart-define=AARAST_FIREBASE_APP_ID=$env:AARAST_FIREBASE_APP_ID `
  --dart-define=AARAST_FIREBASE_MESSAGING_SENDER_ID=$env:AARAST_FIREBASE_MESSAGING_SENDER_ID `
  --dart-define=AARAST_FIREBASE_PROJECT_ID=$env:AARAST_FIREBASE_PROJECT_ID `
  --dart-define=AARAST_ENVIRONMENT=staging
```

The default remains `com.aarast.aarast_mobile` with the production launcher
label. Never use a QA application ID for a store artifact or production App
Links; Play signing and `assetlinks.json` must reference the production ID.

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

## 6. Public pages and external link association

The repository now contains an allowlisted public-site image for:

- `https://aarast.shadowgardn.com/privacy`
- `https://aarast.shadowgardn.com/support`
- `https://aarast.shadowgardn.com/invites/:token`
- `https://aarast.shadowgardn.com/.well-known/assetlinks.json`

The privacy and support pages contain no JavaScript, forms, analytics, or
third-party resources. The invite page uses a small first-party script that
keeps the validated token in page memory only. Every unlisted route returns
`404`, and Apple association deliberately remains `404` until the real Apple
identity is available.

Before store submission, deploy and verify:

- `https://aarast.shadowgardn.com/.well-known/assetlinks.json` using the real
  Android package and production signing fingerprint.
- `https://aarast.shadowgardn.com/.well-known/apple-app-site-association` using
  the real Apple Team ID and bundle ID.

The source image, immutable Compose entry, and local tests do not prove public
deployment. Verify TLS, headers, expected `200` routes, fail-closed routes, and
association identity from outside the hosting environment.

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
- [ ] Privacy and support URLs return the reviewed static pages over HTTPS
- [ ] Public-site random routes return `404`; Apple association stays `404`
      until the real Team ID association is published
- [ ] `versionCode`/`CFBundleVersion` incremented
- [ ] Privacy policy, data-safety form, listing text, and screenshots are ready

Final Android/iOS signing, Play/App Store accounts, store graphics and
screenshots, the Apple Team ID and provisioning profile, AAB/IPA upload, and
physical-device link/session checks are external gates. This guide must not be
used to claim that production deployment or store submission has happened.
