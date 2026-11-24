import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { sendToUser } from "./sendToUser";

/**
 * GYM UPDATES: when staff post a new update with "Notify members" on,
 * send a push notification to everyone in that gym (except the poster).
 *
 * Tapping it opens the update in the app ({ type: "gym_update", updateId }).
 * Edits never notify: this only runs when an update is created.
 */

/** Same safety check as tag notifications: skip anything that isn't brand
 *  new (for example, updates copied in by a script or migration). */
const MAX_UPDATE_AGE_MINUTES = 10;

export const sendGymUpdateNotification = onDocumentCreated(
    "gyms/{gymId}/updates/{updateId}",
    async (event) => {
        if (!event.data) return;
        const update = event.data.data();
        const { gymId, updateId } = event.params;

        if (update.notify !== true) return;

        const createdAt =
            update.createdAt instanceof admin.firestore.Timestamp ? update.createdAt.toDate() : null;
        if (createdAt === null ||
            (Date.now() - createdAt.getTime()) / 60000 > MAX_UPDATE_AGE_MINUTES) {
            console.log(`Gym ${gymId}: skipped update ${updateId}, not new`);
            return;
        }

        const db = admin.firestore();
        const gymDoc = await db.doc(`gyms/${gymId}`).get();
        const gymName: string = gymDoc.get("name") || "Your gym";
        const heading = String(update.title || "New update").slice(0, 100);

        // Everyone in this gym. sendToUser handles people with notifications
        // turned off or no device token, the same as tag notifications.
        const members = await db.collection("users").where("gymId", "==", gymId).get();
        const recipientIds = members.docs
            .map((doc) => doc.id)
            .filter((id) => id !== update.createdBy);

        if (recipientIds.length === 0) return;

        // allSettled: one bad token shouldn't stop everyone else's notification
        const results = await Promise.allSettled(
            recipientIds.map((userId) =>
                sendToUser(userId, gymName, heading, { type: "gym_update", updateId })
            )
        );

        const failed = results.filter((r) => r.status === "rejected").length;
        console.log(
            `Gym ${gymId}: update ${updateId} sent to ${recipientIds.length - failed} member(s)` +
            (failed > 0 ? `, ${failed} failed` : "")
        );
    }
);
