# Publishing Stride on Google Play: step by step

A checklist for getting **Stride by Moops** onto Google Play under the **Moops Design** name. Moops Design is a sole proprietorship with the owner's PAN. Work through it in order and tick things off. Google changes these rules from time to time, so if a screen doesn't match, trust the Play Console and ask.

Time needed: about 1 day of your own work, plus waiting time of up to 30 days for the D-U-N-S number and a few days for Google's verification.

---

## Part 0: Choose the account type (decided: Organization)

| | **Organization account** (recommended) | Personal account |
|---|---|---|
| Name shown on Google Play | **Moops Design** (legal name from D-U-N-S), plus a developer name such as "Moops" | **Your own legal name**, even if the developer name is "Moops" |
| Also shown publicly | Legal **address**, developer email, developer **phone** | Country and developer email (full address only if the app makes money) |
| Extra paperwork | **D-U-N-S number** (free, up to 30 days) + business registration | Personal ID only |
| Before going live | No mandatory test period | **Closed test with 12+ testers for 14 days in a row**, then apply for production |
| Fee | US$25 one-time | US$25 one-time |

Since you want the account under the Moops name, go **Organization**. Two things to decide now:

- **The address will be public.** Register the business at an address you're comfortable showing (an office or co-working address rather than home, if possible). The same address has to be used everywhere: Udyam, D-U-N-S and Google.
- **The phone number will be public.** Use a business number if you have one.

---

## Part 1: Business paperwork (start today; this is the slow part)

### 1.1 Udyam (MSME) registration: free, online, same day
A sole proprietorship has no registration certificate of its own. Udyam gives Moops Design an official document with its name and address, which D&B and Google can check against.

- [ ] Go to **udyamregistration.gov.in** → "For New Entrepreneurs who are not Registered yet as MSME".
- [ ] Use **your Aadhaar** and **your PAN**. Type of organisation: **Proprietorship**. This is normal: a proprietorship uses the owner's PAN.
- [ ] Name of enterprise: **MOOPS DESIGN**, spelled exactly as you want it everywhere.
- [ ] Address: the public business address from Part 0.
- [ ] Activity: Services. NIC code for software or computer programming services, for example 62011/62013.
- [ ] Download the **Udyam Registration Certificate (PDF)**.

GST registration is only needed if your turnover requires it. It isn't required for a free app.

### 1.2 Website and email: make them match
Google asks for an organization website and checks that it looks like the business.

- [ ] **moops.in** shows the name **Moops Design** and the **same address** (footer or contact page), plus contact email **info@moops.in** and a phone number.
- [ ] Publish the privacy policy at, for example, **https://moops.in/stride/privacy** (content: `docs/PRIVACY.md`).
- [ ] **info@moops.in** can receive mail. Google and D&B both send verification codes.

### 1.3 D-U-N-S number: free, up to 30 days
- [ ] Request it **free** from Dun & Bradstreet India (dnb.co.in → "Get a D-U-N-S Number"), or through Apple's free D-U-N-S lookup tool, which forwards new requests to D&B.
- [ ] Legal name: **MOOPS DESIGN** (sole proprietor: your name). Address: **exactly** as on Udyam.
- [ ] Keep your Udyam certificate and PAN handy. D&B may email or call to verify.
- [ ] Ignore offers to pay for faster processing. The standard number is free.
- [ ] When it arrives, write it down: `D-U-N-S: _____________`.

**The name and address must match character for character** across D&B, Udyam and the Google payments profile in Part 3. Mismatches are the most common reason accounts get flagged.

---

## Part 2: A Google account for the business (10 minutes)

- [ ] Create a Google account that the business owns, for example using **info@moops.in** ("Use my current email address instead" on the sign-up page), or a dedicated Gmail. This account owns the developer account permanently, so don't use a throwaway.
- [ ] Turn on **2-Step Verification**. Play Console requires it.
- [ ] Have an **international debit or credit card** ready for the US$25 fee. Indian cards need international transactions enabled.

---

## Part 3: Create the Play Console organization account (once you have the D-U-N-S)

1. [ ] Go to **play.google.com/console/signup**, signed in with the business Google account.
2. [ ] Choose **"An organization or business"**.
3. [ ] **Payments profile:** create a new **Business** profile. Name: **MOOPS DESIGN**. Address: the same address again. Enter the **D-U-N-S number**.
4. [ ] **Organization details:** organization phone, website **https://moops.in**, organization size and type.
5. [ ] **Developer profile** (public): developer name, for example **Moops** or **Moops Design**; developer email **info@moops.in**; developer phone; website.
6. [ ] **Contact details** (private, for Google): your name, email and phone.
7. [ ] Verify each email and phone with the one-time codes.
8. [ ] Pay the **US$25** fee.
9. [ ] **Verification:** Google may ask for documents, such as the Udyam certificate or a bank document showing the business name and address, and may verify the payment method. It can take several days. Watch the inbox.

When the account shows as verified, you're ready to create the app.

---

## Part 4: Prepare the app for upload (do this with Claude)

Steps 4.1 and 4.2 are yours; the rest Claude can do from the repo.

### 4.1 Create the upload key: once, keep it forever
```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
mkdir -p ~/keys
"$JAVA_HOME/bin/keytool" -genkey -v -keystore ~/keys/stride-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias stride-upload
```
- [ ] Store the `.jks` file **and both passwords** in a password manager, with an encrypted backup elsewhere.
- [ ] Create `android/key.properties` (gitignored; never commit it):
  ```properties
  storeFile=/Users/prateek/keys/stride-upload.jks
  storePassword=YOUR_STORE_PASSWORD
  keyAlias=stride-upload
  keyPassword=YOUR_KEY_PASSWORD
  ```

