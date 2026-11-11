import * as admin from "firebase-admin";

admin.initializeApp();

export { sendTagNotification, sendGymTagNotification } from "./sendTagNotification";
export { sendWorkoutReminder } from "./sendWorkoutReminder";

// Phase 1: multi-gym roles
export { syncUserClaims } from "./syncUserClaims";
export { setUserRole } from "./setUserRole";

// Invite-only access
export { claimInviteOnSignup, applyInviteToExistingAccount, claimMyInvite } from "./invites";
export { removeFromGym } from "./removeFromGym";

// Report and block
export { notifyStaffOfReport } from "./notifyStaffOfReport";