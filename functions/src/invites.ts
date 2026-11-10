import * as admin from "firebase-admin";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

/**
 * INVITES: the only way into a gym.
 *
 * Staff create invites/{email} from the Staff Portal. An account gets a
 * gymId only when its sign-in email is VERIFIED and matches a pending
 * invite. Three ways in, all using claimInvite():
 *
 *   claimMyInvite                  app calls it after the user verifies
 *                                  their email (the usual path)
 *   applyInviteToExistingAccount   invite created for someone who already
 *                                  signed up and verified
 *   claimInviteOnSignup            signup with an already-verified email
 *                                  (not possible with email/password today,
 *                                  kept for future sign-in methods)
 *
 * applyInviteToExistingAccount also sends the invite email through the
 * Trigger Email extension (writes to the "mail" collection).
 */

/** Collection the Trigger Email extension watches. Must match its setting. */
const MAIL_COLLECTION = "mail";

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
 * The caller must check that the email is verified first.
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
        const remove = admin.firestore.FieldValue.delete();

        tx.update(userRef, {
            gymId,
            // Clear any earlier "removed from gym" record (re-invited member)
            removedFromGymId: remove,
            removedBy: remove,
            removedAt: remove,
        });
        tx.update(inviteRef, {
            status: "used",
            usedBy: uid,
            usedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        logger.info(`User ${uid} joined gym ${gymId} with invite ${inviteRef.id}`);
        return true;
    });
}

// -----------------------------------------------------------------------------
// The usual path: app calls this after the user verifies their email
// -----------------------------------------------------------------------------

/**
 * Called from the "Waiting for an invite" screen:
 *
 *   FirebaseFunctions.instance.httpsCallable('claimMyInvite').call();
 *
 * The email and its verified flag come from the caller's ID token, which
 * only Firebase Auth can issue. The app must refresh the token after the
 * user clicks the verification link (getIdToken(true)), or the token
 * still says "not verified".
 */
export const claimMyInvite = onCall(async (request) => {
    const uid = request.auth?.uid;
    const token = request.auth?.token;
    if (!uid || !token) {
        throw new HttpsError("unauthenticated", "Please sign in.");
    }
    if (!token.email) {
        throw new HttpsError("failed-precondition", "Your account has no email address.");
    }
    if (token.email_verified !== true) {
        throw new HttpsError("failed-precondition", "Please verify your email first.");
    }

    const joined = await claimInvite(uid, token.email);
    if (!joined) {
        logger.info(`claimMyInvite: no pending invite for ${uid}`);
    }
    return { joined };
});

// -----------------------------------------------------------------------------
// Signup with an already-verified email (future sign-in methods)
// -----------------------------------------------------------------------------

export const claimInviteOnSignup = onDocumentCreated("users/{uid}", async (event) => {
    const uid = event.params.uid;

    try {
        const authUser = await admin.auth().getUser(uid);
        if (!authUser.email) return;

        // Email/password signups aren't verified yet at this point. They
        // join through claimMyInvite after clicking the link instead.
        if (!authUser.emailVerified) {
            logger.info(`User ${uid} signed up, waiting for email verification`);
            return;
        }

        await claimInvite(uid, authUser.email);
    } catch (err) {
        logger.error(`Could not check invite for ${uid}`, err);
    }
});

// -----------------------------------------------------------------------------
// New or re-sent invite: send the email, and let in a waiting account
// -----------------------------------------------------------------------------

export const applyInviteToExistingAccount = onDocumentWritten("invites/{email}", async (event) => {
    const after = event.data?.after.data();
    const before = event.data?.before.data();

    // Only when an invite becomes pending (new, or re-sent after a revoke).
    // This function's own "used" update also triggers it; that stops here.
    if (!after || after.status !== "pending") return;
    if (before && before.status === "pending") return;

    const email = normalizeEmail(event.params.email);

    // 1. Send the invite email (never blocks the rest)
    try {
        await queueInviteEmail(email, after.gymId, after.invitedByName);
    } catch (err) {
        logger.error(`Could not queue invite email for ${email}`, err);
    }

    // 2. Already signed up and verified? Let them in now.
    try {
        const authUser = await admin.auth().getUserByEmail(email);
        if (!authUser.emailVerified) {
            logger.info(`Invite ${email}: account exists but email not verified yet`);
            return;
        }
        await claimInvite(authUser.uid, email);
    } catch (err: unknown) {
        const code = (err as { code?: string })?.code;
        if (code === "auth/user-not-found") return; // hasn't signed up yet: normal
        logger.error(`Could not apply invite ${email}`, err);
    }
});

/** Escapes text before putting it in the HTML email. */
function escapeHtml(text: string): string {
    return text
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

/**
 * Writes the invite email to the "mail" collection. The Trigger Email
 * extension sends it and records the result on the same document
 * (delivery.state: SUCCESS or ERROR).
 *
 * Download links come from optional fields on the gym document:
 * appStoreUrl and playStoreUrl.
 */
async function queueInviteEmail(email: string, gymId: string, invitedByName?: string) {
    const db = admin.firestore();
    const gym = await db.doc(`gyms/${gymId}`).get();

    const gymName: string = gym.get("name") || "your gym";
    const appStoreUrl: string | undefined = gym.get("appStoreUrl");
    const playStoreUrl: string | undefined = gym.get("playStoreUrl");
    const from = invitedByName ? ` by ${invitedByName}` : "";

    // ----- Plain text version -----
    const textLines: string[] = [
        `You've been invited${from} to join ${gymName} in the app.`,
        "",
        "1. Download the app:",
    ];
    if (appStoreUrl) textLines.push(`   iPhone: ${appStoreUrl}`);
    if (playStoreUrl) textLines.push(`   Android: ${playStoreUrl}`);
    if (!appStoreUrl && !playStoreUrl) textLines.push("   Ask the front desk for the download link.");
    textLines.push(
        `2. Sign up with this email address: ${email}`,
        "3. Verify your email with the link we send you, and you're in.",
        "",
        "Already have the app? Just open it.",
    );

    // ----- HTML version -----
    const safeGym = escapeHtml(gymName);
    const safeFrom = escapeHtml(from);
    const links = [
        appStoreUrl ? `<a href="${escapeHtml(appStoreUrl)}">Download for iPhone</a>` : "",
        playStoreUrl ? `<a href="${escapeHtml(playStoreUrl)}">Download for Android</a>` : "",
    ].filter(Boolean).join(" &nbsp;|&nbsp; ");

    const html = `
<div style="font-family: Arial, sans-serif; font-size: 15px; line-height: 1.5; color: #222;">
  <h2 style="margin-bottom: 4px;">You're invited to ${safeGym}</h2>
  <p>You've been invited${safeFrom} to join <b>${safeGym}</b> in the app.</p>
  <ol>
    <li>${links || "Ask the front desk for the download link."}</li>
    <li>Sign up with this email address: <b>${escapeHtml(email)}</b></li>
    <li>Verify your email with the link we send you, and you're in.</li>
  </ol>
  <p style="color: #666;">Already have the app? Just open it.</p>
</div>`.trim();

    await db.collection(MAIL_COLLECTION).add({
        to: email,
        message: {
            subject: `You're invited to ${gymName}`,
            text: textLines.join("\n"),
            html,
        },
        // For your own reference in the console; the extension ignores it
        meta: { type: "invite", gymId },
    });

    logger.info(`Invite email queued for ${email} (gym ${gymId})`);
}