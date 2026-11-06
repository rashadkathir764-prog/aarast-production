// Prints the demo groom's ids for the route sweep, as key=value pairs.
const { PrismaClient } = require('../../backend/node_modules/@prisma/client');
const prisma = new PrismaClient();

(async () => {
  const user = await prisma.user.findFirstOrThrow({
    where: { phone: { endsWith: '777000101' } },
  });
  const plan = await prisma.weddingPlan.findFirstOrThrow({
    where: { ownerUserId: user.id },
  });
  const planWhere = { weddingPlanId: plan.id };
  const category = await prisma.budgetCategory.findFirstOrThrow({ where: planWhere });
  const cost = await prisma.weddingCost.findFirstOrThrow({ where: planWhere });
  const schedule = await prisma.paymentSchedule.findFirstOrThrow({
    where: { weddingCost: { weddingPlanId: plan.id } },
  });
  const payment = await prisma.costPayment.findFirstOrThrow({
    where: { weddingCost: { weddingPlanId: plan.id } },
  });
  const task = await prisma.weddingTask.findFirstOrThrow({ where: planWhere });
  const guest = await prisma.guest.findFirstOrThrow({ where: planWhere });
  const member = await prisma.sharedMember.findFirstOrThrow({ where: planWhere });
  const quote = await prisma.quoteRequest.findFirstOrThrow({ where: planWhere });
  const booked = await prisma.booking.findFirstOrThrow({
    where: { quoteRequest: planWhere },
  });
  const ids = {
    planId: plan.id,
    categoryId: category.id,
    costId: cost.id,
    scheduleId: schedule.id,
    paymentId: payment.id,
    taskId: task.id,
    guestId: guest.id,
    memberId: member.id,
    quoteId: quote.id,
    bookedQuoteId: booked.quoteRequestId,
    providerId: quote.providerId,
    conversationId: quote.conversationId,
  };
  console.log(Object.entries(ids).map(([key, value]) => `${key}=${value}`).join(','));
  await prisma.$disconnect();
})().catch((error) => {
  console.error(error.message.slice(0, 300));
  process.exit(1);
});
