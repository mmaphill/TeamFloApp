import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { normalizeRole } from "./syncUserClaims";

const LEGACY_GYM_ID = "teamflo";

/** Roles that can be handed out through this function. */
const ASSIGNABLE = ["owner", "manager", "instructor", "front_desk", "member"];

/**
 * Change another member's role. Called from the app:
 *
 *   FirebaseFunctions.instance
 *       .httpsCallable('setUserRole')
 *       .call({'targetUid': uid, 'role': 'instructor'});
 *
 * Rules:
 *  - Caller must be an owner or manager.
 *  - Caller and target must be in the same gym.
 *  - Only an owner can give or take away owner or manager.
 *  - Nobody can change their own role (stops an owner locking themselves out).
 *
 * Reads roles from Firestore (not claims) so it works before claims exist.
 * syncUserClaims then copies the new role into the target's claims.
 */
export const setUserRole = onCall(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new HttpsError("unauthenticated", "Please sign in.");
    }

    const targetUid = request.data?.targetUid;
    const newRole = request.data?.role;

    if (typeof targetUid !== "string" || targetUid.length === 0) {
        throw new HttpsError("invalid-argument", "targetUid is required.");
    }
    if (typeof newRole !== "string" || !ASSIGNABLE.includes(newRole)) {
        throw new HttpsError("invalid-argument", `role must be one of: ${ASSIGNABLE.join(", ")}.`);
    }
    if (targetUid === callerUid) {
        throw new HttpsError("failed-precondition", "You can't change your own role.");
    }

    const db = admin.firestore();
    const [callerSnap, targetSnap] = await Promise.all([
        db.collection("users").doc(callerUid).get(),
        db.collection("users").doc(targetUid).get(),
    ]);

    if (!callerSnap.exists || !targetSnap.exists) {
        throw new HttpsError("not-found", "User not found.");
    }

    const caller = callerSnap.data()!;
    const target = targetSnap.data()!;

    const callerRole = normalizeRole(caller.role);
    const targetRole = normalizeRole(target.role);
    const callerGym = caller.gymId ?? LEGACY_GYM_ID;
    const targetGym = target.gymId ?? LEGACY_GYM_ID;

    if (callerGym !== targetGym) {
        throw new HttpsError("permission-denied", "That member is not in your gym.");
    }
    if (callerRole !== "owner" && callerRole !== "manager") {
        throw new HttpsError("permission-denied", "Only owners and managers can change roles.");
    }

    // Managers can't create or demote owners and managers.
    const touchesSeniorRole =
        ["owner", "manager"].includes(newRole) || ["owner", "manager"].includes(targetRole);
    if (touchesSeniorRole && callerRole !== "owner") {
        throw new HttpsError("permission-denied", "Only an owner can change owner or manager roles.");
    }

    await targetSnap.ref.update({
        role: newRole,
        roleUpdatedBy: callerUid,
        roleUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info(`${callerUid} set ${targetUid} to ${newRole} in gym ${callerGym}`);
    return { ok: true, role: newRole };
});