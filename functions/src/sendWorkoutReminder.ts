import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";
import { sendToUser } from "./sendToUser";

const TIME_ZONE = "America/New_York";

// Start sending reminds 10 minutes after class has ended
const REMINDER_DELAY_MINUTES = 10;

// Don't send a reminder any longer than 1 hour after class has ended
const LATE_LIMIT_MINUTES = 60;

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

// PHASE 1 STEP 3: class records live in the shared "classHistory" collection
// (Team Flo before migration) and under each scoped gym. Returns all of
// today's records from both places.
async function todaysClassRecords(
    db: admin.firestore.Firestore,
    today: string
): Promise<admin.firestore.QueryDocumentSnapshot[]> {
    const collections: admin.firestore.CollectionReference[] = [db.collection("classHistory")];

    const scopedGyms = await db.collection("gyms").where("dataScoped", "==", true).get();
    for (const gym of scopedGyms.docs) {
        collections.push(gym.ref.collection("classHistory"));
    }

    const snapshots = await Promise.all(
        collections.map((c) => c.where("sessionDate", "==", today).get())
    );
    return snapshots.flatMap((snap) => snap.docs);
}

// Most recent journal entry
function journalSavedAt(entry: admin.firestore.DocumentData): Date | null {
    const stamp = entry.updatedAt ?? entry.createdAt;
    return stamp instanceof admin.firestore.Timestamp ? stamp.toDate() : null;
}

export const sendWorkoutReminder = onSchedule(
    {
        schedule: "*/5 7-20 * * *",
        timeZone: TIME_ZONE,
    },
    async () => {
        const db = admin.firestore();
        const now = new Date();
        const today = easternDateString(now);
        const nowMinutes = easternMinutesNow(now);

        // Everyone with a class record for today's sessions, in every gym
        const records = await todaysClassRecords(db, today);

        if (records.length === 0) return;

        // Records whose class ended at least 10 minutes ago and hasn't been handled
        const due: admin.firestore.QueryDocumentSnapshot[] = [];
        for (const doc of records) {
            const record = doc.data();
            if (!record.userId) continue;

            // FIX: was "remnderCheckAt" (typo), so this never matched and the
            // same person could be reminded every 5 minutes for an hour.
            if (record.reminderCheckAt) continue; // already checked for this class

            if (record.status === 'noShow') continue; // signed up but didn't show up

            const endMinutes = parseTimeToMinutes(record.endTime ?? "");
            if (endMinutes === null) continue;

            const minutesSinceEnd = nowMinutes - endMinutes;
            if (minutesSinceEnd < REMINDER_DELAY_MINUTES) continue; // too early for reminder
            if (minutesSinceEnd > LATE_LIMIT_MINUTES) continue; // too late for reminder

            due.push(doc);
        }

        if (due.length === 0) return;

        console.log(`${due.length} class records due for a reminder check on ${today}`);

        // Today's date range in Eastern time
        const dayStart = easternMidnight(today, now);
        // FIX: was 24 * 60 * 1000 (24 minutes, not 24 hours), so journal
        // entries after 12:24 AM were never found and people who had
        // already logged still got reminded.
        const dayEnd = new Date(dayStart.getTime() + 24 * 60 * 60 * 1000);
        const startStamp = admin.firestore.Timestamp.fromDate(dayStart);
        const endStamp = admin.firestore.Timestamp.fromDate(dayEnd);

        let sent = 0;

        for (const doc of due) {
            const record = doc.data();
            const userId: string = record.userId;
            let sentNow = false;

            try {
                const startMinutes = parseTimeToMinutes(record.startTime ?? "") ?? 0;
                const classStart = new Date(dayStart.getTime() + startMinutes * 60 * 1000);

                const journalQuery = await db
                    .collection("users")
                    .doc(userId)
                    .collection("journal")
                    .where("date", ">=", startStamp)
                    .where("date", "<=", endStamp)
                    .get();

                const alreadyLogged = journalQuery.docs.some((entry) => {
                    const savedAt = journalSavedAt(entry.data());
                    return savedAt === null || savedAt >= classStart;
                })

                if (alreadyLogged) {
                    console.log(`User ${userId} already logged ${record.className}`);
                } else {
                    await sendToUser(
                        userId,
                        "Log your workout",
                        // FIX: the || "class" fallback was inside the text, so it
                        // showed up in the notification itself.
                        `Don't forget to log your session from ${record.className || "class"}`,
                        {type: "workout_reminder", classId: record.classId}
                    );
                    sentNow = true;
                    sent++;
                }

                await doc.ref.update({
                    reminderCheckAt: admin.firestore.FieldValue.serverTimestamp(),
                    reminderSent: sentNow,
                });
            } catch (error) {
                console.log(`Error processing reminder for ${userId}:`, error);
            }
        }

        console.log(`Sent ${sent} workout reminders`);
    }
);