// Security-rules tests for ../firestore.rules. Payloads mirror exactly what
// lib/features/sync/providers/sync_engine.dart writes.
//
//   cd firestore-tests && npm install && npm test
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc, setLogLevel, writeBatch } from 'firebase/firestore';

setLogLevel('error');

let env;
const ALICE = 'alice';
const BOB = 'bob';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-stride',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const runRef = (uid, id, as = uid) => doc(db(as), `users/${uid}/activities/${id}`);
const userRef = (uid, as = uid) => doc(db(as), `users/${uid}`);

// What _toCloud(row) sends: the local SQLite row minus `synced`.
const run = (id, overrides = {}) => ({
  id,
  type: 'run',
  start_time: 1761200000000,
  end_time: 1761201800000,
  distance_meters: 5230.5,
  duration_seconds: 1800,
  avg_pace: 5.73,
  calories_estimate: 342.2,
  route_polyline: '[[22.71,75.85],[22.72,75.86]]',
  steps: 6104,
  updated_at: 1761201800000,
  deleted: 0,
  splits: '{"unit":1000.0,"splits":[[1000.0,371]]}',
  ...overrides,
});

const tombstone = (id) => ({ id, deleted: 1, updated_at: 1761300000000 });

const profile = (overrides = {}) => ({
  goal: 'Endurance',
  experience_level: 'Beginner',
  gender: 'Female',
  age: 29,
  height: 165.0,
  weight: 58.5,
  activity_level: 'Light',
  units_preference: 'km',
  updated_at: 1761200000000,
  ...overrides,
});

const seed = (path, data) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));

describe('ownership', () => {
  test('signed-out users can do nothing', async () => {
    await seed('users/alice/activities/r1', run('r1'));
    await assertFails(getDoc(doc(db(null), 'users/alice/activities/r1')));
    await assertFails(setDoc(doc(db(null), 'users/alice/activities/r2'), run('r2')));
    await assertFails(getDoc(doc(db(null), 'users/alice')));
  });

  test("users can't read or write someone else's data", async () => {
    await seed('users/alice/activities/r1', run('r1'));
    await seed('users/alice', { profile: profile() });
    await assertFails(getDoc(runRef(ALICE, 'r1', BOB)));
    await assertFails(setDoc(runRef(ALICE, 'r9', BOB), run('r9')));
    await assertFails(deleteDoc(runRef(ALICE, 'r1', BOB)));
    await assertFails(getDoc(userRef(ALICE, BOB)));
    await assertFails(setDoc(userRef(ALICE, BOB), { profile: profile() }));
  });

  test('everything outside users/{uid} is denied', async () => {
    await assertFails(setDoc(doc(db(ALICE), 'leaderboard/x'), { a: 1 }));
    await assertFails(getDoc(doc(db(ALICE), 'leaderboard/x')));
    await assertFails(setDoc(doc(db(ALICE), 'users/alice/secrets/x'), { a: 1 }));
  });
});

