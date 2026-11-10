import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";

/**
 * INVITES: the only way into a gym.
 *
 * Staff create invites/{email} from the Staff Portal. An account gets a
 * gymId only when its sign-in email matches a pending invite. Two triggers
 * cover both orders:
 *
 *   claimInviteOnSignup             invited first, then signs up
 *   applyInviteToExistingAccount    signs up first, then gets invited
 *
 * Both use claimInvite(), which runs in a transaction so an invite can
 * only ever be used once.
 */

/** Same normalizing the app uses: trimmed and lowercase. */
export function normalizeEmail(email: string): string {
    return email.trim().toLowerCase();
}

/**
 * Gives the user the invite's gym and marks the invite used.
 * Returns true if the user joined a gym.
 *
 * Does nothing if: there's no pending invite for this email, the user
 * document doesn't exist yet, or the user already belongs to a gym.
 */
export async function claimInvite(uid: string, email: string): Promise<boolean> {
    const db = admin.firestore();
    const inviteRef = db.doc(`invites/${normalizeEmail(email)}`);
    const userRef = db.doc(`users/${uid}`);

    return db.runTransaction(async (tx) => {
        const [invite, user] = await Promise.all([tx.get(inviteRef), tx.get(userRef)]);

        if (!invite.exists || invite.get("status") !== "pending") return false;
        if (!user.exists) return false;
        if (typeof user.get("gymId") === "string") return false; // already in a gym

        const gymId: string = invite.get("gymId");

        tx.update(userRef, { gymId });
        tx.update(inviteRef, {
            status: "used",
            usedBy: uid,
            usedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info(`User ${uid} joined gym ${gymId} with invite ${inviteRef.id}`);
        return true;
    });
}

/**
 * Invited first, then signs up.
 *
 * Runs when the app creates users/{uid} at signup. The email comes from
 * Firebase Auth, NOT from the user document, because the app writes the
 * user document and could put any email there.
 */
export const claimInviteOnSignup = onDocumentCreated("users/{uid}", async (event) => {
    const uid = event.params.uid;

    try {
        const authUser = await admin.auth().getUser(uid);
        if (!authUser.email) {
            logger.info(`User ${uid} has no email, no invite to check`);
            return;
        }

        const joined = await claimInvite(uid, authUser.email);
        if (!joined) {
            logger.info(`User ${uid} signed up without a pending invite`);
        }
    } catch (err) {
        logger.error(`Could not check invite for ${uid}`, err);
    }
});

/**
 * Signs up first, then gets invited.
 *
 * Runs when an invite is created or re-sent. If an account with that
 * email already exists and has no gym, it joins right away. The app is
 * listening to the user document, so their "Waiting for an invite"
 * screen opens into the app by itself.
 */
export const applyInviteToExistingAccount = onDocumentWritten("invites/{email}", async (event) => {
    const after = event.data?.after.data();
    const before = event.data?.before.data();

    // Only when an invite becomes pending (new, or re-sent after a revoke).
    // This function's own "used" update also triggers it; that stops here.
    if (!after || after.status !== "pending") return;
    if (before && before.status === "pending") return;

    const email = normalizeEmail(event.params.email);

    try {
        const authUser = await admin.auth().getUserByEmail(email);
        await claimInvite(authUser.uid, email);
    } catch (err: unknown) {
        const code = (err as { code?: string })?.code;
        if (code === "auth/user-not-found") {
            // Normal: they haven't signed up yet. claimInviteOnSignup
            // handles it when they do.
            return;
        }
        logger.error(`Could not apply invite ${email}`, err);
    }
});