import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { sendToUser } from "./sendToUser";

/** Accounts made before multi-gym support have no gymId. */
const LEGACY_GYM_ID = "teamflo";

/**
 * Sends a "You were tagged" notification to everyone @mentioned in a new post.
 *
 * PHASE 1 STEP 3: posts can live in two places, so there are two triggers
 * that share this one handler:
 *   sendTagNotification     posts/{postId}                 (Team Flo today)
 *   sendGymTagNotification  gyms/{gymId}/posts/{postId}   (scoped gyms)
 *
 * Only members of the post's gym are notified, so a post can't be used to
 * send notifications to people in another gym.
 */
async function handleNewPost(
    post: FirebaseFirestore.DocumentData,
    postId: string,
    gymId: string
): Promise<void> {
    const mentions: any[] = post.mentions || [];
    const authorId: string | undefined = post.userId;
    const authorName: string = post.userName || "Someone";

    // Remove duplicates, empty values, and the author tagging themselves
    const taggedUserIds = [
        ...new Set<string>(mentions.map((m) => m.userId).filter((id) => !!id)),
    ].filter((id) => id !== authorId);

    if (taggedUserIds.length === 0) return;

    // Keep only people in the same gym as the post
    const userDocs = await admin
        .firestore()
        .getAll(...taggedUserIds.map((id) => admin.firestore().doc(`users/${id}`)));

    const sameGymIds = userDocs
        .filter((doc) => doc.exists && (doc.get("gymId") ?? LEGACY_GYM_ID) === gymId)
        .map((doc) => doc.id);

    if (sameGymIds.length === 0) return;

    await Promise.all(
        sameGymIds.map((userId) =>
            sendToUser(
                userId,
                "You were tagged",
                `${authorName} tagged you in a post`,
                { type: "tag", postId }
            )
        )
    );

    console.log(`Gym ${gymId}: processed ${sameGymIds.length} tag notification(s)`);
}

/** Posts in the shared collection (Team Flo before migration). */
export const sendTagNotification = onDocumentCreated(
    "posts/{postId}",
    async (event) => {
        if (!event.data) return;
        await handleNewPost(event.data.data(), event.params.postId, LEGACY_GYM_ID);
    }
);

/** Posts under a gym (any gym with dataScoped turned on). */
export const sendGymTagNotification = onDocumentCreated(
    "gyms/{gymId}/posts/{postId}",
    async (event) => {
        if (!event.data) return;
        await handleNewPost(event.data.data(), event.params.postId, event.params.gymId);
    }
);