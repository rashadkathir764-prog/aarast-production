# Mobile Store Release Guide

Snapshot date: 2026-08-11

The mobile release path is fail-closed. Source configuration and automated
tests now prevent a store artifact from using a local/HTTP API, development
login bypass, missing signing values, a missing keystore, or Android debug
keys. The production upload key, store accounts, and final signed artifacts are
external release inputs and are not stored in this repository.

Latest local Android Release evidence from 2026-08-11 is bounded to the exact
artifact below. It is not Play/App Store acceptance or device-flow approval:

- Source revision: `2ffbe95d7a8e412ead47220536046501f4ac86bf`.
- Package/version: `com.aarast.aarast_mobile`, `1.0.0+8`; min SDK 24 and target
  SDK 36.
- APK path: `mobile/build/app/outputs/flutter-apk/app-release.apk`; size
  88,634,008 bytes; SHA-256
  `075D82E24BEF4DED75F34D663B76132C9A6D6F89C7FE6535009C734A0CA1C69D`.
- The APK is non-debuggable, APK Signature Scheme v2 verification passes, and
  the Aarast RSA-3072 upload signer matches the production Android
  `assetlinks.json` identity.
- The Production HTTPS API origin and private Firebase client configuration are
  embedded. The Sentry release identifier is
  `aarast-mobile@1.0.0+8-2ffbe95d7a8e412ead47220536046501f4ac86bf`, but the
  Sentry DSN is intentionally empty for this local artifact.
- This is a signed direct-install APK, not a store AAB. Play App Signing, final
  AAB upload, physical-device OTP/Push/session acceptance, iOS Archive, and
  store review remain separate gates.

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

Production revision `900897a90e8b030c7c3ddfdc55cc2669b64f2e87` now serves
the allowlisted public-site image for:

- `https://aarast.shadowgardn.com/privacy`
- `https://aarast.shadowgardn.com/support`
- `https://aarast.shadowgardn.com/invites/:token`
- `https://aarast.shadowgardn.com/.well-known/assetlinks.json`

The privacy and support pages contain no JavaScript, forms, analytics, or
third-party resources. The invite page uses a small first-party script that
keeps the validated token in page memory only. Every unlisted route returns
`404`, and Apple association deliberately remains `404` until the real Apple
identity is available.

External TLS, headers, expected `200` routes, fail-closed routes, and the
Android package/upload-signing identity passed from outside the hosting
environment. Before store submission, repeat Android association with the
final Play App Signing certificate. Apple association remains `404` and must be
published only with the real Apple Team ID and bundle ID.

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
- [x] Privacy and support URLs return the reviewed static pages over HTTPS
- [x] Public-site random routes return `404`; Apple association stays `404`
      until the real Team ID association is published
- [ ] `versionCode`/`CFBundleVersion` incremented
- [ ] Privacy policy, data-safety form, listing text, and screenshots are ready

Final Android/iOS signing, Play/App Store accounts, store graphics and
screenshots, the Apple Team ID and provisioning profile, AAB/IPA upload, and
physical-device link/session checks are external gates. The web/API production
deployment is recorded separately and does not imply store submission.
