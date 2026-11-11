import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions";
import { sendToUser } from "./sendToUser";
import { normalizeRole } from "./syncUserClaims";

/**
 * REPORT AND BLOCK: when a member reports a post or comment, notify the
 * gym's owners and managers so the report is reviewed quickly.
 *
 * Reports are reviewed in the app under Staff Portal > Reports.
 * sendToUser already skips anyone who has notifications turned off.
 */
export const notifyStaffOfReport = onDocumentCreated(
    "gyms/{gymId}/reports/{reportId}",
    async (event) => {
        const report = event.data?.data();
        if (!report) return;

        const gymId = event.params.gymId;

        // Everyone in the gym, then keep owners and managers. Filtering the
        // role here (not in the query) avoids needing a Firestore index.
        const members = await admin
            .firestore()
            .collection("users")
            .where("gymId", "==", gymId)
            .get();

        const reviewerIds = members.docs
            .filter((doc) => ["owner", "manager"].includes(normalizeRole(doc.get("role"))))
            .map((doc) => doc.id)
            .filter((id) => id !== report.reportedBy);

        if (reviewerIds.length === 0) {
            logger.warn(`Gym ${gymId}: a report was filed but there is no owner or manager to notify`);
            return;
        }

        const what = report.type === "comment" ? "comment" : "post";

        await Promise.all(
            reviewerIds.map((userId) =>
                sendToUser(
                    userId,
                    "New report to review",
                    `A ${what} was reported (${report.reason || "no reason given"}). Open Staff Portal > Reports.`,
                    { type: "report", reportId: event.params.reportId }
                )
            )
        );

        logger.info(`Gym ${gymId}: notified ${reviewerIds.length} reviewer(s) of report ${event.params.reportId}`);
    }
);