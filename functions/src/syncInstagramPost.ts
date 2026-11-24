import * as admin from "firebase-admin";
import { randomUUID } from "crypto";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";

/**
 * INSTAGRAM PHASE 2: keeps the Home screen's Instagram card up to date.
 *
 * Every hour: ask Instagram for the gym's newest post. If it's new, copy
 * its picture into our Storage (Instagram's picture links expire after a
 * while) and update gyms/{gymId}/instagram/latestPost, the document the
 * app's InstagramFeedWidget already reads. No app update needed.
 *
 * The token is a Meta system-user token (never expires) saved with:
 *   firebase functions:secrets:set INSTAGRAM_TOKEN --project teamflo
 */
const INSTAGRAM_TOKEN = defineSecret("INSTAGRAM_TOKEN");

const GRAPH_VERSION = "v24.0";

/**
 * Which Instagram account feeds which gym. One entry per gym.
 * igUserId comes from the Graph API (team_flo_bjj). When another gym
 * joins, add a line here (and give it its own token secret).
 */
const ACCOUNTS: { gymId: string; igUserId: string }[] = [
    { gymId: "teamflo", igUserId: "17841403207049067" },
];

/** What Instagram sends back for one post (only the fields we ask for). */
interface IgMedia {
    id: string;
    caption?: string;
    media_type: "IMAGE" | "VIDEO" | "CAROUSEL_ALBUM";
    media_url?: string;
    thumbnail_url?: string;
    permalink: string;
    timestamp: string; // e.g. "2026-11-24T15:02:26+0000"
}

export const syncInstagramPost = onSchedule(
    {
        schedule: "every 60 minutes",
        timeZone: "America/New_York",
        secrets: [INSTAGRAM_TOKEN],
        // Don't retry a failed run: the next hourly run is the retry
        retryCount: 0,
    },
    async () => {
        for (const account of ACCOUNTS) {
            try {
                await syncOneGym(account.gymId, account.igUserId, INSTAGRAM_TOKEN.value());
            } catch (e) {
                // One gym failing shouldn't stop the others. Logged for the console.
                console.error(`Instagram sync failed for gym ${account.gymId}:`, e);
            }
        }
    }
);

async function syncOneGym(gymId: string, igUserId: string, token: string): Promise<void> {
    // ----- 1. Newest post from Instagram -----
    const fields = "id,caption,media_type,media_url,thumbnail_url,permalink,timestamp";
    const url =
        `https://graph.facebook.com/${GRAPH_VERSION}/${igUserId}/media` +
        `?fields=${fields}&limit=1&access_token=${encodeURIComponent(token)}`;

    const res = await fetch(url);
    if (!res.ok) {
        // Never log the URL itself: it contains the token
        const body = await res.text();
        throw new Error(`Instagram API returned ${res.status}: ${body.slice(0, 300)}`);
    }
    const json = (await res.json()) as { data?: IgMedia[] };
    const post = json.data?.[0];
    if (!post) {
        console.log(`Gym ${gymId}: no Instagram posts found`);
        return;
    }

    // ----- 2. Skip if we already have this post -----
    const db = admin.firestore();
    const docRef = db.doc(`gyms/${gymId}/instagram/latestPost`);
    const current = await docRef.get();
    if (current.get("instagramId") === post.id) {
        console.log(`Gym ${gymId}: latest post ${post.id} already saved, nothing to do`);
        return;
    }

    // ----- 3. Copy the picture into Storage -----
    // Videos (reels): use the cover image. Photos and carousels: the
    // picture itself (for a carousel, the first slide).
    const sourceUrl = post.media_type === "VIDEO" ? post.thumbnail_url : post.media_url;
    if (!sourceUrl) {
        throw new Error(`Post ${post.id} (${post.media_type}) has no picture to show`);
    }

    const imageRes = await fetch(sourceUrl);
    if (!imageRes.ok) throw new Error(`Could not download picture: ${imageRes.status}`);
    const imageBytes = Buffer.from(await imageRes.arrayBuffer());

    const bucket = admin.storage().bucket();
    const folder = `instagram/${gymId}/`;
    const path = `${folder}${post.id}.jpg`;
    const downloadToken = randomUUID();

    await bucket.file(path).save(imageBytes, {
        contentType: imageRes.headers.get("content-type") ?? "image/jpeg",
        metadata: {
            cacheControl: "public, max-age=86400",
            // Lets the app load it with a normal Firebase download link
            metadata: { firebaseStorageDownloadTokens: downloadToken },
        },
    });
    const imageUrl =
        `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/` +
        `${encodeURIComponent(path)}?alt=media&token=${downloadToken}`;

    // ----- 4. Update the document the app's card reads -----
    // Same four fields the card already uses, plus a few for this function.
    await docRef.set({
        caption: post.caption ?? "",
        imageUrl,
        postLink: post.permalink,
        timestamp: admin.firestore.Timestamp.fromDate(parseIgTime(post.timestamp)),
        instagramId: post.id,
        mediaType: post.media_type,
        source: "auto",
        syncedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // ----- 5. Remove older pictures this function saved (only this gym's folder) -----
    const [files] = await bucket.getFiles({ prefix: folder });
    await Promise.allSettled(
        files.filter((f) => f.name !== path).map((f) => f.delete({ ignoreNotFound: true }))
    );

    console.log(`Gym ${gymId}: Instagram card updated to post ${post.id} (${post.media_type})`);
}

/** Instagram writes "+0000"; turn it into "+00:00" so Date reads it reliably. */
function parseIgTime(value: string): Date {
    const fixed = value.replace(/([+-]\d{2})(\d{2})$/, "$1:$2");
    const date = new Date(fixed);
    return isNaN(date.getTime()) ? new Date() : date;
}