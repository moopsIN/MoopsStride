# Moops Stride — Product & Engineering Plan

**Type:** Boutique showcase app (portfolio/demo quality over feature breadth)
**Core activity:** Walking & running tracking, with light AI coaching
**Platform:** Flutter (iOS + Android)
**Backend:** Firebase (free tier / Spark plan where possible)
**Maps:** Google Maps Platform (free tier / monthly credit)
**AI:** Gemini API (Flash / Flash-Lite)

---

## 0. Current project state (as of handoff to Antigravity)

This section reflects what has already been done manually, so the agent does not repeat or re-scaffold these steps.

**Completed:**
- [x] Flutter project created (`flutter create`), org/package name set, confirmed running on Android emulator and iOS simulator via `flutter run`.
- [x] Firebase project created in console (Authentication enabled: Email/Password + Google; Firestore Database created in test mode).
- [x] Firebase CLI + FlutterFire CLI installed locally; `flutterfire configure` run successfully — `lib/firebase_options.dart`, `google-services.json` (Android), and `GoogleService-Info.plist` (iOS) are in place.
- [x] Core dependencies added via `flutter pub add` and `flutter pub get` run:
  - `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`
  - `sqflite`, `path_provider`
  - `google_maps_flutter`, `geolocator`
  - `fl_chart`, `flutter_animate`
  - `flutter_riverpod`
  - `http`

**Not yet done — left for the agent to handle as part of the build:**
- [ ] `Firebase.initializeApp()` wiring in `main.dart` (may exist as boilerplate only — verify/complete).
- [ ] Google Maps API key integration:
  - Android key → `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY` meta-data tag)
  - iOS key → `ios/Runner/AppDelegate.swift` (`GMSServices.provideAPIKey(...)`)
  - **Use placeholder string values for both keys for now** (e.g. `"YOUR_ANDROID_MAPS_API_KEY"` / `"YOUR_IOS_MAPS_API_KEY"`) — real keys will be inserted manually later once Google Cloud Console setup is done.
- [ ] Location permission strings (`NSLocationWhenInUseUsageDescription` in `Info.plist`; `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` in `AndroidManifest.xml`).
- [ ] Gemini API integration and the Cloudflare Worker proxy described in Section 7 — **use a placeholder API key/config for now**; the real Gemini key will be added manually once the proxy is scaffolded. Do not hardcode a real key into client code under any circumstance — the placeholder should live in the Worker/server-side config, not in the Flutter app.
- [ ] Firestore security rules (currently test mode — must be locked down before any real usage; not required to function during initial development, but flag this as outstanding).
- [ ] All actual screens, local SQLite schema, sync logic, and UI per Sections 5–7 below — this is the main body of work for the agent.

---

## 1. Purpose of this document

This is the single source of truth for building Moops Stride. It defines scope, design language, architecture, data model, and phased delivery. The guiding principle for every decision in this app:

> **Depth over breadth.** One core loop (start → track → finish → review) built to a premium, polished standard beats many shallow features. Every screen should look and feel intentional — this app exists to demonstrate craftsmanship, not to be a full-featured fitness suite.

---

## 2. Naming & branding

**App name:** **Moops Stride**

- "Stride" is neutral to both walking and running (unlike "Run", which excludes walkers).
- Reads calm and premium rather than aggressive/gym-bro — fits the Apple Fitness-esque tone, not a hardcore performance-tracker vibe.
- Company brand "Moops" is preserved as the prefix across all products.

**Tagline (working):** *"Every step, beautifully tracked."*

**App icon direction:** A single abstract stride/path mark (like a stylized "S" curve or footprint-path glyph), not literal shoe/running iconography — should look at home next to minimal, premium app icons (Apple Fitness, Oura, etc.), not busy/cartoonish.

---

## 3. Design language

