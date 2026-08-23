import "reflect-metadata";

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from "@nestjs/common";
import {
  PaymentScheduleStatus,
  Prisma,
  PrismaClient,
  ProviderStatus,
  SharedMemberRole,
  WeddingCostStatus,
  WeddingPlanStatus,
} from "@prisma/client";
import ts from "typescript";
import { BudgetCategoriesService } from "../../src/budget-categories/budget-categories.service";
import { ContributionHistoryService } from "../../src/modules/collaboration/internal/contribution-history.service";
import { ContributorScopeService } from "../../src/modules/collaboration/internal/contributor-scope.service";
import { MoneyBudgetService } from "../../src/money/money-budget.service";
import { WeddingPlanBudgetWriter } from "../../src/modules/planning/internal/wedding-plan-budget-writer";
import { PermissionService } from "../../src/sharing/permission.service";
import { WeddingCostsService } from "../../src/wedding-costs/wedding-costs.service";

const { assertManagedSmokeEnvironment } = require("./smoke-utils.js") as {
  assertManagedSmokeEnvironment: (
    environment: NodeJS.ProcessEnv,
  ) => { runId: string };
};
const { createPermissionRevocationFixture, withFixture } =
  require("../../test/support/phase0-postgres-support.js") as {
    createPermissionRevocationFixture: (
      prisma: unknown,
      environment?: NodeJS.ProcessEnv,
    ) => Promise<any>;
    withFixture: (
      createFixture: (environment: NodeJS.ProcessEnv) => Promise<any>,
      callback: (fixture: any) => Promise<void>,
      environment?: NodeJS.ProcessEnv,
    ) => Promise<void>;
  };

assertManagedSmokeEnvironment(process.env);

const prisma = new PrismaClient();
const permissions = new PermissionService(prisma as any);
const contributionHistory = new ContributionHistoryService(prisma as any);
const contributorScope = new ContributorScopeService(contributionHistory);
const weddingCosts = new WeddingCostsService(
  prisma as any,
  permissions,
  contributorScope,
  contributionHistory,
);
const budgetCategories = new BudgetCategoriesService(
  prisma as any,
  permissions,
  contributorScope,
  contributionHistory,
);
const moneyBudget = new MoneyBudgetService(
  prisma as any,
  permissions,
  new WeddingPlanBudgetWriter(),
);

interface ControllerMutation {
  file: string;
  controller: string;
  handler: string;
  receiver: string;
  service: string;
  serviceClass: string;
  serviceFile: string;
  gate: string;
}

const controllerMutations: ControllerMutation[] = [
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "WeddingPlanCostsController",
    handler: "create",
    receiver: "service",
    service: "createCost",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "CostsController",
    handler: "update",
    receiver: "service",
    service: "updateCost",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "CostsController",
    handler: "remove",
    receiver: "service",
    service: "deleteCost",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "CostsController",
    handler: "cancel",
    receiver: "service",
    service: "cancelCost",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "CostsController",
    handler: "createPayment",
    receiver: "service",
    service: "createPayment",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "CostsController",
    handler: "createSchedule",
    receiver: "service",
    service: "createSchedule",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "CostPaymentsController",
    handler: "reverse",
    receiver: "service",
    service: "reversePayment",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "PaymentSchedulesController",
    handler: "update",
    receiver: "service",
    service: "updateSchedule",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "PaymentSchedulesController",
    handler: "remove",
    receiver: "service",
    service: "deleteSchedule",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "PaymentSchedulesController",
    handler: "cancel",
    receiver: "service",
    service: "cancelSchedule",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/wedding-costs/wedding-costs.controller.ts",
    controller: "PaymentSchedulesController",
    handler: "pay",
    receiver: "service",
    service: "paySchedule",
    serviceClass: "WeddingCostsService",
    serviceFile: "src/wedding-costs/wedding-costs.service.ts",
    gate: "assertMoneyManageableInTransaction",
  },
  {
    file: "src/budget-categories/budget-categories.controller.ts",
    controller: "WeddingPlanBudgetCategoriesController",
    handler: "create",
    receiver: "budgetCategoriesService",
    service: "create",
    serviceClass: "BudgetCategoriesService",
    serviceFile: "src/budget-categories/budget-categories.service.ts",
    gate: "assertMoneyManageableForUpdateInTransaction",
  },
  {
    file: "src/budget-categories/budget-categories.controller.ts",
    controller: "BudgetCategoriesController",
    handler: "update",
    receiver: "budgetCategoriesService",
    service: "update",
    serviceClass: "BudgetCategoriesService",
    serviceFile: "src/budget-categories/budget-categories.service.ts",
    gate: "assertMoneyManageableForUpdateInTransaction",
  },
  {
    file: "src/budget-categories/budget-categories.controller.ts",
    controller: "BudgetCategoriesController",
    handler: "remove",
    receiver: "budgetCategoriesService",
    service: "remove",
    serviceClass: "BudgetCategoriesService",
    serviceFile: "src/budget-categories/budget-categories.service.ts",
    gate: "assertMoneyManageableForUpdateInTransaction",
  },
  {
    file: "src/money/money-summary.controller.ts",
    controller: "MoneySummaryController",
    handler: "replaceMoneyBudget",
    receiver: "moneyBudgetService",
    service: "replace",
    serviceClass: "MoneyBudgetService",
    serviceFile: "src/money/money-budget.service.ts",
    gate: "assertMoneyManageableForUpdateInTransaction",
  },
];

