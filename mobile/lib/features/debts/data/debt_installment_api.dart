import '../../../core/network/api_client.dart';
import '../models/debt.dart';
import '../models/debt_summary.dart';
import '../models/installment.dart';

class DebtInstallmentApi {
  const DebtInstallmentApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Debt>> getDebts(String weddingPlanId) async {
    final list = await _apiClient.getJsonList(
      '/wedding-plans/$weddingPlanId/debts',
    );
    return list
        .whereType<Map>()
        .map((item) => Debt.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<DebtSummary> getDebtSummary(String weddingPlanId) async {
    final json = await _apiClient.getJson(
      '/wedding-plans/$weddingPlanId/debts/summary',
    );
    return DebtSummary.fromJson(json);
  }

  Future<Debt> createDebt({
    required String weddingPlanId,
    required String creditorName,
    required String title,
    required String totalAmount,
    String? paidAmount,
    DateTime? dueDate,
    String status = 'OPEN',
    String? note,
  }) async {
    final json = await _apiClient
        .postJson('/wedding-plans/$weddingPlanId/debts', {
          'creditorName': creditorName.trim(),
          'title': title.trim(),
          'totalAmount': totalAmount.trim(),
          'status': status,
          if (paidAmount != null && paidAmount.trim().isNotEmpty)
            'paidAmount': paidAmount.trim(),
          if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        });
    return Debt.fromJson(json);
  }

  Future<Debt> updateDebt(String id, Map<String, dynamic> data) async {
    final json = await _apiClient.patchJson('/debts/$id', data);
    return Debt.fromJson(json);
  }

  Future<void> deleteDebt(String id) async {
    await _apiClient.deleteJson('/debts/$id');
  }

  Future<List<Installment>> getInstallments(String debtId) async {
    final list = await _apiClient.getJsonList('/debts/$debtId/installments');
    return list
        .whereType<Map>()
        .map((item) => Installment.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<Installment>> getDueInstallments(String weddingPlanId) async {
    final list = await _apiClient.getJsonList(
      '/wedding-plans/$weddingPlanId/installments/due',
    );
    return list
        .whereType<Map>()
        .map((item) => Installment.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Installment> createInstallment({
    required String debtId,
    required String amount,
    DateTime? dueDate,
    DateTime? paidAt,
    String status = 'PENDING',
    String? note,
  }) async {
    final json = await _apiClient.postJson('/debts/$debtId/installments', {
      'amount': amount.trim(),
      'status': status,
      if (dueDate != null) 'dueDate': dueDate.toIso8601String(),
      if (paidAt != null) 'paidAt': paidAt.toIso8601String(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
    return Installment.fromJson(json);
  }

  Future<Installment> updateInstallment(
    String id,
    Map<String, dynamic> data,
  ) async {
    final json = await _apiClient.patchJson('/installments/$id', data);
    return Installment.fromJson(json);
  }

  Future<void> deleteInstallment(String id) async {
    await _apiClient.deleteJson('/installments/$id');
  }
}
