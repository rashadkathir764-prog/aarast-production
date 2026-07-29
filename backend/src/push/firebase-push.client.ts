import { Injectable } from "@nestjs/common";
import {
  App,
  applicationDefault,
  getApps,
  initializeApp,
} from "firebase-admin/app";
import {
  BatchResponse,
  FidMulticastMessage,
  getMessaging,
} from "firebase-admin/messaging";

export const PUSH_NOTIFICATIONS_ENABLED_ENV = "PUSH_NOTIFICATIONS_ENABLED";
export const FIREBASE_PROJECT_ID_ENV = "FIREBASE_PROJECT_ID";

@Injectable()
export class FirebasePushClient {
  private app: App | null = null;

  get enabled(): boolean {
    return process.env[PUSH_NOTIFICATIONS_ENABLED_ENV]?.trim() === "true";
  }

  async sendEachForMulticast(
    message: FidMulticastMessage,
  ): Promise<BatchResponse> {
    return getMessaging(this.firebaseApp()).sendEachForMulticast(message);
  }

  private firebaseApp(): App {
    if (this.app) return this.app;
    if (!this.enabled) {
      throw namedError("PushNotificationsDisabledError");
    }
    const projectId = process.env[FIREBASE_PROJECT_ID_ENV]?.trim();
    if (!projectId) {
      throw namedError("PushConfigurationError");
    }
    const appName = "aarast-push";
    this.app =
      getApps().find((candidate) => candidate.name === appName) ??
      initializeApp(
        {
          credential: applicationDefault(),
          projectId,
        },
        appName,
      );
    return this.app;
  }
}

function namedError(name: string): Error {
  const error = new Error(name);
  error.name = name;
  return error;
}