const backendRoot = resolve(__dirname, "../..");

function parseSource(relativePath: string): ts.SourceFile {
  const path = join(backendRoot, relativePath);
  return ts.createSourceFile(
    path,
    readFileSync(path, "utf8"),
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
}

function nodeName(node: ts.NamedDeclaration): string | null {
  return node.name && ts.isIdentifier(node.name) ? node.name.text : null;
}

function visitCalls(
  node: ts.Node,
  callback: (call: ts.CallExpression) => void,
): void {
  if (ts.isCallExpression(node)) callback(node);
  ts.forEachChild(node, (child) => visitCalls(child, callback));
}

function writeDecoratorNames(method: ts.MethodDeclaration): string[] {
  const decorators = ts.canHaveDecorators(method)
    ? (ts.getDecorators(method) ?? [])
    : [];
  return decorators.flatMap((decorator) => {
    const expression = ts.isCallExpression(decorator.expression)
      ? decorator.expression.expression
      : decorator.expression;
    return ts.isIdentifier(expression) ? [expression.text] : [];
  });
}

function thisServiceCall(
  call: ts.CallExpression,
): { receiver: string; service: string } | null {
  if (!ts.isPropertyAccessExpression(call.expression)) return null;
  const receiver = call.expression.expression;
  if (
    !ts.isPropertyAccessExpression(receiver) ||
    receiver.expression.kind !== ts.SyntaxKind.ThisKeyword
  ) {
    return null;
  }
  return {
    receiver: receiver.name.text,
    service: call.expression.name.text,
  };
}

function findClass(
  source: ts.SourceFile,
  className: string,
): ts.ClassDeclaration {
  const found = source.statements.find(
    (statement): statement is ts.ClassDeclaration =>
      ts.isClassDeclaration(statement) && nodeName(statement) === className,
  );
  assert.ok(found, `source guard: class ${className} must exist`);
  return found;
}

function findMethod(
  classNode: ts.ClassDeclaration,
  methodName: string,
): ts.MethodDeclaration {
  const found = classNode.members.find(
    (member): member is ts.MethodDeclaration =>
      ts.isMethodDeclaration(member) && nodeName(member) === methodName,
  );
  assert.ok(
    found?.body,
    `source guard: ${nodeName(classNode)}.${methodName} must have a body`,
  );
  return found;
}

function assertControllerAndTransactionalGateMap(): void {
  assert.equal(
    controllerMutations.length,
    15,
    "source guard must cover exactly 15 financial controller mutations",
  );

  const expectedHandlers = controllerMutations
    .map((item) => `${item.file}:${item.controller}.${item.handler}`)
    .sort();
  const actualHandlers: string[] = [];
  const parsedControllers = new Map<string, ts.SourceFile>();

  for (const file of new Set(controllerMutations.map((item) => item.file))) {
    const source = parseSource(file);
    parsedControllers.set(file, source);
    for (const statement of source.statements) {
      if (!ts.isClassDeclaration(statement) || !nodeName(statement)) continue;
      for (const member of statement.members) {
        if (!ts.isMethodDeclaration(member) || !nodeName(member)) continue;
        if (
          writeDecoratorNames(member).some((name) =>
            ["Post", "Put", "Patch", "Delete"].includes(name),
          )
        ) {
          actualHandlers.push(
            `${file}:${nodeName(statement)}.${nodeName(member)}`,
          );
        }
      }
    }
  }
  assert.deepEqual(
    actualHandlers.sort(),
    expectedHandlers,
    "source guard: the exact financial controller write surface changed",
  );

  const knownMutationMethods = new Set(
    controllerMutations.map((item) => item.service),
  );
  for (const mapping of controllerMutations) {
    const source = parsedControllers.get(mapping.file)!;
    const handler = findMethod(
      findClass(source, mapping.controller),
      mapping.handler,
    );
    const mutationCalls: string[] = [];
    visitCalls(handler.body!, (call) => {
      const target = thisServiceCall(call);
      if (target && knownMutationMethods.has(target.service)) {
        mutationCalls.push(`${target.receiver}.${target.service}`);
      }
    });
    assert.deepEqual(
      mutationCalls,
      [`${mapping.receiver}.${mapping.service}`],
      `source guard: ${mapping.controller}.${mapping.handler} must map exactly to ${mapping.receiver}.${mapping.service}`,
    );
  }

  const uniqueServiceMethods = new Map<
    string,
    Pick<
      ControllerMutation,
      "serviceFile" | "serviceClass" | "service" | "gate"
    >
  >();
  for (const mapping of controllerMutations) {
    uniqueServiceMethods.set(
      `${mapping.serviceFile}:${mapping.serviceClass}.${mapping.service}`,
      mapping,
    );
  }
  assert.equal(
    uniqueServiceMethods.size,
    15,
    "source guard must cover 15 distinct service mutations",
  );

  const parsedServices = new Map<string, ts.SourceFile>();
  for (const mapping of uniqueServiceMethods.values()) {
    const source =
      parsedServices.get(mapping.serviceFile) ??
      parseSource(mapping.serviceFile);
    parsedServices.set(mapping.serviceFile, source);
    const method = findMethod(
      findClass(source, mapping.serviceClass),
      mapping.service,
    );
    const serializableCalls: ts.CallExpression[] = [];
    visitCalls(method.body!, (call) => {
      if (
        ts.isIdentifier(call.expression) &&
        call.expression.text === "runSerializableTransaction"
      ) {
        serializableCalls.push(call);
      }
    });
    assert.equal(
      serializableCalls.length,
      1,
      `source guard: ${mapping.serviceClass}.${mapping.service} must use one serializable transaction`,
    );
    const transactionCallback = serializableCalls[0]!.arguments.find(
      (argument): argument is ts.ArrowFunction | ts.FunctionExpression =>
        ts.isArrowFunction(argument) || ts.isFunctionExpression(argument),
    );
    assert.ok(
      transactionCallback,
      `source guard: ${mapping.serviceClass}.${mapping.service} must use an inline transaction callback`,
    );
    const txParameter = transactionCallback.parameters[0]?.name;
    assert.ok(
      txParameter && ts.isIdentifier(txParameter),
      `source guard: ${mapping.serviceClass}.${mapping.service} transaction callback must name its client`,
    );
    const gateCalls: ts.CallExpression[] = [];
    visitCalls(transactionCallback.body, (call) => {
      if (
        ts.isPropertyAccessExpression(call.expression) &&
        call.expression.name.text === mapping.gate &&
        call.arguments[0] &&
        ts.isIdentifier(call.arguments[0]) &&
        call.arguments[0].text === txParameter.text
      ) {
        gateCalls.push(call);
      }
    });
    assert.equal(
      gateCalls.length,
      1,
      `source guard: ${mapping.serviceClass}.${mapping.service} must authorize through ${mapping.gate}(tx, ...) inside its transaction callback`,
    );
    if (
      mapping.serviceClass === "MoneyBudgetService" &&
      mapping.service === "replace"
    ) {
      const summaryCalls: ts.CallExpression[] = [];
      visitCalls(transactionCallback.body, (call) => {
        if (
          ts.isIdentifier(call.expression) &&
          call.expression.text === "buildMoneySummaryInTransaction" &&
          call.arguments[0] &&
          ts.isIdentifier(call.arguments[0]) &&
          call.arguments[0].text === txParameter.text
        ) {
          summaryCalls.push(call);
        }
      });
      assert.equal(
        summaryCalls.length,
        1,
        "source guard: MoneyBudgetService.replace must build its response summary inside the same serializable transaction",
      );
    }
  }

  const moneyController = findClass(
    parsedControllers.get("src/money/money-summary.controller.ts")!,
    "MoneySummaryController",
  );
  const replaceHandler = findMethod(moneyController, "replaceMoneyBudget");
  const postCommitSummaryReads: ts.CallExpression[] = [];
  visitCalls(replaceHandler.body!, (call) => {
    const target = thisServiceCall(call);
    if (
      target?.receiver === "moneySummaryService" &&
      target.service === "getSummary"
    ) {
      postCommitSummaryReads.push(call);
    }
  });
  assert.equal(
    postCommitSummaryReads.length,
    0,
    "source guard: money-budget PUT must not perform a post-commit summary read",
  );

  const summarySource = parseSource("src/money/money-summary.service.ts");
  const getSummary = findMethod(
    findClass(summarySource, "MoneySummaryService"),
    "getSummary",
  );
  const summaryTransactions: ts.CallExpression[] = [];
  visitCalls(getSummary.body!, (call) => {
    if (
      ts.isIdentifier(call.expression) &&
      call.expression.text === "runRetryableTransaction"
    ) {
      summaryTransactions.push(call);
    }
  });
  assert.equal(
    summaryTransactions.length,
    1,
    "source guard: money summary GET must use one repeatable-read transaction",
  );
  const summaryCallback = summaryTransactions[0]!.arguments.find(
    (argument): argument is ts.ArrowFunction | ts.FunctionExpression =>
      ts.isArrowFunction(argument) || ts.isFunctionExpression(argument),
  );
  assert.ok(
    summaryCallback,
    "source guard: money summary transaction callback must be inline",
  );
  const summaryTx = summaryCallback.parameters[0]?.name;
  assert.ok(
    summaryTx && ts.isIdentifier(summaryTx),
    "source guard: money summary transaction callback must name its client",
  );
  const summaryGateCalls: ts.CallExpression[] = [];
  const summaryBuilderCalls: ts.CallExpression[] = [];
  visitCalls(summaryCallback.body, (call) => {
    if (
      ts.isPropertyAccessExpression(call.expression) &&
      call.expression.name.text === "assertMoneyReadableInTransaction" &&
      call.arguments[0] &&
      ts.isIdentifier(call.arguments[0]) &&
      call.arguments[0].text === summaryTx.text
    ) {
      summaryGateCalls.push(call);
    }
    if (
      ts.isIdentifier(call.expression) &&
      call.expression.text === "buildMoneySummaryInTransaction" &&
      call.arguments[0] &&
      ts.isIdentifier(call.arguments[0]) &&
      call.arguments[0].text === summaryTx.text
    ) {
      summaryBuilderCalls.push(call);
    }
  });
  assert.equal(
    summaryGateCalls.length,
    1,
    "source guard: money summary permission must be checked inside its read transaction",
  );
  assert.equal(
    summaryBuilderCalls.length,
    1,
    "source guard: money summary data must be read inside the authorized transaction",
  );
}

function authenticatedUser(user: {
  id: string;
  name: string;
  phone: string | null;
}) {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
  } as any;
}

