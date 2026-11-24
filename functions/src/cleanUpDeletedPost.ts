import * as admin from "firebase-admin";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";

/**
 * POST CLEANUP: when a post is deleted, remove what it leaves behind.
 *
 *  1. Its photos and videos in Storage (posts/{userId}/...)
 *  2. Its comments. Firestore does NOT delete a document's subcollections
 *     when the document is deleted, so without this they stay forever.
 *
 * Runs on the server for every kind of delete (the author, an owner or
 * manager moderating, account deletion), so the app doesn't need to change.
 */

/**
 * Turns a Firebase Storage download URL back into the file's path.
 *   https://firebasestorage.googleapis.com/v0/b/BUCKET/o/posts%2Fuid%2Fabc.jpg?alt=media&token=...
 *   -> "posts/uid/abc.jpg"
 * Returns null for anything that isn't a Storage URL in the posts/ folder,
 * so a strange URL can never delete a file outside post media.
 */
function storagePathFromUrl(url: unknown): string | null {
    if (typeof url !== "string") return null;
    const marker = "/o/";
    const start = url.indexOf(marker);
    if (!url.includes("firebasestorage.googleapis.com") || start === -1) return null;

    const encoded = url.substring(start + marker.length).split("?")[0];
    let path: string;
    try {
        path = decodeURIComponent(encoded);
    } catch {
        return null;
    }
    return path.startsWith("posts/") ? path : null;
}

export const cleanUpDeletedPost = onDocumentDeleted(
    "gyms/{gymId}/posts/{postId}",
    async (event) => {
        if (!event.data) return;
        const post = event.data.data();
        const { gymId, postId } = event.params;

        // ----- 1. Media files -----
        const urls: unknown[] = Array.isArray(post.mediaUrls) ? post.mediaUrls : [];
        const paths = urls
            .map(storagePathFromUrl)
            .filter((p): p is string => p !== null);

        const bucket = admin.storage().bucket();
        const fileResults = await Promise.allSettled(
            // ignoreNotFound: a file that's already gone counts as done
            paths.map((path) => bucket.file(path).delete({ ignoreNotFound: true }))
        );
        const filesFailed = fileResults.filter((r) => r.status === "rejected").length;

        // ----- 2. Comments -----
        let commentsCleaned = true;
        try {
            await admin.firestore().recursiveDelete(event.data.ref.collection("comments"));
        } catch (e) {
            commentsCleaned = false;
            console.error(`Gym ${gymId}: could not delete comments of post ${postId}`, e);
        }

        console.log(
            `Gym ${gymId}: post ${postId} cleaned up. ` +
            `Files removed: ${paths.length - filesFailed}/${paths.length}` +
            (commentsCleaned ? ", comments removed" : ", comments NOT removed")
        );
    }
);