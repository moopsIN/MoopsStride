# Releasing Stride

How to cut a store build. Android first; iOS is a later step and is listed at the end.

## One-time Android setup

### 1. Create the upload keystore

Use the JDK that ships with Android Studio:

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
"$JAVA_HOME/bin/keytool" -genkey -v \
  -keystore ~/keys/stride-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias stride-upload
```

Keep the `.jks` file and its passwords in a password manager. If they are lost, you can no longer publish updates. Never commit them; `*.jks` and `android/key.properties` are gitignored.

### 2. Point the build at it

Create `android/key.properties`:

```properties
storeFile=/Users/<you>/keys/stride-upload.jks
storePassword=<store password>
keyAlias=stride-upload
keyPassword=<key password>
```

If this file is missing, release builds fall back to the debug key. That's fine for local testing but can't be uploaded to Play.

### 3. Register the fingerprints in Firebase (required for Google sign-in)

Google sign-in **fails in release builds** unless the signing certificate's SHA-1 and SHA-256 are added in Firebase (Project settings → Your apps → Android → Add fingerprint).

```bash
"$JAVA_HOME/bin/keytool" -list -v -keystore ~/keys/stride-upload.jks -alias stride-upload
```

With **Play App Signing** (the default), Google re-signs the app with its own key. Also add the **app signing key** fingerprints from Play Console → Test and release → App integrity. After adding fingerprints, download the new `google-services.json` and replace `android/app/google-services.json`.

## Every Android release

1. Bump `version:` in `pubspec.yaml`. The part after `+` is the Android versionCode and must increase every upload. Example: `1.0.1+2`.
2. Build the bundle:
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`. Release builds use R8 code and resource shrinking; keep rules are in `android/app/proguard-rules.pro`.
3. Smoke test a release build on a real phone before uploading:
   ```bash
   flutter run --release
   ```
   Check: fresh install → onboarding, sign in with Google and email, a run with the screen locked, sync, sign out, delete account.
4. Upload the `.aab` to an internal testing track first.

## Backend

Firestore rules live in `firestore.rules`, with tests in `firestore-tests/`. Deploy any rules changes before or with the app release:

```bash
firebase deploy --only firestore:rules
```

## Console tasks that aren't in code

- **Restrict the MapTiler key** (cloud.maptiler.com → API keys) to the app's package name `in.moops.stride` and iOS bundle id.
- **Play Console data safety form and location declaration:** answers are in `docs/STORE_DATA_SAFETY.md`.
- **Privacy policy URL:** publish `docs/PRIVACY.md` (for example at moops.in/stride/privacy) and link it in both stores and in the app listing.

## iOS (later)

- Set the signing team and bundle id in Xcode (`ios/Runner.xcworkspace`).
- Add the iOS app's URL scheme for Google sign-in, from `GoogleService-Info.plist` (`REVERSED_CLIENT_ID`), if it isn't there yet.
- Build with `flutter build ipa --release` and upload through Xcode or Transporter.
