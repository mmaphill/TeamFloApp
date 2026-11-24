import * as admin from "firebase-admin";

admin.initializeApp();

export { sendTagNotification, sendGymTagNotification } from "./sendTagNotification";

// Post cleanup: delete a post's media and comments when the post is deleted
export { cleanUpDeletedPost } from "./cleanUpDeletedPost";
export { sendWorkoutReminder } from "./sendWorkoutReminder";

// Phase 1: multi-gym roles
export { syncUserClaims } from "./syncUserClaims";
export { setUserRole } from "./setUserRole";

// Invite-only access
export { claimInviteOnSignup, applyInviteToExistingAccount, claimMyInvite } from "./invites";
export { removeFromGym } from "./removeFromGym";

// Instagram: hourly sync of the gym's latest Instagram post
export { syncInstagramPost } from "./syncInstagramPost";

// Gym updates (news and events on the Home screen)
export { sendGymUpdateNotification } from "./sendGymUpdateNotification";

// Report and block
export { notifyStaffOfReport } from "./notifyStaffOfReport";

// Account deletion (runs on the server so nothing is left behind)
export { deleteMyAccount } from "./deleteMyAccount";