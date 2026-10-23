# Store privacy forms: answers for Stride

Use this to fill in Google Play's **Data safety** form and Apple's **App Privacy** labels. It reflects the code as of v1.0.0. Update it if what the app collects changes. The public policy is in `docs/PRIVACY.md`.

## Google Play: Data safety

**Does your app collect or share any of the required user data types?** Yes.
**Is all of the user data collected by your app encrypted in transit?** Yes (Firebase uses TLS).
**Do you provide a way for users to request that their data is deleted?** Yes: in-app (Settings → Delete account) and by email.

| Data type (Play category) | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Location → Precise location | Yes (signed-in users: run routes are uploaded) | No | Optional (only with an account; tracking itself is on-device) | App functionality |
| Personal info → Email address | Yes | No | Optional (account) | Account management |
| Personal info → User IDs | Yes (Firebase account ID) | No | Optional (account) | Account management |
| Health and fitness → Fitness info | Yes (runs: distance, pace, steps, calories) | No | Optional (account) | App functionality |
| Health and fitness → Health info | Yes (height, weight, age, gender in the profile) | No | Optional (account) | App functionality, personalisation |
| App info and performance → Crash logs, Diagnostics | Yes (Crashlytics, release builds) | No | Required | Analytics (crash diagnostics) |
| Device or other IDs | Yes (Crashlytics installation ID) | No | Required | Analytics (crash diagnostics) |

Not collected: name, phone number, address, contacts, photos, messages, financial info, web browsing, advertising ID.

Guests (no account) send nothing except crash reports.

### Location permission declaration (Play Console)

The app requests **background location** (`ACCESS_BACKGROUND_LOCATION`) and uses a **location foreground service**, so that a run keeps recording with the screen locked. Play requires:

- **The Location permissions declaration**, explaining that background location is used only during an active, user-started run, shown with a persistent notification.
- **A short video** showing: start a run → lock the screen → the notification is visible → unlock and the route continued.
- **Foreground service type `location`** justification (same use case).

## Apple: App Privacy (later, with the iOS release)

| Data type | Linked to user | Used for tracking | Purpose |
|---|---|---|---|
| Precise Location | Yes | No | App Functionality |
| Email Address | Yes | No | App Functionality |
| User ID | Yes | No | App Functionality |
| Fitness | Yes | No | App Functionality |
| Health (height, weight) | Yes | No | App Functionality |
| Crash Data | No | No | App Functionality |

Tracking (ATT): **No**. The app doesn't track users across apps or websites, so there's no ATT prompt.
