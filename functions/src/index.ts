import * as admin from "firebase-admin";

admin.initializeApp();

export { sendTagNotification } from "./sendTagNotification";
export { sendWorkoutReminder } from "./sendWorkoutReminder";