describe('runs', () => {
  test('the app\'s push (set with merge) is allowed', async () => {
    await assertSucceeds(setDoc(runRef(ALICE, 'r1'), run('r1'), { merge: true }));
    await assertSucceeds(getDoc(runRef(ALICE, 'r1')));
  });

  test('nullable fields may be null (no route, no splits)', async () => {
    await assertSucceeds(setDoc(runRef(ALICE, 'r1'), run('r1', { route_polyline: null, splits: null })));
  });

  test('walks are allowed; unknown types are not', async () => {
    await assertSucceeds(setDoc(runRef(ALICE, 'w1'), run('w1', { type: 'walk' })));
    await assertFails(setDoc(runRef(ALICE, 'x1'), run('x1', { type: 'teleport' })));
  });

  test('chunked batch push of many runs is allowed', async () => {
    const fs = db(ALICE);
    const batch = writeBatch(fs);
    for (let i = 0; i < 50; i++) batch.set(doc(fs, `users/alice/activities/b${i}`), run(`b${i}`), { merge: true });
    await assertSucceeds(batch.commit());
  });

  test('id must match the document path', async () => {
    await assertFails(setDoc(runRef(ALICE, 'r1'), run('other')));
  });

  test('unknown fields are rejected', async () => {
    await assertFails(setDoc(runRef(ALICE, 'r1'), run('r1', { isAdmin: true })));
    await assertFails(setDoc(runRef(ALICE, 'r1'), run('r1', { synced: 1 })));
  });

  test('required fields must be present', async () => {
    const { distance_meters, ...missing } = run('r1');
    await assertFails(setDoc(runRef(ALICE, 'r1'), missing));
  });

  test('types and ranges are enforced', async () => {
    const bad = [
      { distance_meters: -1 },
      { distance_meters: 2000000 },
      { distance_meters: '5000' },
      { duration_seconds: 1.5 },
      { duration_seconds: 999999999 },
      { start_time: 'yesterday' },
      { end_time: 1761100000000 }, // before start
      { avg_pace: -3 },
      { calories_estimate: -1 },
      { steps: -10 },
      { deleted: 1 }, // full run must not claim to be deleted
    ];
    for (const o of bad) {
      await assertFails(setDoc(runRef(ALICE, 'r1'), run('r1', o)), JSON.stringify(o));
    }
  });

  test('oversized route or splits are rejected', async () => {
    await assertFails(setDoc(runRef(ALICE, 'r1'), run('r1', { route_polyline: 'x'.repeat(900001) })));
    await assertFails(setDoc(runRef(ALICE, 'r1'), run('r1', { splits: 'x'.repeat(100001) })));
  });

  test('a run can be deleted outright by its owner (Start Fresh / account deletion)', async () => {
    await seed('users/alice/activities/r1', run('r1'));
    await assertSucceeds(deleteDoc(runRef(ALICE, 'r1')));
  });
});

describe('tombstones', () => {
  test('the app\'s tombstone overwrite is allowed', async () => {
    await seed('users/alice/activities/r1', run('r1'));
    await assertSucceeds(setDoc(runRef(ALICE, 'r1'), tombstone('r1')));
    const snap = await getDoc(runRef(ALICE, 'r1'));
    if (snap.data().route_polyline !== undefined) throw new Error('route should be erased');
  });

  test('tombstones must have exactly id, deleted=1 and updated_at', async () => {
    await assertFails(setDoc(runRef(ALICE, 'r1'), { ...tombstone('r1'), route_polyline: '[]' }));
    await assertFails(setDoc(runRef(ALICE, 'r1'), { ...tombstone('r1'), deleted: 2 }));
    await assertFails(setDoc(runRef(ALICE, 'r1'), { id: 'r1', deleted: 1 }));
    await assertFails(setDoc(runRef(ALICE, 'r1'), tombstone('other')));
  });

  test('a run restored after a tombstone (merge over it) is allowed', async () => {
    await seed('users/alice/activities/r1', tombstone('r1'));
    await assertSucceeds(setDoc(runRef(ALICE, 'r1'), run('r1'), { merge: true }));
  });
});

describe('profile', () => {
  test('the app\'s profile push (merge into users/{uid}) is allowed', async () => {
    await assertSucceeds(setDoc(userRef(ALICE), { profile: profile() }, { merge: true }));
    await assertSucceeds(getDoc(userRef(ALICE)));
  });

  test('fields may be null (older local rows)', async () => {
    await assertSucceeds(setDoc(userRef(ALICE), { profile: profile({ units_preference: null, goal: null }) }));
  });

  test('only the profile key is allowed on the user doc', async () => {
    await assertFails(setDoc(userRef(ALICE), { profile: profile(), role: 'admin' }));
  });

  test('profile fields are allow-listed, typed and bounded', async () => {
    const bad = [
      { isPro: true },
      { age: 400 },
      { age: '29' },
      { height: -5 },
      { weight: 9000 },
      { units_preference: 'furlongs' },
      { goal: 'x'.repeat(41) },
    ];
    for (const o of bad) {
      await assertFails(setDoc(userRef(ALICE), { profile: profile(o) }), JSON.stringify(o));
    }
  });

  test('the owner can delete their user doc (wipe / account deletion)', async () => {
    await seed('users/alice', { profile: profile() });
    await assertSucceeds(deleteDoc(userRef(ALICE)));
  });
});
