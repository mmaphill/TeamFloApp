import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

/**
 * ACCOUNT DELETION: deletes the caller's account and everything they
 * created. Called from the app:
 *
 *   FirebaseFunctions.instance.httpsCallable('deleteMyAccount').call();
 *
 * Why this runs on the server (it used to run in the app):
 *  - The app could not find the user's comments on other people's posts,
 *    so they were left behind.
 *  - The app deleted the data first and the sign-in last. If the sign-in
 *    delete failed ("requires recent login"), the person was left with a
 *    login but no data, stuck on a loading screen.
 *  - Deleting a post in the app left its comments behind.
 *
 * What is deleted, in this order:
 *  1. The user's posts, with all comments on them
 *  2. The user's comments on other people's posts (and the post's count)
 *  3. The user's likes on posts
 *  4. The user's invite (it holds their email address)
 *  5. The user's files in Storage (profile, post and journal media)
 *  6. The user document with its journal and block list
 *  7. The sign-in account
 *
 * Safe to run twice: if it stops part-way, calling it again finishes.
 *
 * NOT deleted: class attendance records (the gym's own records) and
 * reports the user sent to staff.
 */
export const deleteMyAccount = onCall({ timeoutSeconds: 300 }, async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new HttpsError("unauthenticated", "Please sign in.");
    }

    const db = admin.firestore();
    const userRef = db.doc(`users/${uid}`);
    const userSnap = await userRef.get();

    // Every place this user's posts and comments can be: their gym, a gym
    // they were removed from, and the old shared collection (kept as a
    // backup since the step 7 migration; skipped once it's deleted).
    const postCollections: FirebaseFirestore.CollectionReference[] = [];
    const gymIds = new Set<string>();
    for (const field of ["gymId", "removedFromGymId"]) {
        const value = userSnap.get(field);
        if (typeof value === "string" && value.length > 0) gymIds.add(value);
    }
    for (const gymId of gymIds) {
        postCollections.push(db.collection(`gyms/${gymId}/posts`));
    }
    postCollections.push(db.collection("posts"));

    const totals = { posts: 0, comments: 0, likes: 0 };

    try {
        for (const posts of postCollections) {
            const result = await cleanPosts(db, posts, uid);
            totals.posts += result.posts;
            totals.comments += result.comments;
            totals.likes += result.likes;
        }

        await deleteInvite(db, uid);
        await deleteStorageFiles(uid);

        // The user document and everything under it (journal, block list)
        await db.recursiveDelete(userRef);
    } catch (err) {
        logger.error(`Account deletion for ${uid} stopped part-way`, err);
        throw new HttpsError("internal", "Could not delete your account. Please try again.");
    }

    // Last: the sign-in account. After this the person is signed out.
    try {
        await admin.auth().deleteUser(uid);
    } catch (err) {
        logger.error(`Data for ${uid} was deleted but the sign-in account was not`, err);
        throw new HttpsError("internal", "Could not finish deleting your account. Please try again.");
    }

    logger.info(
        `Deleted account ${uid}: ${totals.posts} post(s), ${totals.comments} comment(s), ${totals.likes} like(s) removed`
    );
    return { ok: true };
});

/** Deletes the user's posts, comments and post likes in one posts collection. */
async function cleanPosts(
    db: FirebaseFirestore.Firestore,
    posts: FirebaseFirestore.CollectionReference,
    uid: string
): Promise<{ posts: number; comments: number; likes: number }> {
    // 1. The user's own posts, with every comment on them
    const ownPosts = await posts.where("userId", "==", uid).get();
    for (const post of ownPosts.docs) {
        await db.recursiveDelete(post.ref);
    }

    // 2. The user's comments on other posts.
    // listDocuments() also returns posts that were deleted but still have
    // comments under them, so old comments are found too. Each post's
    // comments are searched on their own, which needs no Firestore index.
    let comments = 0;
    const postRefs = await posts.listDocuments();
    const CHUNK = 25;
    for (let i = 0; i < postRefs.length; i += CHUNK) {
        const counts = await Promise.all(
            postRefs.slice(i, i + CHUNK).map((postRef) => deleteCommentsBy(db, postRef, uid))
        );
        comments += counts.reduce((sum, n) => sum + n, 0);
    }

    // 3. The user's likes on posts
    const liked = await posts.where("likedBy", "array-contains", uid).get();
    for (const post of liked.docs) {
        await post.ref.update({ likedBy: admin.firestore.FieldValue.arrayRemove(uid) });
    }

    return { posts: ownPosts.size, comments, likes: liked.size };
}

/** Deletes one user's comments on one post and lowers the post's count. */
async function deleteCommentsBy(
    db: FirebaseFirestore.Firestore,
    postRef: FirebaseFirestore.DocumentReference,
    uid: string
): Promise<number> {
    const mine = await postRef.collection("comments").where("userId", "==", uid).get();
    if (mine.empty) return 0;

    const batch = db.batch();
    for (const comment of mine.docs) batch.delete(comment.ref);
    await batch.commit();

    try {
        await postRef.update({
            commentCount: admin.firestore.FieldValue.increment(-mine.size),
        });
    } catch {
        // The post itself was deleted earlier; there is no count to update.
    }
    return mine.size;
}

/** Deletes the invite this user joined with. It holds their email address. */
async function deleteInvite(db: FirebaseFirestore.Firestore, uid: string): Promise<void> {
    const invites = await db.collection("invites").where("usedBy", "==", uid).get();
    for (const invite of invites.docs) {
        await invite.ref.delete();
    }
}

/** Deletes the user's uploaded files. A missing folder is not an error. */
async function deleteStorageFiles(uid: string): Promise<void> {
    const bucket = admin.storage().bucket();
    for (const folder of ["profiles", "posts", "journals"]) {
        try {
            await bucket.deleteFiles({ prefix: `${folder}/${uid}/` });
        } catch (err) {
            logger.warn(`Could not delete ${folder}/${uid}/ from Storage`, err);
        }
    }
}