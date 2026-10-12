import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { sendToUser } from "./sendToUser";

const TIME_ZONE = "America/New_York";

// Today's date in Eastern time as "yyyy-MM-dd" (e.g. "2026-10-12").
// Matches the sessionDate format the app writes.
function easternDateString(date: Date): string {
    return new Intl.DateTimeFormat("en-CA", {
        timeZone: TIME_ZONE,
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
    }).format(date);
}

// Current time in Eastern as minutes since midnight (8:00 PM -> 1200).
function easternMinutesNow(date: Date): number {
    const parts = new Intl.DateTimeFormat("en-US", {
        timeZone: TIME_ZONE,
        hour: "2-digit",
        minute: "2-digit",
        hourCycle: "h23",
    }).formatToParts(date);
    const hour = Number(parts.find((p) => p.type === "hour")?.value ?? 0);
    const minute = Number(parts.find((p) => p.type === "minute")?.value ?? 0);
    return hour * 60 + minute;
}

// Midnight at the start of an Eastern date, as a real point in time.
// Handles EST (-05:00) and EDT (-04:00) automatically.
function easternMidnight(dateString: string, reference: Date): Date {
    const offsetText =
        new Intl.DateTimeFormat("en-US", {
            timeZone: TIME_ZONE,
            timeZoneName: "shortOffset",
        })
            .formatToParts(reference)
            .find((p) => p.type === "timeZoneName")?.value ?? "GMT-5";

    // "GMT-4" -> sign "-", hours "04", minutes "00"
    const match = offsetText.match(/GMT([+-])(\d{1,2})(?::(\d{2}))?/);
    const sign = match?.[1] ?? "-";
    const hours = (match?.[2] ?? "5").padStart(2, "0");
    const minutes = match?.[3] ?? "00";

    return new Date(`${dateString}T00:00:00${sign}${hours}:${minutes}`);
}

// "12:15 PM" -> 735 minutes since midnight. Returns null if unreadable.
// Same format the app uses for startTime/endTime.
function parseTimeToMinutes(time: string): number | null {
    const match = time.trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)$/i);
    if (!match) return null;
    let hour = Number(match[1]) % 12;
    if (match[3].toUpperCase() === "PM") hour += 12;
    return hour * 60 + Number(match[2]);
}

export const sendWorkoutReminder = onSchedule(
    {
        schedule: "0 20 * * *",
        timeZone: TIME_ZONE,
    },
    async () => {
        const db = admin.firestore();
        const now = new Date();
        const today = easternDateString(now);
        const nowMinutes = easternMinutesNow(now);

        // Everyone with a class record for today's sessions
        const historySnapshot = await db
            .collection("classHistory")
            .where("sessionDate", "==", today)
            .get();

        console.log(`Found ${historySnapshot.size} classHistory records for ${today}`);

        // One reminder per person, even if they trained twice today
        const toRemind = new Map<string, { classId: string; className: string }>();

        for (const doc of historySnapshot.docs) {
            const record = doc.data();
            const userId: string | undefined = record.userId;
            if (!userId) continue;

            // Marked absent by staff
            if (record.status === "noShow") continue;

            // Class hasn't finished yet (e.g. a class ending after 8 PM)
            const endMinutes = parseTimeToMinutes(record.endTime ?? "");
            if (endMinutes !== null && endMinutes > nowMinutes) continue;

            if (!toRemind.has(userId)) {
                toRemind.set(userId, {
                    classId: record.classId,
                    className: record.className || "class",
                });
            }
        }

        console.log(`${toRemind.size} members trained today`);

        // Journal entries dated today (Eastern) count as "already logged"
        const dayStart = easternMidnight(today, now);
        const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
        const startStamp = admin.firestore.Timestamp.fromDate(dayStart);
        const endStamp = admin.firestore.Timestamp.fromDate(dayEnd);

        let sent = 0;

        for (const [userId, info] of toRemind) {
            try {
                const journalQuery = await db
                    .collection("users")
                    .doc(userId)
                    .collection("journal")
                    .where("date", ">=", startStamp)
                    .where("date", "<", endStamp)
                    .limit(1)
                    .get();

                if (!journalQuery.empty) {
                    console.log(`User ${userId} already logged today`);
                    continue;
                }

                await sendToUser(
                    userId,
                    "Log your workout",
                    `Don't forget to log your session from ${info.className}`,
                    { type: "workout_reminder", classId: info.classId }
                );
                sent++;
            } catch (error) {
                console.error(`Error processing reminder for ${userId}:`, error);
            }
        }

        console.log(`Sent ${sent} workout reminders`);
    }
);