import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { sendToUser } from "./sendToUser";

export const sendTagNotification = onDocumentCreated(
    "posts/{postId}",
    async (event) => {
        const snap = event.data;
        const postId = event.params.postId;

        if (!snap) return;

        const post = snap.data();
        const mentions: any[] = post.mentions || [];

        // Check this matches the field name your posts use for the author
        const authorId: string | undefined = post.userId;
        const authorName: string = post.userName || "Someone";

        // Remove duplicates, empty values, and the author tagging themselves
        const taggedUserIds = [
            ...new Set<string>(
                mentions.map((m) => m.userId).filter((id) => !!id)
            ),
        ].filter((id) => id !== authorId);

        if (taggedUserIds.length === 0) return;

        await Promise.all(
            taggedUserIds.map((userId) =>
                sendToUser(
                    userId,
                    "You were tagged",
                    `${authorName} tagged you in a post`,
                    { type: "tag", postId }
                )
            )
        );

        console.log(`Processed ${taggedUserIds.length} tag notification(s)`);
    }
);