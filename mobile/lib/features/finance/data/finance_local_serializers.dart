import '../models/wedding_cost.dart';

Map<String, dynamic> weddingCostToLocalJson(WeddingCost cost) => {
  'id': cost.id,
  'weddingPlanId': cost.weddingPlanId,
  'budgetCategoryId': cost.budgetCategoryId,
  'title': cost.title,
  'totalAmount': cost.totalAmount,
  'paidAmount': cost.paidAmount,
  'remainingAmount': cost.remainingAmount,
  'status': cost.status,
  if (cost.providerId != null) 'providerId': cost.providerId,
  if (cost.quoteOfferId != null) 'quoteOfferId': cost.quoteOfferId,
  if (cost.partyName != null) 'partyName': cost.partyName,
  if (cost.partyPhone != null) 'partyPhone': cost.partyPhone,
  if (cost.payer != null) 'payer': cost.payer,
  if (cost.payerName != null) 'payerName': cost.payerName,
  if (cost.note != null) 'note': cost.note,
  if (cost.agreementDate != null)
    'agreementDate': cost.agreementDate!.toIso8601String(),
  if (cost.paymentsCount != null) 'paymentsCount': cost.paymentsCount,
  if (cost.createdAt != null) 'createdAt': cost.createdAt!.toIso8601String(),
  if (cost.updatedAt != null) 'updatedAt': cost.updatedAt!.toIso8601String(),
};

Map<String, dynamic> costPaymentToLocalJson(CostPayment payment) => {
  'id': payment.id,
  'costId': payment.costId,
  'amount': payment.amount,
  'paidAt': payment.paidAt.toIso8601String(),
  'entryType': payment.entryType,
  if (payment.paymentScheduleId != null)
    'paymentScheduleId': payment.paymentScheduleId,
  if (payment.reversalOfId != null) 'reversalOfId': payment.reversalOfId,
  if (payment.reversedById != null) 'reversedById': payment.reversedById,
  'reversible': payment.reversible,
  if (payment.method != null) 'method': payment.method,
  if (payment.note != null) 'note': payment.note,
  if (payment.weddingPlanId != null) 'weddingPlanId': payment.weddingPlanId,
  if (payment.createdAt != null)
    'createdAt': payment.createdAt!.toIso8601String(),
};

Map<String, dynamic> paymentScheduleToLocalJson(PaymentSchedule schedule) => {
  'id': schedule.id,
  'costId': schedule.costId,
  'amount': schedule.amount,
  if (schedule.amountDue != null) 'amountDue': schedule.amountDue,
  'dueDate': schedule.dueDate.toIso8601String(),
  'status': schedule.status,
  if (schedule.paidAt != null) 'paidAt': schedule.paidAt!.toIso8601String(),
  if (schedule.note != null) 'note': schedule.note,
  if (schedule.weddingPlanId != null) 'weddingPlanId': schedule.weddingPlanId,
  if (schedule.createdAt != null)
    'createdAt': schedule.createdAt!.toIso8601String(),
  if (schedule.updatedAt != null)
    'updatedAt': schedule.updatedAt!.toIso8601String(),
};
