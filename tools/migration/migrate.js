// =============================================================================
// Phase 1 Step 7: move Team Flo's data under gyms/teamflo
//
// Run from this folder (tools/migration):
//
//   node migrate.js              Report only. Counts everything, changes nothing.
//   node migrate.js --run        Copy, tag, switch Team Flo over, then catch up.
//   node migrate.js --catch-up   Copy anything still missing. Safe to repeat.
//
// Needs serviceAccountKey.json in this folder (Firebase console > Project
// settings > Service accounts > Generate new private key). Delete the key
// when you're done. It is a master password to the database.
//
// Nothing is ever deleted. The old shared collections stay as a backup.
// =============================================================================

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");
const readline = require("readline");

const GYM_ID = "teamflo";
const PROJECT_ID = "teamfloapp";

// Shared collections that move under gyms/teamflo/. Subcollections
// (for example posts/{id}/comments) are found and copied automatically.
const COLLECTIONS = ["posts", "classes", "classHistory", "instagram"];

// -----------------------------------------------------------------------------
// Setup
// -----------------------------------------------------------------------------

const KEY_PATH = path.join(__dirname, "serviceAccountKey.json");
if (!fs.existsSync(KEY_PATH)) {
    console.error("serviceAccountKey.json not found in tools/migration.");
    console.error("Download it from Firebase console > Project settings > Service accounts.");
    process.exit(1);
}

const key = require(KEY_PATH);
if (key.project_id !== PROJECT_ID) {
    console.error(`This key is for "${key.project_id}", not "${PROJECT_ID}". Stopping.`);
    process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(key) });
const db = admin.firestore();

const mode = process.argv[2] || "--report";
const gymRef = db.collection("gyms").doc(GYM_ID);

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Counts the documents in a collection and in every subcollection under it.
// Returns e.g. { posts: 120, "posts/comments": 340 }
async function countTree(col, label, totals = {}) {
    const snap = await col.get();
    totals[label] = (totals[label] || 0) + snap.size;
    for (const doc of snap.docs) {
        const subs = await doc.ref.listCollections();
        for (const sub of subs) {
            await countTree(sub, `${label}/${sub.id}`, totals);
        }
    }
    return totals;
}

// Copies every document from src to dst with the same IDs, then does the
// same for each document's subcollections.
//
// onlyMissing = false: overwrite (first copy).
// onlyMissing = true:  skip documents that already exist in dst, so newer
//                      edits made in the new location are never overwritten.
async function copyTree(src, dst, writer, onlyMissing, counter) {
    const snap = await src.get();

    let existing = new Set();
    if (onlyMissing) {
        const dstSnap = await dst.select().get(); // IDs only, no data
        existing = new Set(dstSnap.docs.map((d) => d.id));
    }

    for (const doc of snap.docs) {
        if (!existing.has(doc.id)) {
            writer.set(dst.doc(doc.id), doc.data());
            counter.copied++;
        }
        // Always walk subcollections: a post that was already copied
        // can still have a new comment.
        const subs = await doc.ref.listCollections();
        for (const sub of subs) {
            await copyTree(sub, dst.doc(doc.id).collection(sub.id), writer, onlyMissing, counter);
        }
    }
}

// Team Flo users are the accounts made before multi-gym support (no gymId)
// plus any already tagged 'teamflo'.
async function loadUsers() {
    const snap = await db.collection("users").get();
    const untagged = [];
    const teamflo = [];
    const otherGyms = {};
    for (const doc of snap.docs) {
        const gymId = doc.get("gymId");
        if (gymId === undefined || gymId === null) untagged.push(doc);
        else if (gymId === GYM_ID) teamflo.push(doc);
        else (otherGyms[gymId] = otherGyms[gymId] || []).push(doc);
    }
    return { total: snap.size, untagged, teamflo, otherGyms };
}

// Journal entries for Team Flo users that don't have a gymId yet.
async function untaggedJournals(userDocs) {
    const result = [];
    for (const user of userDocs) {
        const snap = await user.ref.collection("journal").get();
        for (const entry of snap.docs) {
            if (entry.get("gymId") === undefined) result.push(entry.ref);
        }
    }
    return result;
}

function ask(question) {
    const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    return new Promise((resolve) =>
        rl.question(question, (answer) => {
            rl.close();
            resolve(answer.trim());
        })
    );
}

function newWriter() {
    const writer = db.bulkWriter(); // batches and retries automatically
    writer.onWriteError((err) => {
        console.error(`  Write failed: ${err.documentRef.path}: ${err.message}`);
        return err.failedAttempts < 3; // retry up to 3 times
    });
    return writer;
}

// -----------------------------------------------------------------------------
// Report (default)
// -----------------------------------------------------------------------------

