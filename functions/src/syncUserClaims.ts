import * as admin from "firebase-admin";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";

/** Accounts made before multi-gym support have no gymId. */
const LEGACY_GYM_ID = "teamflo";

const ROLES = ["owner", "manager", "instructor", "front_desk", "member"];

/** 'admin' on older accounts becomes 'owner'; anything unknown becomes 'member'. */
export function normalizeRole(role: unknown): string {
    if (role === "admin") return "owner";
    if (typeof role === "string" && ROLES.includes(role)) return role;
    return "member";
}

/**
 * Copies gymId and role from users/{uid} into the user's Auth custom claims.
 *
 * Security rules can trust claims (request.auth.token.gymId / .role)
 * because only this server code can set them. The app refreshes its
 * token when it sees the user doc change (GymService does this).
 */
export const syncUserClaims = onDocumentWritten("users/{uid}", async (event) => {
    const uid = event.params.uid;
    const after = event.data?.after.data();

    // User doc deleted (account deletion): nothing to sync.
    if (!after) return;

    const gymId: string = typeof after.gymId === "string" ? after.gymId : LEGACY_GYM_ID;
    const role = normalizeRole(after.role);

    try {
        const user = await admin.auth().getUser(uid);
        const current = user.customClaims ?? {};

        // Skip the write if nothing changed. Saves a call on every profile edit.
        if (current.gymId === gymId && current.role === role) return;

        await admin.auth().setCustomUserClaims(uid, { ...current, gymId, role });
        logger.info(`Claims set for ${uid}: gym=${gymId}, role=${role}`);
    } catch (err) {
        // The Auth user may already be gone during account deletion.
        logger.warn(`Could not set claims for ${uid}`, err);
    }
});