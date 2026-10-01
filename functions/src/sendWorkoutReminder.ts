import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { sendToUser } from "./sendToUser";

export const sendWorkoutReminder = onSchedule(
    {
        schedule: "0 20 * * *",
        timeZone: "America/New_York",
    },
    async () => {
        // Look back 24 hours from now. This avoids the UTC/Eastern mismatch,
        // and each class falls into exactly one daily run.
        const now = new Date();
        const dayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

        const classesSnapshot = await admin
            .firestore()
            .collection("classes")
            .where("classDate", ">=", dayAgo)
            .where("classDate", "<", now)
            .get();

        console.log(`Found ${classesSnapshot.size} classes in the last 24 hours`);

        for (const classDoc of classesSnapshot.docs) {
            const classData = classDoc.data();
            const attendees: string[] = classData.attendees || [];
            const className: string = classData.className || "class";

            for (const userId of attendees) {
                try {
                    // Skip users who already logged this class
                    const journalQuery = await admin
                        .firestore()
                        .collection("users")
                        .doc(userId)
                        .collection("journal")
                        .where("classId", "==", classDoc.id)
                        .limit(1)
                        .get();

                    if (!journalQuery.empty) continue;

                    await sendToUser(
                        userId,
                        "Log your workout",
                        `Don't forget to log your session from ${className}`,
                        { type: "workout_reminder", classId: classDoc.id }
                    );
                } catch (error) {
                    console.error(`Error processing reminder for ${userId}:`, error);
                }
            }
        }
    }
);