With **Play App Signing** (the default, and recommended), Google holds the real app signing key. This file is only the *upload* key, so if it's ever lost Google can reset it. Still, don't lose it.

### 4.2 Accept the Android SDK licences
- [ ] Run `flutter doctor --android-licenses` and accept. This is your agreement to make.

### 4.3 Add the upload key's fingerprints to Firebase
- [ ] `"$JAVA_HOME/bin/keytool" -list -v -keystore ~/keys/stride-upload.jks -alias stride-upload`, then copy the **SHA-1** and **SHA-256**.
- [ ] Firebase console → project **moops-stride** → Project settings → Android app `in.moops.stride` → **Add fingerprint** (both).
- [ ] Download the new **google-services.json** and replace `android/app/google-services.json`.

### 4.4 Build the App Bundle
- [ ] `pubspec.yaml` `version:` is `1.0.0+1` for the first upload. The number after `+` must go up for every later upload.
- [ ] `flutter build appbundle --release` → `build/app/outputs/bundle/release/app-release.aab`.

---

## Part 5: Create the app in Play Console

- [ ] **Home → Create app.** App name: **Stride by Moops** (30 characters max). Default language: English (United States or India). App or game: **App**. Free or paid: **Free**. Accept the declarations.

---

## Part 6: The "Set up your app" checklist (Dashboard)

Each item is a form. Suggested answers for Stride:

| Section | Answer |
|---|---|
| **Privacy policy** | `https://moops.in/stride/privacy` (from Part 1.2) |
| **App access** | All functionality is available without special access. Sign-in is optional and only backs up runs. |
| **Ads** | No, the app doesn't contain ads |
| **Content rating** | Fill in the IARC questionnaire honestly (category: Utility/Productivity/Communication/Other; no violence, gambling or user-to-user chat). Expect "Everyone" / 3+. |
| **Target audience** | 13 and over. The privacy policy says the app isn't directed at under-13s. |
| **News app** | No |
| **Data safety** | Copy from `docs/STORE_DATA_SAFETY.md` |
| **Government app** | No |
| **Financial features** | None |
| **Health apps** | Declare it as an activity/fitness tracking app (no medical or diagnostic claims) |
| **Foreground service permissions** | Location: tracks a user-started run while the screen is locked, with a persistent notification. Needs a short **video**. |
| **Location permissions (background)** | Same use case. Needs a **video**: start a run → lock the screen → notification visible → unlock and the route has continued. See `docs/STORE_DATA_SAFETY.md`. |
| **App category** | Health & Fitness. Contact email info@moops.in, website moops.in. |

### Store listing (Grow → Store presence → Main store listing)
- [ ] **Short description** (max 80 characters), for example: *A cute, offline-first run tracker with Moop. No account needed.*
- [ ] **Full description** (max 4000 characters). Claude can draft it from the README.
- [ ] **App icon:** 512 × 512 PNG, up to 1 MB. Claude can export it from `assets/brand/icon/app-icon-source.png`.
- [ ] **Feature graphic:** 1024 × 500 PNG/JPG, no transparency. Claude can make one in the app's style.
- [ ] **Phone screenshots:** 2 to 8. **The long side may be at most 2× the short side.** The current README screenshots are 1220 × 2712 (about 2.2×), so they need padding or cropping to 9:16 (for example 1080 × 1920). Claude can produce store-ready versions.

---

## Part 7: Internal testing (fast, up to 100 testers)

Internal testing is the quickest way to install the real Play build on your own phones. It usually becomes available within minutes, without the full review.

1. [ ] **Test and release → Testing → Internal testing → Create new release.**
2. [ ] Accept **Play App Signing** (default) when asked.
3. [ ] Upload **app-release.aab**. Release name is automatic. Release notes, for example: *First internal build.*
4. [ ] **Save → Review release → Start rollout to Internal testing.**
5. [ ] **Testers tab → Create email list** (for example "Moops team") → add Gmail/Google-account emails (up to 100) → save.
6. [ ] Copy the **opt-in link**. Each tester opens it, taps **Become a tester**, then installs Stride from the Play Store link on that page.

### Required right after the first upload: Google sign-in
Play re-signs the app with Google's key, so Google sign-in will **fail** in Play-installed builds until:
- [ ] **Test and release → App integrity → App signing:** copy the **App signing key certificate** SHA-1 and SHA-256.
- [ ] Add both to Firebase (as in 4.3), download the new **google-services.json**, then rebuild and upload a new version (bump the `+` number).

---

## Part 8: Closed and open testing (optional for organization accounts)

The 12-testers-for-14-days rule applies only to **personal** accounts created after 13 Nov 2023, and internal testing doesn't count toward it. As an organization you can go to production after internal testing. A closed test with friends is still a good idea for real-world feedback.

---

## Part 9: Production

- [ ] **Test and release → Production → Countries/regions:** choose India (and others you want).
- [ ] **Create new release:** promote the tested build or upload a new one → release notes → **Review → Send for review**.
- [ ] The first review for a new developer account can take **up to about 7 days** or longer. You'll get an email.
- [ ] After approval, Stride appears under the developer name you chose.

---

## Quick reference

| Thing | Value |
|---|---|
| Package name | `in.moops.stride` (permanent; can't change after the first upload) |
| App name | Stride by Moops |
| Legal name | MOOPS DESIGN (sole proprietorship) |
| Website / email | moops.in / info@moops.in |
| Privacy policy | https://moops.in/stride/privacy (`docs/PRIVACY.md`) |
| Data safety answers | `docs/STORE_DATA_SAFETY.md` |
| Build commands | `docs/RELEASE.md` |
| Firebase project | moops-stride |