function deferred(): { promise: Promise<void>; resolve: () => void } {
  let resolve!: () => void;
  const promise = new Promise<void>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

interface HeldMutation {
  commit: () => Promise<void>;
}

async function holdUncommittedMutation(
  mutation: (tx: Prisma.TransactionClient) => Promise<unknown>,
): Promise<HeldMutation> {
  const changed = deferred();
  const commitRequested = deferred();
  let committedOnce = false;
  let changeReached = false;
  const transaction = prisma.$transaction(
    async (tx) => {
      await mutation(tx);
      changeReached = true;
      changed.resolve();
      await commitRequested.promise;
    },
    { timeout: 20_000 },
  );
  await Promise.race([
    changed.promise,
    transaction.then(
      () => {
        if (!changeReached) {
          throw new Error("Held transaction ended before changing its row");
        }
      },
      (error) => Promise.reject(error),
    ),
  ]);
  return {
    commit: async () => {
      if (!committedOnce) {
        committedOnce = true;
        commitRequested.resolve();
      }
      await transaction;
    },
  };
}

async function holdUncommittedMoneyRevocation(
  sharedMemberId: string,
): Promise<HeldMutation> {
  return holdUncommittedMutation((tx) =>
    tx.sharedMember.update({
      where: { id: sharedMemberId },
      data: {
        role: SharedMemberRole.VIEWER,
        canViewMoney: false,
        canManageMoney: false,
      },
    }),
  );
}

async function holdUncommittedMembershipRemoval(
  sharedMemberId: string,
): Promise<HeldMutation> {
  return holdUncommittedMutation(async (tx) => {
    const member = await tx.sharedMember.findUniqueOrThrow({
      where: { id: sharedMemberId },
    });
    await contributionHistory.closeTenureInTransaction(tx, {
      weddingPlanId: member.weddingPlanId,
      actorUserId: member.userId,
      reason: "MEMBER_REMOVED",
      roleAtEnd: member.role,
    });
    await tx.sharedMember.delete({ where: { id: sharedMemberId } });
  });
}

async function holdUncommittedPlanArchive(
  weddingPlanId: string,
): Promise<HeldMutation> {
  return holdUncommittedMutation((tx) =>
    tx.weddingPlan.update({
      where: { id: weddingPlanId },
      data: { status: WeddingPlanStatus.ARCHIVED },
    }),
  );
}

async function holdUncommittedProviderSuspension(
  providerId: string,
): Promise<HeldMutation> {
  return holdUncommittedMutation((tx) =>
    tx.provider.update({
      where: { id: providerId },
      data: { status: ProviderStatus.SUSPENDED },
    }),
  );
}

async function waitForBlockedMutation(
  operation: Promise<unknown>,
  label: string,
): Promise<void> {
  const state = await Promise.race([
    operation.then(
      () => "settled",
      () => "settled",
    ),
    new Promise<"blocked">((resolveBlocked) =>
      setTimeout(() => resolveBlocked("blocked"), 75),
    ),
  ]);
  assert.equal(
    state,
    "blocked",
    `${label} must wait for the uncommitted authority/lifecycle change`,
  );
}

function assertRejectedWith(
  result: PromiseSettledResult<unknown> | undefined,
  expected: typeof NotFoundException | typeof BadRequestException,
  label: string,
): void {
  assert.equal(result?.status, "rejected", `${label} must reject after commit`);
  if (result?.status === "rejected") {
    assert.ok(
      result.reason instanceof expected,
      `${label} must reject with ${expected.name}`,
    );
  }
}

function assertArchivedReadOnly(
  result: PromiseSettledResult<unknown> | undefined,
  label: string,
): void {
  assert.equal(result?.status, "rejected", `${label} must reject after archive`);
  if (result?.status !== "rejected") return;
  assert.ok(
    result.reason instanceof ConflictException,
    `${label} must reject with ConflictException`,
  );
  const response = (
    result.reason as { getResponse?: () => unknown }
  ).getResponse?.();
  assert.equal(
    typeof response === "object" && response !== null
      ? (response as { code?: unknown }).code
      : undefined,
    "PLAN_ARCHIVED_READ_ONLY",
    `${label} must expose the archived-plan lifecycle code`,
  );
}

async function createFinanceGraph(fixture: any) {
  await prisma.sharedMember.update({
    where: { id: fixture.sharedMember.id },
    data: {
      canViewMoney: true,
      canManageMoney: true,
    },
  });
  const user = authenticatedUser(fixture.member);
  const category = await budgetCategories.create(user, fixture.plan.id, {
    name: `Concurrency category ${fixture.scope}`,
  });
  const cost = await weddingCosts.createCost(user, fixture.plan.id, {
    budgetCategoryId: category.id,
    providerId: fixture.provider.id,
    title: `Concurrency cost ${fixture.scope}`,
    totalAmount: "1000",
    note: "unchanged cost note",
  });
  const schedule = await prisma.paymentSchedule.create({
    data: {
      weddingCostId: cost.id,
      amount: new Prisma.Decimal(100),
      dueDate: new Date(Date.now() + 14 * 24 * 60 * 60 * 1_000),
      status: PaymentScheduleStatus.PENDING,
      note: "unchanged schedule note",
    },
  });
  return { category, cost, schedule };
}

async function withPermissionFixture(
  callback: (fixture: any, graph: Awaited<ReturnType<typeof createFinanceGraph>>) => Promise<void>,
): Promise<void> {
  await withFixture(
    (environment) => createPermissionRevocationFixture(prisma, environment),
    async (fixture) => callback(fixture, await createFinanceGraph(fixture)),
  );
}

async function assertRevocationWinsBeforeCreatePayment(): Promise<void> {
  await withPermissionFixture(async (fixture, graph) => {
    const held = await holdUncommittedMoneyRevocation(fixture.sharedMember.id);
    const operation = weddingCosts.createPayment(
      authenticatedUser(fixture.member),
      graph.cost.id,
      { amount: "125", note: "must not be recorded" },
    );
    try {
      await waitForBlockedMutation(operation, "revoke vs createPayment");
      await held.commit();
      const [result] = await Promise.allSettled([operation]);
      assertRejectedWith(
        result,
        NotFoundException,
        "revoke vs createPayment",
      );
      assert.equal(
        await prisma.costPayment.count({
          where: { weddingCostId: graph.cost.id },
        }),
        0,
        "revoked createPayment must not append a ledger row",
      );
      const stored = await prisma.weddingCost.findUniqueOrThrow({
        where: { id: graph.cost.id },
      });
      assert.equal(stored.paidAmount.toString(), "0");
      assert.equal(stored.status, WeddingCostStatus.OPEN);
    } finally {
      await held.commit();
      await Promise.allSettled([operation]);
    }
  });
}

async function assertMembershipRemovalWinsBeforeScheduleUpdate(): Promise<void> {
  await withPermissionFixture(async (fixture, graph) => {
    const held = await holdUncommittedMembershipRemoval(
      fixture.sharedMember.id,
    );
    const operation = weddingCosts.updateSchedule(
      authenticatedUser(fixture.member),
      graph.schedule.id,
      {
        amount: "175",
        note: "must not replace the schedule",
      },
    );
    try {
      await waitForBlockedMutation(operation, "member delete vs updateSchedule");
      await held.commit();
      const [result] = await Promise.allSettled([operation]);
      assertRejectedWith(
        result,
        NotFoundException,
        "member delete vs updateSchedule",
      );
      const stored = await prisma.paymentSchedule.findUniqueOrThrow({
        where: { id: graph.schedule.id },
      });
      assert.equal(stored.amount.toString(), "100");
      assert.equal(stored.note, "unchanged schedule note");
      assert.equal(stored.status, PaymentScheduleStatus.PENDING);
    } finally {
      await held.commit();
      await Promise.allSettled([operation]);
    }
  });
}

async function assertArchiveWinsBeforeBudgetReplace(): Promise<void> {
  await withPermissionFixture(async (fixture, graph) => {
    const held = await holdUncommittedPlanArchive(fixture.plan.id);
    const operation = moneyBudget.replace(
      authenticatedUser(fixture.member),
      fixture.plan.id,
      {
        totalBudget: "2500",
        currency: fixture.plan.currency,
        categories: [
          {
            id: graph.category.id,
            name: "Must not replace category",
            allocatedAmount: "500",
          },
        ],
      },
    );
    try {
      await waitForBlockedMutation(operation, "archive vs MoneyBudget.replace");
      await held.commit();
      const [result] = await Promise.allSettled([operation]);
      assertArchivedReadOnly(result, "archive vs MoneyBudget.replace");
      const storedPlan = await prisma.weddingPlan.findUniqueOrThrow({
        where: { id: fixture.plan.id },
      });
      assert.equal(storedPlan.status, WeddingPlanStatus.ARCHIVED);
      assert.equal(
        storedPlan.estimatedBudget?.toString() ?? null,
        fixture.plan.estimatedBudget?.toString() ?? null,
        "archived budget replace must not change estimatedBudget",
      );
      assert.equal(storedPlan.currency, fixture.plan.currency);
      const storedCategory = await prisma.budgetCategory.findUniqueOrThrow({
        where: { id: graph.category.id },
      });
      assert.equal(storedCategory.name, graph.category.name);
      assert.equal(storedCategory.allocatedAmount, null);
    } finally {
      await held.commit();
      await Promise.allSettled([operation]);
    }
  });
}

async function assertArchiveWinsBeforeSchedulePayment(): Promise<void> {
  await withPermissionFixture(async (fixture, graph) => {
    const held = await holdUncommittedPlanArchive(fixture.plan.id);
    const operation = weddingCosts.paySchedule(
      authenticatedUser(fixture.member),
      graph.schedule.id,
      { method: "must-not-be-recorded" },
    );
    try {
      await waitForBlockedMutation(operation, "archive vs paySchedule");
      await held.commit();
      const [result] = await Promise.allSettled([operation]);
      assertArchivedReadOnly(result, "archive vs paySchedule");
      assert.equal(
        await prisma.costPayment.count({
          where: { weddingCostId: graph.cost.id },
        }),
        0,
        "archived paySchedule must not append a ledger row",
      );
      const storedCost = await prisma.weddingCost.findUniqueOrThrow({
        where: { id: graph.cost.id },
      });
      assert.equal(storedCost.paidAmount.toString(), "0");
      assert.equal(storedCost.status, WeddingCostStatus.OPEN);
      const storedSchedule = await prisma.paymentSchedule.findUniqueOrThrow({
        where: { id: graph.schedule.id },
      });
      assert.equal(storedSchedule.status, PaymentScheduleStatus.PENDING);
      assert.equal(storedSchedule.paidAt, null);
    } finally {
      await held.commit();
      await Promise.allSettled([operation]);
    }
  });
}

async function assertProviderSuspensionWinsBeforeCostCreate(): Promise<void> {
  await withPermissionFixture(async (fixture, graph) => {
    const held = await holdUncommittedProviderSuspension(fixture.provider.id);
    const blockedTitle = `Must not create ${fixture.scope}`;
    const operation = weddingCosts.createCost(
      authenticatedUser(fixture.member),
      fixture.plan.id,
      {
        budgetCategoryId: graph.category.id,
        providerId: fixture.provider.id,
        title: blockedTitle,
        totalAmount: "900",
      },
    );
    try {
      await waitForBlockedMutation(operation, "provider suspend vs createCost");
      await held.commit();
      const [result] = await Promise.allSettled([operation]);
      assertRejectedWith(
        result,
        BadRequestException,
        "provider suspend vs createCost",
      );
      assert.equal(
        await prisma.weddingCost.count({
          where: { weddingPlanId: fixture.plan.id },
        }),
        1,
        "provider suspension must prevent an additional cost",
      );
      assert.equal(
        await prisma.weddingCost.count({ where: { title: blockedTitle } }),
        0,
      );
    } finally {
      await held.commit();
      await Promise.allSettled([operation]);
    }
  });
}

async function assertProviderSuspensionWinsBeforeCostUpdate(): Promise<void> {
  await withPermissionFixture(async (fixture, graph) => {
    const held = await holdUncommittedProviderSuspension(fixture.provider.id);
    const operation = weddingCosts.updateCost(
      authenticatedUser(fixture.member),
      graph.cost.id,
      {
        title: "Must not update after provider suspension",
        note: "must not replace the cost note",
      },
    );
    try {
      await waitForBlockedMutation(operation, "provider suspend vs updateCost");
      await held.commit();
      const [result] = await Promise.allSettled([operation]);
      assertRejectedWith(
        result,
        BadRequestException,
        "provider suspend vs updateCost",
      );
      const stored = await prisma.weddingCost.findUniqueOrThrow({
        where: { id: graph.cost.id },
      });
      assert.equal(stored.title, graph.cost.title);
      assert.equal(stored.note, "unchanged cost note");
      assert.equal(stored.totalAmount.toString(), "1000");
    } finally {
      await held.commit();
      await Promise.allSettled([operation]);
    }
  });
}

async function main(): Promise<void> {
  try {
    assertControllerAndTransactionalGateMap();
    await assertRevocationWinsBeforeCreatePayment();
    await assertMembershipRemovalWinsBeforeScheduleUpdate();
    await assertArchiveWinsBeforeBudgetReplace();
    await assertArchiveWinsBeforeSchedulePayment();
    await assertProviderSuspensionWinsBeforeCostCreate();
    await assertProviderSuspensionWinsBeforeCostUpdate();
    console.log(
      "PASS - Phase 2 financial authorization/lifecycle changes serialize before all 15 financial write handlers, and representative races reject without writes.",
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
