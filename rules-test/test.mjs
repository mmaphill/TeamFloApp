import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import {
    doc, setDoc, updateDoc, getDoc, deleteDoc,
    collection, collectionGroup, query, where, getDocs,
    serverTimestamp,
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

// Fake data, written with the rules turned off.
// Matches the real database AFTER the step 7 migration:
// every Team Flo account has gymId 'teamflo' and Team Flo is scoped.
await env.withSecurityRulesDisabled(async c => {
    const db = c.firestore();

    // ----- Team Flo (scoped, data under gyms/teamflo/) -----
    await setDoc(doc(db, 'gyms/teamflo'), { name: 'Team Flo', plan: 'academy', dataScoped: true });
    await setDoc(doc(db, 'users/alice'), { uid: 'alice', name: 'Alice', role: 'member', gymId: 'teamflo' });
    await setDoc(doc(db, 'users/legacy'), { uid: 'legacy', name: 'Old', gymId: 'teamflo' }); // no role
    await setDoc(doc(db, 'users/oldadmin'), { uid: 'oldadmin', name: 'Boss', role: 'admin', gymId: 'teamflo' });
    await setDoc(doc(db, 'users/mgr'), { uid: 'mgr', name: 'Manager', role: 'manager', gymId: 'teamflo' });
    await setDoc(doc(db, 'users/desk'), { uid: 'desk', name: 'Desk', role: 'front_desk', gymId: 'teamflo' });
    await setDoc(doc(db, 'users/instr'), { uid: 'instr', name: 'Instructor', role: 'instructor', gymId: 'teamflo' });
    await setDoc(doc(db, 'gyms/teamflo/posts/p1'), { userId: 'alice', content: 'Team Flo post' });
    await setDoc(doc(db, 'gyms/teamflo/classes/c1'), { className: 'Gi' });
    await setDoc(doc(db, 'gyms/teamflo/classHistory/c1_2026-10-16_alice'), { userId: 'alice', status: 'signedUp' });
    await setDoc(doc(db, 'users/alice/journal/j1'), { userId: 'alice', gymId: 'teamflo', notes: 'private-ish' });

    // ----- Old shared collections (read-only backup after step 7) -----
    await setDoc(doc(db, 'posts/p1'), { userId: 'alice', content: 'Team Flo post (backup)' });
    await setDoc(doc(db, 'classes/c1'), { className: 'Gi (backup)' });
    await setDoc(doc(db, 'classHistory/c1_2026-10-16_alice'), { userId: 'alice', status: 'signedUp' });

    // ----- A second gym -----
    await setDoc(doc(db, 'gyms/othergym'), { name: 'Other Gym', plan: 'academy', dataScoped: true });
    await setDoc(doc(db, 'users/ozzy'), { uid: 'ozzy', name: 'Ozzy', role: 'member', gymId: 'othergym' });
    await setDoc(doc(db, 'users/omgr'), { uid: 'omgr', name: 'Other Manager', role: 'manager', gymId: 'othergym' });
    await setDoc(doc(db, 'gyms/othergym/posts/op1'), { userId: 'omgr', content: 'Other gym post' });
    await setDoc(doc(db, 'gyms/othergym/classes/oc1'), { className: 'No Gi' });
    await setDoc(doc(db, 'users/ozzy/journal/oj1'), { userId: 'ozzy', gymId: 'othergym', notes: 'x' });

    // ----- Accounts with no gym (signed up without an invite) -----
    await setDoc(doc(db, 'users/newbie'), { uid: 'newbie', name: 'Newbie', role: 'member' });
    await setDoc(doc(db, 'users/newbie2'), { uid: 'newbie2', name: 'Newbie Two', role: 'member' });

    // ----- Invites -----
    await setDoc(doc(db, 'invites/pending@x.com'), {
        email: 'pending@x.com', gymId: 'teamflo', role: 'member', status: 'pending', invitedBy: 'desk',
    });
    await setDoc(doc(db, 'invites/revoked@x.com'), {
        email: 'revoked@x.com', gymId: 'teamflo', role: 'member', status: 'revoked', invitedBy: 'desk',
    });
    await setDoc(doc(db, 'invites/used@x.com'), {
        email: 'used@x.com', gymId: 'teamflo', role: 'member', status: 'used', invitedBy: 'desk', usedBy: 'alice',
    });
    await setDoc(doc(db, 'invites/other@x.com'), {
        email: 'other@x.com', gymId: 'othergym', role: 'member', status: 'pending', invitedBy: 'omgr',
    });
});

const as = uid => env.authenticatedContext(uid).firestore();
const anon = env.unauthenticatedContext().firestore();

// A valid new invite from `uid` for `email` in `gymId`
const newInvite = (uid, email, gymId, extra = {}) => ({
    email, gymId, role: 'member', status: 'pending',
    invitedBy: uid, invitedByName: 'Staff', createdAt: serverTimestamp(), ...extra,
});

// =====================================================================
// Steps 1-2: accounts and roles
// =====================================================================

// Sign-ups (no gym yet, so no gymId)
await t('new member signup ok', assertSucceeds(setDoc(doc(as('bob'), 'users/bob'), { uid: 'bob', name: 'Bob', role: 'member' })));
await t('signup as admin blocked', assertFails(setDoc(doc(as('eve'), 'users/eve'), { uid: 'eve', name: 'Eve', role: 'admin' })));
await t('signup as owner blocked', assertFails(setDoc(doc(as('eve'), 'users/eve'), { uid: 'eve', name: 'Eve', role: 'owner' })));
await t('signup with gymId blocked', assertFails(setDoc(doc(as('eve'), 'users/eve'), { uid: 'eve', name: 'Eve', role: 'member', gymId: 'teamflo' })));

// Self edits
await t('member edits their name', assertSucceeds(updateDoc(doc(as('alice'), 'users/alice'), { name: 'Alice B' })));
await t('member full set() keeping role and gym is ok', assertSucceeds(setDoc(doc(as('alice'), 'users/alice'), { uid: 'alice', name: 'Alice C', role: 'member', gymId: 'teamflo' })));
await t('member full set() that drops gymId is blocked', assertFails(setDoc(doc(as('alice'), 'users/alice'), { uid: 'alice', name: 'Alice D', role: 'member' })));
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
await t('member reads own gym', assertSucceeds(getDoc(doc(as('alice'), 'gyms/teamflo'))));
await t('anon reads gym blocked', assertFails(getDoc(doc(anon, 'gyms/teamflo'))));
await t('manager writes gym is blocked', assertFails(updateDoc(doc(as('mgr'), 'gyms/teamflo'), { plan: 'branded' })));

// Attendance and classes (Team Flo, now under gyms/teamflo)
await t('front desk confirms attendance', assertSucceeds(updateDoc(doc(as('desk'), 'gyms/teamflo/classHistory/c1_2026-10-16_alice'), { status: 'attended' })));
await t('members confirming attendance is blocked', assertFails(updateDoc(doc(as('alice'), 'gyms/teamflo/classHistory/c1_2026-10-16_alice'), { status: 'attended' })));
await t('manager creates a class', assertSucceeds(setDoc(doc(as('mgr'), 'gyms/teamflo/classes/c2'), { className: 'NoGi' })));
await t('front desk creating a class is blocked', assertFails(setDoc(doc(as('desk'), 'gyms/teamflo/classes/c3'), { className: 'NoGi' })));
await t('old admin deletes a class', assertSucceeds(deleteDoc(doc(as('oldadmin'), 'gyms/teamflo/classes/c2'))));

// =====================================================================
// Step 4: each gym only sees its own data
// =====================================================================

// Gym settings
await t('gym: member reads own gym settings', assertSucceeds(getDoc(doc(as('ozzy'), 'gyms/othergym'))));
await t('gym: member reads another gym settings blocked', assertFails(getDoc(doc(as('ozzy'), 'gyms/teamflo'))));

// Posts
await t('gym: Team Flo member reads Team Flo posts', assertSucceeds(getDoc(doc(as('alice'), 'gyms/teamflo/posts/p1'))));
await t('gym: other gym reads Team Flo posts blocked', assertFails(getDoc(doc(as('ozzy'), 'gyms/teamflo/posts/p1'))));
await t('gym: member reads own gym posts', assertSucceeds(getDoc(doc(as('ozzy'), 'gyms/othergym/posts/op1'))));
await t('gym: member posts in own gym', assertSucceeds(setDoc(doc(as('ozzy'), 'gyms/othergym/posts/op2'), { userId: 'ozzy', content: 'hi' })));
await t('gym: Team Flo member reads other gym posts blocked', assertFails(getDoc(doc(as('alice'), 'gyms/othergym/posts/op1'))));
await t('gym: Team Flo member posts in other gym blocked', assertFails(setDoc(doc(as('alice'), 'gyms/othergym/posts/op3'), { userId: 'alice', content: 'hi' })));
await t('gym: other gym manager deletes Team Flo post blocked', assertFails(deleteDoc(doc(as('omgr'), 'gyms/teamflo/posts/p1'))));
await t('gym: author deletes own post', assertSucceeds(deleteDoc(doc(as('ozzy'), 'gyms/othergym/posts/op2'))));

// Classes and attendance
await t('gym: manager creates class in own gym', assertSucceeds(setDoc(doc(as('omgr'), 'gyms/othergym/classes/oc2'), { className: 'Gi' })));
await t('gym: other gym manager creates Team Flo class blocked', assertFails(setDoc(doc(as('omgr'), 'gyms/teamflo/classes/c9'), { className: 'Gi' })));
await t('gym: Team Flo manager creates other gym class blocked', assertFails(setDoc(doc(as('mgr'), 'gyms/othergym/classes/oc9'), { className: 'Gi' })));
await t('gym: member signs up for own gym class', assertSucceeds(setDoc(doc(as('ozzy'), 'gyms/othergym/classHistory/oc1_2026-10-26_ozzy'), { userId: 'ozzy', classId: 'oc1', sessionDate: '2026-10-26', status: 'signedUp', walkIn: false })));
await t('gym: other gym opens Team Flo attendance blocked', assertFails(getDoc(doc(as('omgr'), 'gyms/teamflo/classHistory/c1_2026-10-16_alice'))));

// Instagram card (step 6)
await t('gym: member reads own gym Instagram card', assertSucceeds(getDoc(doc(as('ozzy'), 'gyms/othergym/instagram/latestPost'))));
await t('gym: Team Flo member reads other gym Instagram card blocked', assertFails(getDoc(doc(as('alice'), 'gyms/othergym/instagram/latestPost'))));
await t('gym: manager updates own gym Instagram card', assertSucceeds(setDoc(doc(as('omgr'), 'gyms/othergym/instagram/latestPost'), { caption: 'hi' })));
await t('gym: member updates Instagram card blocked', assertFails(setDoc(doc(as('ozzy'), 'gyms/othergym/instagram/latestPost'), { caption: 'hax' })));

// Profiles
await t('gym: member opens gym-mate profile', assertSucceeds(getDoc(doc(as('ozzy'), 'users/omgr'))));
await t('gym: opening a deleted profile returns not found', assertSucceeds(getDoc(doc(as('alice'), 'users/ghost'))));
await t('gym: member opens other gym profile blocked', assertFails(getDoc(doc(as('ozzy'), 'users/alice'))));
await t('gym: other gym manager edits Team Flo member blocked', assertFails(updateDoc(doc(as('omgr'), 'users/alice'), { goals: 'hax' })));

// Journals
await t('gym: other gym reads Team Flo journal blocked', assertFails(getDoc(doc(as('ozzy'), 'users/alice/journal/j1'))));
await t('gym: other gym technique list with own gymId', assertSucceeds(getDocs(query(collectionGroup(as('ozzy'), 'journal'), where('gymId', '==', 'othergym')))));
await t('gym: other gym technique list without filter blocked', assertFails(getDocs(collectionGroup(as('ozzy'), 'journal'))));

// =====================================================================
// Step 7: temporary Team Flo exceptions are gone; old collections read-only
// =====================================================================

await t('step 7: Team Flo lists own members with gymId filter', assertSucceeds(getDocs(query(collection(as('alice'), 'users'), where('gymId', '==', 'teamflo')))));
await t('step 7: Team Flo lists ALL users blocked', assertFails(getDocs(collection(as('alice'), 'users'))));
await t('step 7: other gym lists all users blocked', assertFails(getDocs(collection(as('ozzy'), 'users'))));
await t('step 7: Team Flo technique list with gymId filter', assertSucceeds(getDocs(query(collectionGroup(as('alice'), 'journal'), where('gymId', '==', 'teamflo')))));
await t('step 7: Team Flo technique list without filter blocked', assertFails(getDocs(collectionGroup(as('alice'), 'journal'))));

await t('step 7: Team Flo member reads old backup post', assertSucceeds(getDoc(doc(as('alice'), 'posts/p1'))));
await t('step 7: other gym reads old backup post blocked', assertFails(getDoc(doc(as('ozzy'), 'posts/p1'))));
await t('step 7: writing a post to old collection blocked', assertFails(setDoc(doc(as('alice'), 'posts/p9'), { userId: 'alice', content: 'lost' })));
await t('step 7: manager writing old classes blocked', assertFails(setDoc(doc(as('mgr'), 'classes/c9'), { className: 'lost' })));
await t('step 7: staff updating old attendance blocked', assertFails(updateDoc(doc(as('desk'), 'classHistory/c1_2026-10-16_alice'), { status: 'attended' })));
await t('step 7: manager writing old Instagram blocked', assertFails(setDoc(doc(as('mgr'), 'instagram/latestPost'), { caption: 'x' })));

// =====================================================================
// Invites: accounts with no gym see nothing
// =====================================================================

await t('no gym: reads own user doc', assertSucceeds(getDoc(doc(as('newbie'), 'users/newbie'))));
await t('no gym: edits own name', assertSucceeds(updateDoc(doc(as('newbie'), 'users/newbie'), { name: 'New Name' })));
await t('no gym: gives self a gym blocked', assertFails(updateDoc(doc(as('newbie'), 'users/newbie'), { gymId: 'teamflo' })));
await t('no gym: reads Team Flo gym settings blocked', assertFails(getDoc(doc(as('newbie'), 'gyms/teamflo'))));
await t('no gym: reads Team Flo posts blocked', assertFails(getDoc(doc(as('newbie'), 'gyms/teamflo/posts/p1'))));
await t('no gym: posts in Team Flo blocked', assertFails(setDoc(doc(as('newbie'), 'gyms/teamflo/posts/p8'), { userId: 'newbie', content: 'hi' })));
await t('no gym: reads Team Flo classes blocked', assertFails(getDoc(doc(as('newbie'), 'gyms/teamflo/classes/c1'))));
await t('no gym: reads old backup posts blocked', assertFails(getDoc(doc(as('newbie'), 'posts/p1'))));
await t('no gym: opens a member profile blocked', assertFails(getDoc(doc(as('newbie'), 'users/alice'))));
await t('no gym: opens another no-gym profile blocked', assertFails(getDoc(doc(as('newbie'), 'users/newbie2'))));
await t('no gym: lists Team Flo members blocked', assertFails(getDocs(query(collection(as('newbie'), 'users'), where('gymId', '==', 'teamflo')))));
await t('no gym: reads a member journal blocked', assertFails(getDoc(doc(as('newbie'), 'users/alice/journal/j1'))));
await t('no gym: technique list blocked', assertFails(getDocs(query(collectionGroup(as('newbie'), 'journal'), where('gymId', '==', 'teamflo')))));
await t('no gym: reads an invite blocked', assertFails(getDoc(doc(as('newbie'), 'invites/pending@x.com'))));
await t('no gym: creates an invite blocked', assertFails(setDoc(doc(as('newbie'), 'invites/friend@x.com'), newInvite('newbie', 'friend@x.com', 'teamflo'))));
await t('no gym: can still delete own account doc', assertSucceeds(deleteDoc(doc(as('newbie2'), 'users/newbie2'))));

// =====================================================================
// Invites: who can send, see and change them
// =====================================================================

// Create
await t('invite: front desk invites to own gym', assertSucceeds(setDoc(doc(as('desk'), 'invites/a@x.com'), newInvite('desk', 'a@x.com', 'teamflo'))));
await t('invite: instructor invites to own gym', assertSucceeds(setDoc(doc(as('instr'), 'invites/b@x.com'), newInvite('instr', 'b@x.com', 'teamflo'))));
await t('invite: manager invites to own gym', assertSucceeds(setDoc(doc(as('mgr'), 'invites/c@x.com'), newInvite('mgr', 'c@x.com', 'teamflo'))));
await t('invite: old admin (owner) invites to own gym', assertSucceeds(setDoc(doc(as('oldadmin'), 'invites/d@x.com'), newInvite('oldadmin', 'd@x.com', 'teamflo'))));
await t('invite: member invites blocked', assertFails(setDoc(doc(as('alice'), 'invites/e@x.com'), newInvite('alice', 'e@x.com', 'teamflo'))));
await t('invite: staff invites to another gym blocked', assertFails(setDoc(doc(as('desk'), 'invites/f@x.com'), newInvite('desk', 'f@x.com', 'othergym'))));
await t('invite: invite as instructor role blocked', assertFails(setDoc(doc(as('mgr'), 'invites/g@x.com'), newInvite('mgr', 'g@x.com', 'teamflo', { role: 'instructor' }))));
await t('invite: create already used blocked', assertFails(setDoc(doc(as('mgr'), 'invites/h@x.com'), newInvite('mgr', 'h@x.com', 'teamflo', { status: 'used' }))));
await t('invite: create in someone elses name blocked', assertFails(setDoc(doc(as('desk'), 'invites/i@x.com'), newInvite('mgr', 'i@x.com', 'teamflo'))));
await t('invite: doc ID different from email blocked', assertFails(setDoc(doc(as('desk'), 'invites/j@x.com'), newInvite('desk', 'other@y.com', 'teamflo'))));
await t('invite: extra fields blocked', assertFails(setDoc(doc(as('desk'), 'invites/k@x.com'), newInvite('desk', 'k@x.com', 'teamflo', { usedBy: 'desk' }))));
await t('invite: overwrite other gym invite blocked', assertFails(setDoc(doc(as('desk'), 'invites/other@x.com'), newInvite('desk', 'other@x.com', 'teamflo'))));

// Read
await t('invite: staff opens own gym invite', assertSucceeds(getDoc(doc(as('desk'), 'invites/pending@x.com'))));
await t('invite: staff checks an email with no invite', assertSucceeds(getDoc(doc(as('desk'), 'invites/nobody@x.com'))));
await t('invite: staff opens other gym invite blocked', assertFails(getDoc(doc(as('desk'), 'invites/other@x.com'))));
await t('invite: member opens invite blocked', assertFails(getDoc(doc(as('alice'), 'invites/pending@x.com'))));
await t('invite: staff lists own gym invites', assertSucceeds(getDocs(query(collection(as('instr'), 'invites'), where('gymId', '==', 'teamflo')))));
await t('invite: staff lists all invites blocked', assertFails(getDocs(collection(as('instr'), 'invites'))));
await t('invite: staff lists other gym invites blocked', assertFails(getDocs(query(collection(as('mgr'), 'invites'), where('gymId', '==', 'othergym')))));
await t('invite: member lists invites blocked', assertFails(getDocs(query(collection(as('alice'), 'invites'), where('gymId', '==', 'teamflo')))));

// Revoke and re-send
await t('invite: staff revokes pending invite', assertSucceeds(updateDoc(doc(as('desk'), 'invites/pending@x.com'), { status: 'revoked', revokedBy: 'desk', revokedAt: serverTimestamp() })));
await t('invite: staff re-sends revoked invite', assertSucceeds(updateDoc(doc(as('instr'), 'invites/revoked@x.com'), { status: 'pending', invitedBy: 'instr', invitedByName: 'Instructor', createdAt: serverTimestamp() })));
await t('invite: staff re-sends without new timestamp blocked', assertFails(updateDoc(doc(as('mgr'), 'invites/used@x.com'), { status: 'pending', invitedBy: 'mgr' })));
await t('invite: staff re-sends a used invite (member came back)', assertSucceeds(updateDoc(doc(as('mgr'), 'invites/used@x.com'), { status: 'pending', invitedBy: 'mgr', invitedByName: 'Manager', createdAt: serverTimestamp() })));
await t('invite: staff edits usedBy blocked', assertFails(updateDoc(doc(as('mgr'), 'invites/used@x.com'), { usedBy: 'mgr' })));
await t('invite: staff marks invite used blocked', assertFails(updateDoc(doc(as('mgr'), 'invites/revoked@x.com'), { status: 'used' })));
await t('invite: staff moves invite to their gym blocked', assertFails(updateDoc(doc(as('omgr'), 'invites/used@x.com'), { gymId: 'othergym' })));
await t('invite: other gym revokes Team Flo invite blocked', assertFails(updateDoc(doc(as('omgr'), 'invites/a@x.com'), { status: 'revoked', revokedBy: 'omgr', revokedAt: serverTimestamp() })));
await t('invite: member revokes invite blocked', assertFails(updateDoc(doc(as('alice'), 'invites/a@x.com'), { status: 'revoked', revokedBy: 'alice', revokedAt: serverTimestamp() })));
await t('invite: delete blocked', assertFails(deleteDoc(doc(as('mgr'), 'invites/a@x.com'))));

// =====================================================================
// Outgoing email: no app access at all
// =====================================================================

await env.withSecurityRulesDisabled(async c => {
    await setDoc(doc(c.firestore(), 'mail/m1'), { to: 'pending@x.com', message: { subject: 'Invite' } });
});
await t('mail: staff reads queued email blocked', assertFails(getDoc(doc(as('mgr'), 'mail/m1'))));
await t('mail: staff sends email directly blocked', assertFails(setDoc(doc(as('mgr'), 'mail/m2'), { to: 'a@x.com', message: { subject: 'hi' } })));
await t('mail: member lists email blocked', assertFails(getDocs(collection(as('alice'), 'mail'))));

// =====================================================================
// Removed from gym (gymId cleared by the removeFromGym function)
// =====================================================================

await env.withSecurityRulesDisabled(async c => {
    await setDoc(doc(c.firestore(), 'users/gone'), {
        uid: 'gone', name: 'Gone', role: 'member', removedFromGymId: 'teamflo', removedBy: 'mgr',
    });
});
await t('removed: reads own user doc', assertSucceeds(getDoc(doc(as('gone'), 'users/gone'))));
await t('removed: reads Team Flo posts blocked', assertFails(getDoc(doc(as('gone'), 'gyms/teamflo/posts/p1'))));
await t('removed: lists Team Flo members blocked', assertFails(getDocs(query(collection(as('gone'), 'users'), where('gymId', '==', 'teamflo')))));
await t('removed: rejoins by setting own gymId blocked', assertFails(updateDoc(doc(as('gone'), 'users/gone'), { gymId: 'teamflo' })));
await t('removed: Team Flo member opens their profile blocked', assertFails(getDoc(doc(as('alice'), 'users/gone'))));

// =====================================================================
// Report and block
// =====================================================================

const newReport = (uid, type, targetId, extra = {}) => ({
    type, targetId, postId: 'p1', contentAuthorId: 'alice', contentAuthorName: 'Alice',
    contentText: 'Team Flo post', mediaCount: 0, reportedBy: uid, reportedByName: 'Reporter',
    reason: 'Spam', status: 'open', createdAt: serverTimestamp(), ...extra,
});
const closeReport = (uid, status) => ({ status, resolvedBy: uid, resolvedAt: serverTimestamp() });

await t('report: member reports a post', assertSucceeds(setDoc(doc(as('legacy'), 'gyms/teamflo/reports/post_p1_legacy'), newReport('legacy', 'post', 'p1'))));
await t('report: member reports a comment', assertSucceeds(setDoc(doc(as('legacy'), 'gyms/teamflo/reports/comment_c9_legacy'), newReport('legacy', 'comment', 'c9', { commentId: 'c9' }))));
await t('report: same member reports the same post twice blocked', assertFails(setDoc(doc(as('legacy'), 'gyms/teamflo/reports/post_p1_legacy'), newReport('legacy', 'post', 'p1'))));
await t('report: report in someone elses name blocked', assertFails(setDoc(doc(as('legacy'), 'gyms/teamflo/reports/post_p1_instr'), newReport('instr', 'post', 'p1'))));
await t('report: wrong document ID blocked', assertFails(setDoc(doc(as('instr'), 'gyms/teamflo/reports/anything'), newReport('instr', 'post', 'p1'))));
await t('report: created already closed blocked', assertFails(setDoc(doc(as('instr'), 'gyms/teamflo/reports/post_p1_instr'), newReport('instr', 'post', 'p1', { status: 'dismissed' }))));
await t('report: other gym member reports in Team Flo blocked', assertFails(setDoc(doc(as('ozzy'), 'gyms/teamflo/reports/post_p1_ozzy'), newReport('ozzy', 'post', 'p1'))));
await t('report: no-gym account reports blocked', assertFails(setDoc(doc(as('newbie'), 'gyms/teamflo/reports/post_p1_newbie'), newReport('newbie', 'post', 'p1'))));
await t('report: member reads reports blocked', assertFails(getDoc(doc(as('legacy'), 'gyms/teamflo/reports/post_p1_legacy'))));
await t('report: instructor reads reports blocked', assertFails(getDocs(collection(as('instr'), 'gyms/teamflo/reports'))));
await t('report: manager lists reports', assertSucceeds(getDocs(collection(as('mgr'), 'gyms/teamflo/reports'))));
await t('report: other gym manager lists Team Flo reports blocked', assertFails(getDocs(collection(as('omgr'), 'gyms/teamflo/reports'))));
await t('report: member closes a report blocked', assertFails(updateDoc(doc(as('legacy'), 'gyms/teamflo/reports/post_p1_legacy'), closeReport('legacy', 'dismissed'))));
await t('report: manager edits report text blocked', assertFails(updateDoc(doc(as('mgr'), 'gyms/teamflo/reports/post_p1_legacy'), { reason: 'changed' })));
await t('report: manager dismisses a report', assertSucceeds(updateDoc(doc(as('mgr'), 'gyms/teamflo/reports/post_p1_legacy'), closeReport('mgr', 'dismissed'))));
await t('report: owner marks content removed', assertSucceeds(updateDoc(doc(as('oldadmin'), 'gyms/teamflo/reports/comment_c9_legacy'), closeReport('oldadmin', 'removed'))));
await t('report: delete blocked', assertFails(deleteDoc(doc(as('mgr'), 'gyms/teamflo/reports/post_p1_legacy'))));

const blockDoc = (blockedUid) => ({ blockedUid, name: 'Someone', createdAt: serverTimestamp() });
await t('block: member blocks another member', assertSucceeds(setDoc(doc(as('alice'), 'users/alice/blocked/legacy'), blockDoc('legacy'))));
await t('block: member reads own block list', assertSucceeds(getDocs(collection(as('alice'), 'users/alice/blocked'))));
await t('block: blocking yourself blocked', assertFails(setDoc(doc(as('alice'), 'users/alice/blocked/alice'), blockDoc('alice'))));
await t('block: writing to someone elses block list blocked', assertFails(setDoc(doc(as('legacy'), 'users/alice/blocked/mgr'), blockDoc('mgr'))));
await t('block: gym-mate reads your block list blocked', assertFails(getDocs(collection(as('legacy'), 'users/alice/blocked'))));
await t('block: manager reads your block list blocked', assertFails(getDoc(doc(as('mgr'), 'users/alice/blocked/legacy'))));
await t('block: member unblocks', assertSucceeds(deleteDoc(doc(as('alice'), 'users/alice/blocked/legacy'))));

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