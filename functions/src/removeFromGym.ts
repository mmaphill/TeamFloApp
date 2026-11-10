import * as admin from "firebase-admin";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { normalizeRole } from "./syncUserClaims";
import { normalizeEmail } from "./invites";

/** Roles a manager may remove. Owners may remove anyone except themselves. */
const MANAGER_CAN_REMOVE = ["member", "front_desk", "instructor"];

/**
 * Remove a member from the gym. Called from Staff Portal > Members:
 *
 *   FirebaseFunctions.instance
 *       .httpsCallable('removeFromGym')
 *       .call({'targetUid': uid});
 *
 * Rules:
 *  - Caller must be an owner or manager, in the same gym as the target.
 *  - Owners can remove anyone except themselves.
 *  - Managers can remove members, front desk and instructors only.
 *
 * What happens:
 *  - The target's gymId is cleared and their role goes back to member, so
 *    they land on the "Waiting for an invite" screen right away.
 *  - Their posts, comments and journal entries are kept.
 *  - Their invite is marked revoked, so staff can "Invite again" later.
 *
 * Reads roles from Firestore (not claims), like setUserRole.
 */
export const removeFromGym = onCall(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new HttpsError("unauthenticated", "Please sign in.");
    }

    const targetUid = request.data?.targetUid;
    if (typeof targetUid !== "string" || targetUid.length === 0) {
        throw new HttpsError("invalid-argument", "targetUid is required.");
    }
    if (targetUid === callerUid) {
        throw new HttpsError("failed-precondition", "You can't remove yourself.");
    }

    const db = admin.firestore();
    const [callerSnap, targetSnap] = await Promise.all([
        db.collection("users").doc(callerUid).get(),
        db.collection("users").doc(targetUid).get(),
    ]);
    if (!callerSnap.exists || !targetSnap.exists) {
        throw new HttpsError("not-found", "User not found.");
    }

    const callerGym = callerSnap.get("gymId");
    const targetGym = targetSnap.get("gymId");
    const callerRole = normalizeRole(callerSnap.get("role"));
    const targetRole = normalizeRole(targetSnap.get("role"));

    if (typeof callerGym !== "string" || callerGym !== targetGym) {
        throw new HttpsError("permission-denied", "That member is not in your gym.");
    }
    if (callerRole !== "owner" && callerRole !== "manager") {
        throw new HttpsError("permission-denied", "Only owners and managers can remove members.");
    }
    if (callerRole === "manager" && !MANAGER_CAN_REMOVE.includes(targetRole)) {
        throw new HttpsError("permission-denied", "Only an owner can remove an owner or manager.");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    // 1. Take away gym access
    await targetSnap.ref.update({
        gymId: admin.firestore.FieldValue.delete(),
        role: "member",
        roleUpdatedBy: callerUid,
        roleUpdatedAt: now,
        removedFromGymId: callerGym,
        removedBy: callerUid,
        removedAt: now,
    });

    // 2. Mark their invite revoked so it shows under "Revoked" with
    //    "Invite again". Older members joined before invites existed and
    //    have none, which is fine.
    try {
        const authUser = await admin.auth().getUser(targetUid);
        if (authUser.email) {
            const inviteRef = db.doc(`invites/${normalizeEmail(authUser.email)}`);
            const invite = await inviteRef.get();
            if (invite.exists && invite.get("gymId") === callerGym) {
                await inviteRef.update({ status: "revoked", revokedBy: callerUid, revokedAt: now });
            }
        }
    } catch (err) {
        logger.warn(`Removed ${targetUid} but could not update their invite`, err);
    }

    logger.info(`${callerUid} (${callerRole}) removed ${targetUid} (${targetRole}) from gym ${callerGym}`);
    return { ok: true };
});