async function report() {
    const gym = await gymRef.get();
    console.log(`\n=== gyms/${GYM_ID} ===`);
    if (!gym.exists) {
        console.log("  MISSING. Create it before running the migration.");
    } else {
        console.log(`  name: ${gym.get("name")}   plan: ${gym.get("plan")}`);
        console.log(`  dataScoped: ${gym.get("dataScoped") === true}`);
    }

    console.log("\n=== Documents: old location -> new location ===");
    for (const name of COLLECTIONS) {
        const oldCounts = await countTree(db.collection(name), name);
        const newCounts = await countTree(gymRef.collection(name), name);
        const labels = new Set([...Object.keys(oldCounts), ...Object.keys(newCounts)]);
        for (const label of labels) {
            const o = oldCounts[label] || 0;
            const n = newCounts[label] || 0;
            const flag = o === n ? "" : "   <-- differs";
            console.log(`  ${label.padEnd(28)} ${String(o).padStart(6)} -> ${String(n).padStart(6)}${flag}`);
        }
    }

    const users = await loadUsers();
    console.log("\n=== Users ===");
    console.log(`  Total accounts:            ${users.total}`);
    console.log(`  No gymId (will be tagged): ${users.untagged.length}`);
    console.log(`  Already tagged teamflo:    ${users.teamflo.length}`);
    for (const [gymId, docs] of Object.entries(users.otherGyms)) {
        console.log(`  Other gym "${gymId}" (left alone): ${docs.length}`);
        for (const d of docs) console.log(`      - ${d.get("name") || "(no name)"}  ${d.id}`);
    }

    const journals = await untaggedJournals([...users.untagged, ...users.teamflo]);
    console.log("\n=== Journal entries ===");
    console.log(`  Team Flo entries with no gymId (will be tagged): ${journals.length}`);
    console.log("\nReport only. Nothing was changed.\n");
}

// -----------------------------------------------------------------------------
// Run
// -----------------------------------------------------------------------------

async function run() {
    const gym = await gymRef.get();
    if (!gym.exists) {
        console.error(`gyms/${GYM_ID} doesn't exist. Stopping.`);
        process.exit(1);
    }
    if (gym.get("dataScoped") === true) {
        console.error("Team Flo is already scoped. Use --catch-up instead. Stopping.");
        process.exit(1);
    }

    const answer = await ask(
        `This copies Team Flo's data into gyms/${GYM_ID} and switches every app over.\n` +
        `Type "migrate" to continue: `
    );
    if (answer !== "migrate") {
        console.log("Cancelled. Nothing was changed.");
        return;
    }

    // 1. Copy collections
    console.log("\n1/4 Copying collections...");
    let writer = newWriter();
    const counter = { copied: 0 };
    for (const name of COLLECTIONS) {
        await copyTree(db.collection(name), gymRef.collection(name), writer, false, counter);
    }
    await writer.close();
    console.log(`    Copied ${counter.copied} documents.`);

    // 2. Tag users and journal entries
    console.log("2/4 Tagging users and journal entries...");
    const users = await loadUsers();
    const journals = await untaggedJournals([...users.untagged, ...users.teamflo]);
    writer = newWriter();
    for (const u of users.untagged) writer.update(u.ref, { gymId: GYM_ID });
    for (const j of journals) writer.update(j, { gymId: GYM_ID });
    await writer.close();
    console.log(`    Tagged ${users.untagged.length} users and ${journals.length} journal entries.`);

    // 3. Switch Team Flo to the new location. Apps pick this up live.
    console.log("3/4 Turning on dataScoped for Team Flo...");
    await gymRef.update({
        dataScoped: true,
        migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log("    Done. Apps now read and write under gyms/teamflo.");

    // 4. Anything written to the old location while steps 1-3 ran
    console.log("4/4 Waiting 30 seconds for apps to switch, then catching up...");
    await new Promise((r) => setTimeout(r, 30000));
    await catchUp();

    console.log("\nMigration finished. Run `node migrate.js` to compare counts.\n");
}

// -----------------------------------------------------------------------------
// Catch-up: copy anything that exists in the old location but not the new one
// -----------------------------------------------------------------------------

async function catchUp() {
    const writer = newWriter();
    const counter = { copied: 0 };
    for (const name of COLLECTIONS) {
        await copyTree(db.collection(name), gymRef.collection(name), writer, true, counter);
    }

    // New accounts or journal entries created without a gymId in the meantime
    const users = await loadUsers();
    const journals = await untaggedJournals([...users.untagged, ...users.teamflo]);
    for (const u of users.untagged) writer.update(u.ref, { gymId: GYM_ID });
    for (const j of journals) writer.update(j, { gymId: GYM_ID });

    await writer.close();
    console.log(
        `    Catch-up: copied ${counter.copied} documents, tagged ${users.untagged.length} users ` +
        `and ${journals.length} journal entries.`
    );
}

// -----------------------------------------------------------------------------

(async () => {
    try {
        if (mode === "--report") await report();
        else if (mode === "--run") await run();
        else if (mode === "--catch-up") await catchUp();
        else console.log("Use: node migrate.js [--run | --catch-up]");
    } catch (err) {
        console.error("\nStopped with an error:", err);
        process.exit(1);
    }
})();