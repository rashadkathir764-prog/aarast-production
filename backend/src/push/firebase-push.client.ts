import { Injectable, Logger, type OnApplicationBootstrap } from "@nestjs/common";
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
import type { PushCapabilityPort } from "../modules/notifications/public/push-capability.port";
import {
  FIREBASE_PROJECT_ID_ENV,
  PUSH_NOTIFICATIONS_ENABLED_ENV,
  pushStatus,
} from "../platform/config/push-status";

export { FIREBASE_PROJECT_ID_ENV, PUSH_NOTIFICATIONS_ENABLED_ENV };

let bootStatusLogged = false;

@Injectable()
export class FirebasePushClient implements PushCapabilityPort, OnApplicationBootstrap {
  private readonly logger = new Logger("PushNotifications");
  private app: App | null = null;

  get enabled(): boolean {
    return pushStatus().enabled;
  }

  /**
   * Said once at boot, so a server that would record every push as
   * DISABLED says it before the first notice does.
   */
  onApplicationBootstrap(): void {
    if (bootStatusLogged) return;
    bootStatusLogged = true;
    const status = pushStatus();
    if (status.enabled) {
      this.logger.log(`Push notifications enabled for Firebase project ${status.projectId}`);
    } else {
      this.logger.warn(
        "Push notifications disabled on this server: every push is recorded as DISABLED",
      );
    }
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