### 3.1 Visual style
- **Dark mode first**, with a light mode as secondary (not the reverse) — dark backgrounds make gradients, glass panels, and data visualizations pop, which is a core part of the "premium" feel this app needs to sell.
- **Glassmorphism** for card surfaces: translucent panels, subtle blur, soft borders (1px, low-opacity white/gray) — used for stat cards, the AI Coach card, and bottom sheets. Do not overuse it; reserve for cards that deserve visual weight (hero stats, not every list row).
- **Accent color:** a single vivid accent (e.g. an electric lime, coral, or cyan — pick one and use it consistently for CTAs, progress rings, and active states). Everything else stays neutral (near-black, charcoal, soft white) so the accent reads as intentional, not noisy.
- **Typography:** one geometric/rounded sans for numbers and headlines (e.g. a variable font like SF Pro Rounded–equivalent, or a Google Font like "Manrope" or "Plus Jakarta Sans"), consistent weight hierarchy: large bold numerals for stats, medium weight for labels.
- **Motion:** every screen transition, button press, and data update should be animated — this is the app's core selling point. No default Flutter page transitions; use custom hero animations, shared element transitions (map → summary), and spring-based micro-interactions.

### 3.2 Signature UI moments (the "showcase" elements)
These are the specific interactions that should get disproportionate polish, since they are what a reviewer/client will remember:
1. **Splash → onboarding transition** — a fluid animated intro (e.g. animated stride/path drawing itself).
2. **Start Run button → Active Tracking screen** — hero/shared-element transition, not a hard cut.
3. **Live map tracking** — smooth route drawing in real time, animated stat counters (distance/pace ticking up, not just re-rendering).
4. **Run summary reveal** — staggered card entrance (map settles in, then stats cascade in one by one).
5. **Progress heatmap** — calendar heatmap with a tap-to-expand day, animated fill.
6. **Pull-to-refresh & skeleton loading** — used consistently across Home and Progress, never a bare spinner.
7. **Empty states** — every list/chart has a designed empty state (illustration + short copy), never a blank screen.

### 3.3 Design references (mood, not to copy 1:1)
- Apple Fitness — stat rings, calm dark UI
- Strava / Nike Run Club — route visualization, post-run summary
- Oura / Whoop — glass cards, minimal data typography

---

## 4. Scope — what's in, what's out

### In scope (v1)
- Onboarding (goal, stats, activity level)
- Auth (email + one social provider)
- Guest mode (no login required to use core tracking)
- Home dashboard
- Live GPS run/walk tracking
- Post-run summary
- Progress/history (charts, streak heatmap, PRs)
- Profile/settings (units, dark mode, notifications)
- AI Coach — scoped, structured, quick-prompt driven (see Section 7)

### Explicitly out of scope (do not build, do not scaffold)
- Nutrition/meal tracking, macros, food database
- Strength/HIIT/yoga workout libraries
- Social feed, likes, comments, leaderboards, challenges
- Open-ended AI chat ("ask me anything")
- Payments/subscriptions (may be stubbed as a UI-only "Pro" badge if time allows, but no real payment integration in v1)

If asked to expand later, treat each of the above as a separate phase/app extension, not a v1 requirement.

---

## 5. Information architecture (screens)

1. **Splash** — animated logo/mark, brief, non-blocking
2. **Onboarding** — goal → experience level → gender (optional) → height/weight → activity level. 4–5 short steps, one question per screen, progress dots.
3. **Auth** — email/password + one social login (Google or Apple depending on platform). Includes a "Continue as guest" option.
4. **Home Dashboard**
   - Greeting (time-of-day aware)
   - "Start Walk/Run" primary CTA (large, hard to miss)
   - Today's stats: steps, distance, active time
   - Weekly summary progress ring
   - Streak indicator
   - Recent activity (last 2–3 runs, tappable)
   - AI Coach quick-prompt card (see Section 7)
5. **Active Tracking**
   - Live map with route drawn as user moves
   - Big live stats: distance, duration, pace, calories (estimated)
   - Pause / Resume / Stop controls
   - Optional audio/haptic split cues (e.g. every 1km)
6. **Run Summary** (post-run)
   - Route map with start/end pins
   - Per-km splits
   - Stat cards: pace, distance, duration, calories
   - "Ask coach about this run" (optional entry point)
   - Save / Discard
7. **Progress / History**
   - List of past activities (filter: all/run/walk, by date)
   - Line chart: pace or distance over time
   - Calendar heatmap: activity days
   - Personal records: fastest 5k, longest distance, longest streak
   - "Coach's take" auto-insight card (see Section 7)
