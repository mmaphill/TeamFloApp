import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
    doc, setDoc, updateDoc, getDoc, deleteDoc,
    collection, collectionGroup, query, where, getDocs,
} from 'firebase/firestore';
import { ref, uploadString, deleteObject } from 'firebase/storage';
import fs from 'fs';

const env = await initializeTestEnvironment({
    projectId: 'demo-teamflo',
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
    storage: { rules: fs.readFileSync('storage.rules', 'utf8'), host: '127.0.0.1', port: 9199 },
});

let pass = 0, fail = 0;
async function t(name, p) {
    try {
        await p;
        pass++;
        console.log('PASS', name);
    } catch (e) {
        fail++;
        console.log('FAIL', name, e.message?.slice(0, 150));
    }
}

// Fake data, written with the rules turned off
await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore();

    // Team Flo (shared collections, like today)
    await setDoc(doc(db, 'users/alice'), { uid: 'alice', name: 'Alice', role: 'member' });
    await setDoc(doc(db, 'users/legacy'), { uid: 'legacy', name: 'Old' }); // no role, no gymId
    await setDoc(doc(db, 'users/oldadmin'), { uid: 'oldadmin', name: 'Boss', role: 'admin' });
    await setDoc(doc(db, 'users/mgr'), { uid: 'mgr', name: 'Manager', role: 'manager', gymId: 'teamflo' });
    await setDoc(doc(db, 'users/desk'), { uid: 'desk', name: 'Desk', role: 'front_desk', gymId: 'teamflo' });
    await setDoc(doc(db, 'users/instr'), { uid: 'instr', name: 'Instructor', role: 'instructor' });
    await setDoc(doc(db, 'gyms/teamflo'), { name: 'Team Flo', plan: 'academy' });
    await setDoc(doc(db, 'classHistory/c1_2026-10-16_alice'), { userId: 'alice', status: 'signedUp' });
    await setDoc(doc(db, 'classes/c1'), { className: 'Gi' });
    await setDoc(doc(db, 'posts/p1'), { userId: 'alice', content: 'Team Flo post' });
    await setDoc(doc(db, 'users/alice/journal/j1'), { userId: 'alice', notes: 'private-ish' });

    // A second gym (scoped: data under gyms/othergym/)
    await setDoc(doc(db, 'gyms/othergym'), { name: 'Other Gym', plan: 'academy', dataScoped: true });
    await setDoc(doc(db, 'users/ozzy'), { uid: 'ozzy', name: 'Ozzy', role: 'member', gymId: 'othergym' });
    await setDoc(doc(db, 'users/omgr'), { uid: 'omgr', name: 'Other Manager', role: 'manager', gymId: 'othergym' });
    await setDoc(doc(db, 'gyms/othergym/posts/op1'), { userId: 'omgr', content: 'Other gym post' });
    await setDoc(doc(db, 'gyms/othergym/classes/oc1'), { className: 'No Gi' });
    await setDoc(doc(db, 'users/ozzy/journal/oj1'), { userId: 'ozzy', gymId: 'othergym', notes: 'x' });
});

const as = uid => env.authenticatedContext(uid).firestore();
const anon = env.unauthenticatedContext().firestore();

// =====================================================================
// Steps 1-2 (unchanged)
// =====================================================================

// Sign-ups
await t('new member signup ok', assertSucceeds(setDoc(doc(as('bob'), 'users/bob'), { uid: 'bob', name: 'Bob', role: 'member' })));
await t('signup as admin blocked', assertFails(setDoc(doc(as('eve'), 'users/eve'), { uid: 'eve', name: 'Eve', role: 'admin' })));
await t('signup as owner blocked', assertFails(setDoc(doc(as('eve'), 'users/eve'), { uid: 'eve', name: 'Eve', role: 'owner' })));
await t('signup with gymId blocked', assertFails(setDoc(doc(as('eve'), 'users/eve'), { uid: 'eve', name: 'Eve', role: 'member', gymId: 'teamflo' })));

