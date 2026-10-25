import {
  GuestAttendanceStatus,
  Prisma,
  WeddingTaskStatus,
} from "@prisma/client";
import { applicationDisplayName } from "../shared-kernel/privacy/application-user-identity";
import type { PlanAccessContext } from "../modules/collaboration/public/collaboration-permission.port";
import type { InsightsReadPorts } from "./insights-read-ports";

/**
 * Who does a task, as a member reads it: the reader, the plan's owner,
 * another member, or a person the owner named by hand. Only a first name,
 * never an id or a phone.
 */
export interface PlanReadAssignee {
  kind: "YOU" | "OWNER" | "MEMBER" | "PERSON";
  firstName: string | null;
}

export interface PlanReadTaskResponse {
  id: string;
  title: string;
  status: WeddingTaskStatus;
  dueDate: Date | null;
  assignee: PlanReadAssignee | null;
}

export interface PlanReadGuestResponse {
  id: string;
  name: string;
  attendanceStatus: GuestAttendanceStatus;
}

export interface PlanReadBookingResponse {
  id: string;
  businessName: string;
  categoryName: string | null;
  serviceTitle: string | null;
  status: "REQUESTED" | "CONFIRMED";
  eventDate: Date;
}

/**
 * D52: the plan's non-money sections as every member reads them. Each field
 * is listed here on purpose; nothing is spread from a row, so no amount,
 * budget, payment, funding, description, phone, note or link can reach a
 * reader through this response.
 */
export interface PlanReadViewResponse {
  weddingPlanId: string;
  tasks: {
    total: number;
    done: number;
    items: PlanReadTaskResponse[];
  };
  guests: {
    total: number;
    confirmed: number;
    pending: number;
    declined: number;
    items: PlanReadGuestResponse[];
  };
  bookings: {
    items: PlanReadBookingResponse[];
  };
}

/** «محمد» from «محمد علي الحمدي»: the first word of the name the app shows. */
export function firstNameOf(name: string | null | undefined): string | null {
  const first = name?.trim().split(/\s+/)[0];
  return first ? first : null;
}

/** Builds the read view on the caller's transaction, after the caller proved membership. */
export async function loadPlanReadView(
  tx: Prisma.TransactionClient,
  owners: InsightsReadPorts,
  context: PlanAccessContext,
  readerUserId: string,
): Promise<PlanReadViewResponse> {
  const weddingPlanId = context.plan.id;
  const [tasks, guests, bookings] = await Promise.all([
    owners.tasks.listReadableTasks(tx, weddingPlanId, readerUserId),
    owners.guests.listReadableGuests(tx, weddingPlanId),
    owners.quotes.listReadableBookings(tx, weddingPlanId),
  ]);

  const ownerUserId = context.plan.ownerUserId;
  const assigneeIds = [
    ...new Set(
      tasks.flatMap((task) =>
        task.assigneeUserId && task.assigneeUserId !== readerUserId
          ? [task.assigneeUserId]
          : [],
      ),
    ),
  ];
  const [identities, categories] = await Promise.all([
    assigneeIds.length === 0
      ? Promise.resolve([])
      : owners.users.getAppIdentities(tx, assigneeIds),
    owners.catalog.getCategories(tx, [
      ...new Set(
        bookings.flatMap((booking) =>
          booking.primaryCategoryId ? [booking.primaryCategoryId] : [],
        ),
      ),
    ]),
  ]);
  const firstNames = new Map(
    identities.map((user) => [
      user.id,
      firstNameOf(applicationDisplayName(user)),
    ]),
  );
  const categoryNames = new Map(
    categories.map((category) => [category.id, category.nameAr]),
  );

  const assigneeOf = (task: (typeof tasks)[number]): PlanReadAssignee | null => {
    const userId = task.assigneeUserId;
    if (userId === readerUserId) return { kind: "YOU", firstName: null };
    if (userId) {
      return {
        kind: userId === ownerUserId ? "OWNER" : "MEMBER",
        firstName: firstNames.get(userId) ?? null,
      };
    }
    const person = task.responsibleName?.trim();
    return person ? { kind: "PERSON", firstName: person } : null;
  };

  const count = (status: GuestAttendanceStatus) =>
    guests.filter((guest) => guest.attendanceStatus === status).length;

  return {
    weddingPlanId,
    tasks: {
      total: tasks.length,
      done: tasks.filter((task) => task.status === WeddingTaskStatus.DONE)
        .length,
      items: tasks.map((task) => ({
        id: task.id,
        title: task.title,
        status: task.status,
        dueDate: task.dueDate,
        assignee: assigneeOf(task),
      })),
    },
    guests: {
      total: guests.length,
      confirmed: count(GuestAttendanceStatus.CONFIRMED),
      pending: count(GuestAttendanceStatus.PENDING),
      declined: count(GuestAttendanceStatus.DECLINED),
      items: guests.map((guest) => ({
        id: guest.id,
        name: guest.name,
        attendanceStatus: guest.attendanceStatus,
      })),
    },
    bookings: {
      items: bookings.map((booking) => ({
        id: booking.id,
        businessName: booking.businessName,
        categoryName: booking.primaryCategoryId
          ? (categoryNames.get(booking.primaryCategoryId) ?? null)
          : null,
        serviceTitle: booking.serviceTitle,
        status: booking.status,
        eventDate: booking.eventDate,
      })),
    },
  };
}
