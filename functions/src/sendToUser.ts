import * as admin from "firebase-admin";

/**
 * Sends a push notification to one user.
 * Skips users with notifications turned off or no token
 * Removes the token if FCM says it's no longer valid.
 */
export async function sendToUser(
    userId: string,
    title: string,
    body: string,
    data: Record<string, string>
): Promise<boolean> {
    const userRef = admin.firestore().collection("users").doc(userId);
    const userDoc = await userRef.get();

    if (!userDoc) return false;

    const userData = userDoc.data();

    // Only skip users who explicitly turned notifications off
    if (userData?.notificationsEnabled === false) {
        console.log(`Notifications disabled for user ${userId}`);
        return false;
    }

    const fcmToken = userData?.fcmToken;
    if (!fcmToken) {
        console.log(`No FCM token for user ${userId}`);
        return false;
    }

    try {
        await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            data,
            android: {
                notification: { channelId: "team_flo_channel" },
            },
            apns: {
                payload: { aps: { sound: "default" } },
            },
        });
        return true;
    } catch (error: any) {
        const code = error?.code;

        // Token is dead (app deleted, reinstalled, etc.): clean it up
        if (
            code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-registration-token"
        ) {
            await userRef.update({
                fcmToken: admin.firestore.FieldValue.delete(),
            });
            console.log(`Removed stale token for user ${userId}`);
        } else {
            console.error(`Error sending to ${userId}`, error);
        }
        return false;
    }
}