// Self edits
await t('member edits their name', assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), { name: 'Alice B' })));
await t('member full set() with same role is okay', assertSucceeds(setDoc(doc(as('alice'), 'users/alice'), { uid: 'alice', name: 'Alice C', role: 'member' })));
await t('member self-promotes are blocked', assertFails(updateDoc(doc(as('alice'), 'users/alice'), { role: 'owner' })));
await t('member sets their own gymId is blocked', assertFails(updateDoc(doc(as('alice'), 'users/alice'), { gymId: 'other' })));
await t('legacy (no role) edits their own name', assertSucceeds(updateDoc(doc(as('legacy'), 'users/legacy'), { name: 'Old 2' })));
await t('legacy adds role blocked', assertFails(updateDoc(doc(as('legacy'), 'users/legacy'), { role: 'member' })));
await t('manager changes role via app blocked', assertFails(updateDoc(doc(as('mgr'), 'users/alice'), { role: 'instructor' })));

// Admin edits
await t('manager edits member profile', assertSucceeds(updateDoc(doc(as('mgr'), 'users/alice'), { goals: 'x' })));
await t('old admin edits member profile', assertSucceeds(updateDoc(doc(as('oldadmin'), 'users/alice'), { goals: 'y' })));
await t('member edits other member blocked', assertFails(updateDoc(doc(as('alice'), 'users/legacy'), { name: 'hax' })));
await t('instructor edits other member is blocked', assertFails(updateDoc(doc(as('instr'), 'users/alice'), { name: 'hax' })));

// Gyms
await t('signed-in reads gym', assertSucceeds(getDoc(doc(as('alice'), 'gyms/teamflo'))));
await t('anon reads gym blocked', assertFails(getDoc(doc(anon, 'gyms/teamflo'))));
await t('manager writes gym is blocked', assertFails(updateDoc(doc(as('mgr'), 'gyms/teamflo'), { plan: 'branded' })));

// Attendance and classes
await t('front desk confirms attendance', assertSucceeds(updateDoc(doc(as('desk'), 'classHistory/c1_2026-10-16_alice'), { status: 'attended' })));
await t('members confirming attendance is blocked', assertFails(updateDoc(doc(as('alice'), 'classHistory/c1_2026-10-16_alice'), { status: 'attended' })));
await t('manager creates a class', assertSucceeds(setDoc(doc(as('mgr'), 'classes/c2'), { className: 'NoGi' })));
await t('front desk creating a class is blocked', assertFails(setDoc(doc(as('desk'), 'classes/c3'), { className: 'NoGi' })));
await t('old admin deletes a class', assertSucceeds(deleteDoc(doc(as('oldadmin'), 'classes/c2'))));

// =====================================================================
// Step 4: each gym only sees its own data
// =====================================================================

// Gym settings
await t('gym: member reads own gym settings', assertSucceeds(getDoc(doc(as('ozzy'), 'gyms/othergym'))));
await t('gym: member reads another gym settings blocked', assertFails(getDoc(doc(as('ozzy'), 'gyms/teamflo'))));

// Posts
await t('gym: Team Flo member reads Team Flo posts', assertSucceeds(getDoc(doc(as('alice'), 'posts/p1'))));
await t('gym: other gym reads Team Flo posts blocked', assertFails(getDoc(doc(as('ozzy'), 'posts/p1'))));
await t('gym: member reads own gym posts', assertSucceeds(getDoc(doc(as('ozzy'), 'gyms/othergym/posts/op1'))));
await t('gym: member posts in own gym', assertSucceeds(setDoc(doc(as('ozzy'), 'gyms/othergym/posts/op2'), { userId: 'ozzy', content: 'hi' })));
await t('gym: Team Flo member reads other gym posts blocked', assertFails(getDoc(doc(as('alice'), 'gyms/othergym/posts/op1'))));
await t('gym: Team Flo member posts in other gym blocked', assertFails(setDoc(doc(as('alice'), 'gyms/othergym/posts/op3'), { userId: 'alice', content: 'hi' })));
await t('gym: other gym manager deletes Team Flo post blocked', assertFails(deleteDoc(doc(as('omgr'), 'posts/p1'))));
await t('gym: author deletes own post', assertSucceeds(deleteDoc(doc(as('ozzy'), 'gyms/othergym/posts/op2'))));

