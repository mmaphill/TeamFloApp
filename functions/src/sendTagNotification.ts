import { onDocumentCreated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

export const sendTagNotification = onDocumentCreated(
    "posts/{postId}",
    async (event) => {
        const snap = event.data;
        const postId = event.params.postId;

        if (!snap) return;

        const post = snap.data();
        const mentions = post.mentions || [];

        const taggedUserIds = mentions.map((m: any) => m.userId);

        if (taggedUserIds.length === 0) return;

        for (const userId of taggedUserIds) {
            try {
                const userDoc = await admin
                    .firestore()
                    .collection("users")
                    .doc(userId)
                    .get();

                if (!userDoc.exists) continue;

                const userData = userDoc.data();

                if (!userData?.notificationsEnabled) {
                    console.log(`Notifications disabled for user ${userId}`);
                    continue;
                }

                const fcmToken = userData?.fcmToken;
                if (!fcmToken) {
                    console.log(`No FCM token for user ${userId}`);
                    continue;
                }

                await admin.messaging().send({
                    token: fcmToken,
                    notification: {
                        title: "You were tagged",
                        body: `${post.userName} tagged you in a post`,
                    },
                    data: {
                        type: "tag",
                        postId: postId,
                    },
                });

                console.log(`Sent tag notification to ${userId}`);
            } catch (error) {
                console.error(`Error sending notification to ${userId}:`, error);
            }
        }
    }
);