8. **Profile / Settings**
   - Units (km/mi)
   - Dark/light mode toggle
   - Notification preferences
   - Account (sign in/out, delete guest data)
   - About / version info

---

## 6. Technical architecture

### 6.1 Core principle: local-first, cloud-optional
- **All activity data is written to local storage first**, regardless of login state. The app is fully functional offline and for guest users with zero cloud dependency.
- **Firestore sync activates only after the user creates an account.** This is a meaningful architectural choice, not a shortcut: it keeps Firestore usage (and cost) proportional to actual signed-in users, keeps the app fast (no network round-trip to read your own run history), and demonstrates a more sophisticated pattern ("local-first with optional sync") than a naive always-online app.

### 6.2 Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (latest stable) |
| Local storage | `sqflite` or `drift` (typed SQL) for structured run/activity data |
| Cloud database | Cloud Firestore (only for signed-in users; sync layer) |
| Auth | Firebase Authentication (email/password + Google Sign-In; Apple Sign-In if targeting iOS App Store) |
| Cloud storage | Firebase Storage — only if storing user avatars; route data stays in Firestore/local (avoid storing route polylines as files) |
| Maps & GPS | `google_maps_flutter` + `geolocator` (device GPS, no paid geolocation API needed) + Google Maps Platform free tier/monthly credit for map tiles |
| Charts | `fl_chart` (line charts, bar charts, radial progress) |
| State management | Riverpod (recommended) or Bloc — pick one and use consistently throughout |
| AI | Gemini API (`gemini-flash` / `gemini-flash-lite` tier) called via a lightweight serverless proxy (Cloudflare Worker — free tier), never called directly from the client |
| Push notifications | Firebase Cloud Messaging (optional, v1.1 — e.g. streak reminders) |
| Animations | Flutter's built-in animation APIs (`Hero`, `AnimatedContainer`, `implicit` animations) + `flutter_animate` package for cleaner declarative animation code |

### 6.3 Why a proxy for Gemini, not direct client calls
- Keeps the API key off-device (a client-embedded key can be extracted from the app binary).
- Allows server-side per-user rate limiting (e.g. "5 AI requests/day") to control cost — client-side limits are trivially bypassed.
- Cloudflare Workers has a genuinely free tier sufficient for this scale and doesn't require Firebase's paid Blaze plan (Firebase Cloud Functions now requires Blaze to use at all, even within free quota).

### 6.4 Data model (high level)

**Local (SQLite via sqflite/drift):**
```
activities
  id (uuid)
  type (run | walk)
  start_time
  end_time
  distance_meters
  duration_seconds
  avg_pace
  calories_estimate
  route_polyline (encoded string)
  synced (bool)  -- true once written to Firestore

splits
  activity_id (fk)
  split_index
  distance_meters
  duration_seconds

user_profile
  goal
  experience_level
  gender (optional)
  height, weight
  activity_level
  units_preference
```