// Classes and attendance
await t('gym: manager creates class in own gym', assertSucceeds(setDoc(doc(as('omgr'), 'gyms/othergym/classes/oc2'), { className: 'Gi' })));
await t('gym: other gym manager creates Team Flo class blocked', assertFails(setDoc(doc(as('omgr'), 'classes/c9'), { className: 'Gi' })));
await t('gym: Team Flo manager creates other gym class blocked', assertFails(setDoc(doc(as('mgr'), 'gyms/othergym/classes/oc9'), { className: 'Gi' })));
await t('gym: member signs up for own gym class', assertSucceeds(setDoc(doc(as('ozzy'), 'gyms/othergym/classHistory/oc1_2026-10-26_ozzy'), { userId: 'ozzy', classId: 'oc1', sessionDate: '2026-10-26', status: 'signedUp', walkIn: false })));
await t('gym: other gym opens Team Flo attendance blocked', assertFails(getDoc(doc(as('omgr'), 'classHistory/c1_2026-10-16_alice'))));

// Instagram card (step 6)
await t('gym: member reads own gym Instagram card', assertSucceeds(getDoc(doc(as('ozzy'), 'gyms/othergym/instagram/latestPost'))));
await t('gym: Team Flo member reads other gym Instagram card blocked', assertFails(getDoc(doc(as('alice'), 'gyms/othergym/instagram/latestPost'))));
await t('gym: manager updates own gym Instagram card', assertSucceeds(setDoc(doc(as('omgr'), 'gyms/othergym/instagram/latestPost'), { caption: 'hi' })));
await t('gym: member updates Instagram card blocked', assertFails(setDoc(doc(as('ozzy'), 'gyms/othergym/instagram/latestPost'), { caption: 'hax' })));

// Profiles and member lists
await t('gym: member opens gym-mate profile', assertSucceeds(getDoc(doc(as('ozzy'), 'users/omgr'))));
await t('gym: opening a deleted profile returns not found', assertSucceeds(getDoc(doc(as('alice'), 'users/ghost'))));
await t('gym: member opens other gym profile blocked', assertFails(getDoc(doc(as('ozzy'), 'users/alice'))));
await t('gym: other gym lists all users blocked', assertFails(getDocs(collection(as('ozzy'), 'users'))));
await t('gym: other gym lists own members', assertSucceeds(getDocs(query(collection(as('ozzy'), 'users'), where('gymId', '==', 'othergym')))));
await t('gym: Team Flo lists users (temporary until step 7)', assertSucceeds(getDocs(collection(as('alice'), 'users'))));
await t('gym: other gym manager edits Team Flo member blocked', assertFails(updateDoc(doc(as('omgr'), 'users/alice'), { goals: 'hax' })));

// Journals
await t('gym: other gym reads Team Flo journal blocked', assertFails(getDoc(doc(as('ozzy'), 'users/alice/journal/j1'))));
await t('gym: other gym technique list with own gymId', assertSucceeds(getDocs(query(collectionGroup(as('ozzy'), 'journal'), where('gymId', '==', 'othergym')))));
await t('gym: other gym technique list without filter blocked', assertFails(getDocs(collectionGroup(as('ozzy'), 'journal'))));

// =====================================================================
// Storage (unchanged)
// =====================================================================
const st = (uid, claims) => env.authenticatedContext(uid, claims).storage();
await env.withSecurityRulesDisabled(async c => {
    await uploadString(ref(c.storage(), 'posts/alice/p.txt'), 'x');
    await uploadString(ref(c.storage(), 'posts/alice/q.txt'), 'x');
});
await t('storage: owner claim deletes a members post image', assertSucceeds(deleteObject(ref(st('own', { role: 'owner' }), 'posts/alice/p.txt'))));
await t('storage: member deletes someone elses image is blocked', assertFails(deleteObject(ref(st('bob', { role: 'member' }), 'posts/alice/q.txt'))));
await t('storage: member uploads for instagram is blocked', assertFails(uploadString(ref(st('bob', { role: 'member' }), 'instagram/a.txt'), 'x')));
await t('storage: manager uploads for instagram', assertSucceeds(uploadString(ref(st('mgr', { role: 'manager' }), 'instagram/a.txt'), 'x')));
await t('storage: member uploads their own profile', assertSucceeds(uploadString(ref(st('bob'), 'profiles/bob/a.txt'), 'x')));

console.log(`\n${pass} passed, ${fail} failed`);
await env.cleanup();
process.exit(fail ? 1 : 0);