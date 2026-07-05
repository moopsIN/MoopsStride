# Moops Stride — Detailed Phased Development & Testing Plan

This document outlines the detailed phased development and testing strategy for **Moops Stride**. It ensures a "local-first, cloud-optional" architecture and high-polish showcase quality. 

**Development & Version Control Principle:** 
Throughout the development process, we will meaningfully document the work and **ensure frequent, granular local Git commits for every meaningful change or feature addition** (not just at the end of phases). Once the development reaches a mature state, the local repository will be pushed to a remote GitHub repository.

---

## Phase 1: Foundation & Architecture Setup
**Objective:** Finalize project scaffolding, set up state management, and build the local data layer.
**Development Tasks:**
- Initialize `Firebase.initializeApp()` in `main.dart`.
- Add Google Maps API key placeholders in Android/iOS native files and update Location permission strings (`Info.plist` & `AndroidManifest.xml`).
- Scaffold folder structure and setup Riverpod for state management.
- Implement Local Storage (`sqflite` or `drift`) with the schema:
  - `activities` (id, type, start_time, end_time, distance, duration, pace, calories, route_polyline, synced)
  - `splits` & `user_profile`
- **Git:** Commit initial architecture, Firebase wire-up, and database schema separately.
**Testing:**
- **Unit Testing:** Database CRUD operations (insert, fetch, update records).
- **Unit Testing:** Riverpod providers initialization and local state management logic.

## Phase 2: Base UI/UX & Design System
**Objective:** Establish the visual identity, dark/light themes, and reusable UI components.
**Development Tasks:**
- Define the Design System: Typography, Colors, Themes (Dark-first), and Glassmorphism utilities.
- Build reusable UI widgets (Stat Cards, Action Buttons, Bottom Sheets).
- Develop "Empty States" and "Skeleton Loaders" for data-dependent screens.
- Build the Splash Screen (with animated logo/mark transition).
- **Git:** Commit design system foundations and core widgets incrementally.
**Testing:**
- **Widget Testing:** Verify UI components render correctly in both Dark and Light modes.
- **Widget Testing:** Ensure Glassmorphism layers and typography scale correctly on different simulated device sizes.

## Phase 3: Auth & Onboarding Flow
**Objective:** Build the user entry points, including guest mode and profile creation.
**Development Tasks:**
- Implement Auth UI: Email/Password, Social Auth buttons, and "Continue as Guest" option.
- Build the 4-step Onboarding Flow (Goal → Experience Level → Height/Weight → Activity Level).
- Implement smooth transitions between onboarding steps.
- Create Profile/Settings skeleton (Units toggle, Dark Mode toggle).
- **Git:** Commit auth UI, onboarding flow, and profile skeleton in logical steps.
**Testing:**
- **Widget Testing:** UI transitions in the onboarding flow.
- **Integration Testing:** "Guest Mode" onboarding loop (Launch → Onboard → Land on Home).

## Phase 4: Core Tracking & Location Services
**Objective:** Develop the core "Active Tracking" loop using GPS and Google Maps.
**Development Tasks:**
- Build Home Dashboard UI (static local data, "Start" CTA, streak indicator).
- Integrate `google_maps_flutter` and `geolocator`.
- Build Active Tracking Screen: Live map, route polyline drawing, and live stats calculation (distance, pace, duration).
- Implement Pause/Resume/Stop controls with hero transitions from Home to Tracking.
- **Git:** Commit Home UI, Maps integration, and tracking logic iteratively.
**Testing:**
- **Unit Testing:** GPS distance/pace calculation logic and polyline encoding/decoding.
- **Integration Testing:** Mock GPS coordinates to simulate a run, verifying the route draws and stats update correctly.

## Phase 5: Run Summary & Progress Data Visualization
**Objective:** Allow users to view and analyze their tracked activities.
**Development Tasks:**
- Build the Run Summary Screen: Staggered card entrance animations, route map, and per-km splits.
- Build the Progress/History Screen: Activity list with filters.
- Integrate `fl_chart` for pace/distance line charts and build the calendar streak heatmap.
- Implement logic for calculating Personal Records (fastest 5k, longest distance).
- **Git:** Commit Summary screen, Charts integration, and PR logic individually.
**Testing:**
- **Widget Testing:** fl_chart rendering and heatmap edge cases (e.g., month rollovers).
- **Integration Testing:** Completing a tracked run and verifying it correctly propagates to the Run Summary and Progress screens.

## Phase 6: Cloud Sync (Firestore)
**Objective:** Activate cloud features for signed-in users, syncing local data to Firebase.
**Development Tasks:**
- Implement Firebase Authentication backend logic (Email/Password & Google Sign-In).
- Develop the Firestore Sync Engine: On login, push local unsynced activities to Firestore.
- Implement dual-write logic: On new saves (if online), write to both local and Firestore.
- Handle offline state: queue data locally and sync opportunistically.
- **Git:** Commit Auth logic, sync engine, and offline-handling iteratively.
**Testing:**
- **Unit Testing:** Mock Firestore to verify sync logic (offline queuing, batch writing, `synced` flag updates).
- **Integration Testing:** Sign in user, verify local data uploads, and verify dual-writes work.

## Phase 7: AI Coach Integration (Gemini)
**Objective:** Integrate the Gemini API via a secure Cloudflare Worker proxy.
**Development Tasks:**
- Scaffold the Cloudflare Worker to accept `{ prompt_type, recent_activity_summary }`.
- Connect Worker to Gemini Flash-Lite to return structured JSON.
- Implement the AI Coach UI: "Quick-prompt" chips on the Home dashboard.
- Build the "Coach's take" auto-populated insight card on the Progress screen.
- Optional: Add post-run "Ask coach about this run" contextual button.
- **Git:** Commit Cloudflare Worker script, AI UI components, and API integration steps.
**Testing:**
- **Unit Testing:** Cloudflare Worker response parsing and error handling for the AI JSON output.
- **Integration Testing:** End-to-end test of requesting an AI plan and rendering the resulting JSON card.

## Phase 8: Final Polish, Animations & Security
**Objective:** Finalize edge cases, add delight features, and secure the app.
**Development Tasks:**
- Add light Gamification: Local-only badges for milestones.
- Stub out a "Pro" tier UI (UI only, no payment backend).
- Perform a comprehensive animation sweep (hero transitions, micro-interactions) ensuring 60fps.
- Configure Firebase Security Rules (Lock down Firestore to only allow users to read/write their own data).
- **Git:** Commit gamification, polish sweeps, and security rules.
**Testing:**
- **End-to-End (E2E) Integration Testing:** Complete flows for a signed-in user (Login → Sync → Track Run → Get AI Feedback → Log out).
- **Performance Profiling:** Run Flutter DevTools in profile mode on physical devices to guarantee smooth animations and map rendering.
