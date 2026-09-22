import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

export const sendWorkoutReminder = onSchedule(
    {
        schedule: "0 20 * * *",
        timeZone: "America/New_York",
    },
    async () => {
        try {
            const today = new Date();
            today.setHours(0, 0, 0, 0);

            const tomorrow = new Date(today);
            tomorrow.setDate(tomorrow.getDate() + 1);

            const classesSnapshot = await admin
                .firestore()
                .collection("classes")
                .where("classDate", ">=", today)
                .where("classDate", "<", tomorrow)
                .get();

            console.log(`Found ${classesSnapshot.docs.length} classes for today`);

            for (const classDoc of classesSnapshot.docs) {
                const classData = classDoc.data();
                const attendees = classData.attendees || [];

                console.log(
                    `Processing class ${classDoc.id} with ${attendees.length} attendees`
                );

                for (const userId of attendees) {
                    try {
                        const userDoc = await admin
                            .firestore()
                            .collection("users")
                            .doc(userId)
                            .get();

                        if (!userDoc.exists) continue;

                        const userData = userDoc.data();

                        if (!userData?.notificationsEnabled) continue;

                        const fcmToken = userData?.fcmToken;
                        if (!fcmToken) continue;

                        const journalQuery = await admin
                            .firestore()
                            .collection("users")
                            .doc(userId)
                            .collection("journal")
                            .where("classId", "==", classDoc.id)
                            .get();

                        if (!journalQuery.empty) {
                            console.log(
                                `User ${userId} already logged class ${classDoc.id}`
                            );
                            continue;
                        }

                        await admin.messaging().send({
                            token: fcmToken,
                            notification: {
                                title: "Log your workout",
                                body: `Don't forget to log your session from ${classData.className}`,
                            },
                            data: {
                                type: "workout_reminder",
                                classId: classDoc.id,
                            },
                        });

                        console.log(`Sent workout reminder to ${userId}`);
                    } catch (error) {
                        console.error(`Error sending reminder to ${userId}:`, error);
                    }
                }
            }
        } catch (error) {
            console.error("Error in sendWorkoutReminder:", error);
            throw error;
        }
    }
);