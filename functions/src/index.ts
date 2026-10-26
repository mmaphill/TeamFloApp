import * as admin from "firebase-admin";

admin.initializeApp();

export { sendTagNotification, sendGymTagNotification } from "./sendTagNotification";
export { sendWorkoutReminder } from "./sendWorkoutReminder";

// Phase 1: multi-gym roles
export { syncUserClaims } from "./syncUserClaims";
export { setUserRole } from "./setUserRole";