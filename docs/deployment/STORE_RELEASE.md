# Play Store Release Guide

Snapshot date: 2026-07-08

Everything needed to publish the Aarast Android app. The signing pipeline
is verified working (a release AAB built and signature-verified against a
real upload key on 2026-07-08); the only step that requires you is
generating and safeguarding your own production keystore.

## 1. Generate your upload keystore (once)

Losing this key locks you out of the Play listing forever — generate it
once, back it up in at least two safe places, and never commit it.

```powershell
keytool -genkeypair -v `
  -keystore $env:USERPROFILE\aarast-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias aarast-upload
```

`keytool` ships with any JDK. If it is not on PATH, use the one bundled
with Android Studio:
`"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"`.

## 2. Point the build at it

Copy `mobile/android/key.properties.example` to
`mobile/android/key.properties` (git-ignored) and fill in real values:

```properties
storeFile=C:/Users/you/aarast-upload.jks
storePassword=...
keyAlias=aarast-upload
keyPassword=...
```

Without `key.properties`, a release build silently falls back to debug
keys so `flutter run --release` still works — but such a build is
**not** uploadable. The Gradle config in
`mobile/android/app/build.gradle.kts` handles this switch automatically.

## 3. Build the signed bundle

```powershell
cd mobile
flutter build appbundle --release
```

Output: `mobile/build/app/outputs/bundle/release/app-release.aab`.

(The build may print "failed to strip debug symbols from native
libraries" on Windows — this is a cosmetic NDK warning; the AAB is still
produced and correctly signed.)

## 4. Verify the signature before uploading

```powershell
keytool -printcert -jarfile build\app\outputs\bundle\release\app-release.aab
```

Confirm the Owner is your `CN=...` and NOT `CN=Android Debug`. Record
the SHA-256 fingerprint; Play App Signing will show the same value.

## 5. Upload

- Play Console → create app → upload the AAB to the internal testing
  track first.
- Enrol in **Play App Signing** (recommended): Google manages the app
  signing key; your `aarast-upload.jks` stays as the upload key only.
- Complete the store listing (`docs/deployment/STORE_LISTING.md`) and
  the data-safety form (`docs/deployment/PLAY_DATA_SAFETY.md`).
- Link the privacy policy URL (host `docs/legal/PRIVACY_POLICY.md`).

## Version bumping

`versionCode`/`versionName` come from `mobile/pubspec.yaml`
(`version: x.y.z+build`). Increment the `+build` integer for every
upload — Play rejects a duplicate `versionCode`.

## Pre-submission checklist

- [ ] Own keystore generated and backed up (not the verification key)
- [ ] `key.properties` filled, confirmed git-ignored
- [ ] `flutter build appbundle --release` succeeds
- [ ] AAB signer certificate is the upload key, not debug
- [ ] `versionCode` incremented since the last upload
- [ ] Privacy policy hosted at a public URL
- [ ] Data-safety form matches `PLAY_DATA_SAFETY.md`
- [ ] Store listing text and screenshots ready
