import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { sendToUser } from "./sendToUser";

/** Team Flo's gym ID. Used only by the old shared posts trigger below. */
const LEGACY_GYM_ID = "teamflo";

/**
 * PHASE 1 STEP 7: only notify for posts created in the last few minutes.
 *
 * The migration copies every old post into gyms/teamflo/posts. Firestore
 * treats each copy as a new document, so without this check every old
 * @mention would be sent again. A real new post is only seconds old when
 * this runs, so 10 minutes leaves plenty of room for slow triggers.
 */
const MAX_POST_AGE_MINUTES = 10;

/** Reads createdAt whether it's a Firestore Timestamp, a Date, or a string. */
function postCreatedAt(post: FirebaseFirestore.DocumentData): Date | null {
    const value = post.createdAt;
    if (value instanceof admin.firestore.Timestamp) return value.toDate();
    if (value instanceof Date) return value;
    if (typeof value === "string") {
        const parsed = new Date(value);
        return isNaN(parsed.getTime()) ? null : parsed;
    }
    return null;
}

function isRecentPost(post: FirebaseFirestore.DocumentData): boolean {
    const createdAt = postCreatedAt(post);
    // No readable date: skip rather than risk re-sending an old mention.
    if (createdAt === null) return false;
    const ageMinutes = (Date.now() - createdAt.getTime()) / 60000;
    return ageMinutes <= MAX_POST_AGE_MINUTES;
}

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
    if (!isRecentPost(post)) {
        console.log(`Gym ${gymId}: skipped post ${postId}, created more than ${MAX_POST_AGE_MINUTES} min ago (copied or migrated)`);
        return;
    }

    const mentions: any[] = post.mentions || [];
    const authorId: string | undefined = post.userId;
    const authorName: string = post.userName || "Someone";

    // Remove duplicates, empty values, and the author tagging themselves
    const taggedUserIds = [
        ...new Set<string>(mentions.map((m) => m.userId).filter((id) => !!id)),
    ].filter((id) => id !== authorId);

    if (taggedUserIds.length === 0) return;

    // Keep only people in the same gym as the post.
    // INVITES: an account with no gymId hasn't been invited to any gym,
    // so it is never notified (was: treated as Team Flo).
    const userDocs = await admin
        .firestore()
        .getAll(...taggedUserIds.map((id) => admin.firestore().doc(`users/${id}`)));

    const sameGymIds = userDocs
        .filter((doc) => doc.exists && doc.get("gymId") === gymId)
        .map((doc) => doc.id);

    if (sameGymIds.length === 0) return;

    // REPORT AND BLOCK: don't notify anyone who has blocked the author.
    // A member's block list is users/{uid}/blocked/{blockedUid}.
    let notifyIds = sameGymIds;
    if (authorId) {
        const blockDocs = await admin.firestore().getAll(
            ...sameGymIds.map((id) => admin.firestore().doc(`users/${id}/blocked/${authorId}`))
        );
        notifyIds = sameGymIds.filter((_, i) => !blockDocs[i].exists);
    }

    if (notifyIds.length === 0) return;

    await Promise.all(
        notifyIds.map((userId) =>
            sendToUser(
                userId,
                "You were tagged",
                `${authorName} tagged you in a post`,
                { type: "tag", postId }
            )
        )
    );

    console.log(`Gym ${gymId}: processed ${notifyIds.length} tag notification(s)`);
}

/**
 * Posts in the old shared collection. Since step 7 this collection is a
 * read-only backup, so this trigger no longer fires. It can be removed
 * when the old collections are deleted.
 */
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