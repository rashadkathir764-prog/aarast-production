import { UserRole } from "@prisma/client";

export const applicationNameFields = {
  name: true,
  appName: true,
  role: true,
} as const;

export const applicationAvatarFields = {
  ...applicationNameFields,
  avatarUrl: true,
  appAvatarUrl: true,
} as const;

export interface ApplicationNameSource {
  name: string;
  appName: string | null;
  role: UserRole;
}

export interface ApplicationAvatarSource extends ApplicationNameSource {
  avatarUrl: string | null;
  appAvatarUrl: string | null;
}

export function applicationDisplayName(user: ApplicationNameSource): string {
  if (user.role !== UserRole.ADMIN) return user.name;
  const appName = user.appName?.trim();
  return appName || "مستخدم اعّرست";
}

export function applicationDisplayAvatar(
  user: ApplicationAvatarSource,
): string | null {
  return user.role === UserRole.ADMIN ? user.appAvatarUrl : user.avatarUrl;
}

export function toApplicationUserContact<
  T extends ApplicationNameSource & { id: string; phone: string | null },
>(user: T) {
  return {
    id: user.id,
    name: applicationDisplayName(user),
    phone: user.phone,
  };
}

export function toApplicationUserSummary<
  T extends ApplicationAvatarSource & { id: string },
>(user: T) {
  return {
    id: user.id,
    name: applicationDisplayName(user),
    avatarUrl: applicationDisplayAvatar(user),
  };
}