**Firestore (mirrors local schema, only for signed-in users):**
```
users/{uid}/activities/{activityId}
users/{uid}/profile
```
Sync strategy: on login, push any local unsynced activities to Firestore; on activity save while online, write to both local and Firestore; if offline, mark `synced: false` locally and sync opportunistically (Firestore's built-in offline persistence handles the retry).

### 6.5 Firebase free-tier fit at 5,000–10,000 installs
- **Auth:** unlimited on free tier — no concern.
- **Firestore:** only signed-in users generate reads/writes, and one document per activity (not per data point) keeps volume well under the daily free quota even with a few thousand active accounts.
- **Cloud Functions:** avoided entirely in v1 — the AI proxy runs on Cloudflare Workers instead, sidestepping the Blaze-plan requirement.
- **Storage:** avoided for route data (kept as polyline strings in Firestore/SQLite, not files); only used if profile avatars are added.
- **Maps:** Google Maps Platform's monthly credit comfortably covers map tile loads at this install scale for a walk/run use case (occasional map views, not constant heavy tile fetching).

---

## 7. AI Coach — exact scope and integration

**Principle: the AI Coach is a feature woven into existing screens, not a standalone chatbot.** No open-ended "ask me anything" chat in v1.

### 7.1 What it does (three functions only)
1. **Plan generation from quick-prompts** — user taps a preset chip (e.g. "20-minute run", "Build endurance", "Recovery walk"), not a blank text field. Output renders as a structured plan card (e.g. warm-up / intervals / cool-down), not a paragraph of prose.
2. **Insight on the user's own data** — a "Coach's take" card on the Progress screen auto-generates a one-line trend summary (e.g. pace improving, streak status) from the user's own recent activity data. This is the highest-value, lowest-cost use case.
3. **Post-run reflection (optional)** — a single "Ask coach about this run" button on the Run Summary screen, scoped only to that run's data, not open conversation.

### 7.2 What it does NOT do
- No free-form general chat interface
- No injury/medical/pain guidance — hard-coded deflection to "consult a professional" if such topics are detected
- No nutrition advice

### 7.3 Integration points (UI)
- **Home Dashboard:** small card with 2–3 quick-prompt chips ("Plan today's run", "20 min only", "Rest day tips")
- **Progress screen:** "Coach's take" card, auto-populated (no user action needed to see it)
- **Run Summary:** single optional button, not a persistent chat icon

### 7.4 Technical flow
```
User taps a quick-prompt chip
   → App sends { prompt_type, recent_activity_summary } to Cloudflare Worker
   → Worker attaches system prompt + calls Gemini Flash-Lite
   → Requests STRUCTURED JSON output (not raw prose) so UI can render as cards
   → Response parsed and rendered as: plan card / insight text / short message
```

**System prompt (baseline):**
> "You are a walking/running coach. You will receive a short summary of the user's recent activity and a request type. Respond only in JSON: `{ "message": string, "plan": [{ "step": string, "duration_min": number }] | null }`. Tone: encouraging, concise, non-clinical. If the request relates to pain, injury, or medical concerns, set `plan` to null and respond only with guidance to consult a healthcare professional."

### 7.5 Cost control
- Rate-limit each user to a small daily cap (e.g. 5–10 requests/day), enforced server-side in the Worker.
- Send only a compact summary of recent activity (last 5–10 runs: date, distance, pace, duration) — never raw GPS traces — keeping token usage and cost minimal.
- Log requests server-side to monitor real usage before considering any expansion.

---

## 8. Phased delivery plan

**Phase 1 — Core loop (this is the MVP; ship this to a polished standard before anything else)**
- Onboarding, auth (+ guest mode), dark mode, base design system
- Home dashboard (static/local data)
- Active tracking screen (GPS + live map + live stats)
- Run summary screen
- Local storage (SQLite) for all activity data
- Progress screen: activity list, 1–2 chart types, streak heatmap

**Phase 2**
- Firestore sync for signed-in users
- Personal records logic
- AI Coach: quick-prompt plan generation + Progress "Coach's take" card
- Settings/profile polish, notifications (streak reminders)

**Phase 3 (only if time/interest remains — not required for the showcase goal)**
- Post-run "ask coach about this run"
- Light gamification (badges for milestones — purely local/rule-based, no leaderboard)
- Stubbed "Pro" tier UI (no real payment backend required for a demo)

---

## 9. Non-negotiables for "showcase" quality

Every Phase 1 screen must have, before being considered done:
- [ ] Custom transition in/out (no default platform transition)
- [ ] Skeleton loading state (not a spinner) for anything data-dependent
- [ ] A designed empty state (not a blank screen)
- [ ] Correct behavior in both dark and light mode
- [ ] Correct behavior fully offline (guest mode is the default test case)
- [ ] Smooth 60fps interaction — no janky list scrolling or animation stutter

If a screen doesn't meet these, it isn't finished — regardless of whether the underlying feature works.

---

## 10. Explicit reminders for whoever builds this

- Do not add nutrition, strength training, or social features "just in case" — every screen not in Section 5 is out of scope for v1.
- Do not build a general-purpose chat UI for the AI Coach — quick-prompt chips and structured cards only.
- Do not call Gemini directly from the Flutter client — always via the Cloudflare Worker proxy.
- Do not sync to Firestore for guest users — local storage only until login.
- Prioritize finishing Phase 1 to a high polish bar over starting Phase 2 early. A complete, buttery Phase 1 is a stronger demo than a half-finished full feature set.