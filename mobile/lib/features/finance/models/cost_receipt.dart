/// A receipt photo kept with a cost (V1 checklist 4.4). [downloadUrl] is a
/// signed URL valid for about two minutes: the list is reloaded to view
/// receipts again later, and nothing is cached on the device.
class CostReceipt {
  const CostReceipt({
    required this.id,
    required this.weddingCostId,
    required this.downloadUrl,
    required this.createdAt,
    this.costPaymentId,
  });

  factory CostReceipt.fromJson(Map<String, dynamic> json) {
    return CostReceipt(
      id: json['id'].toString(),
      weddingCostId: json['weddingCostId']?.toString() ?? '',
      costPaymentId: json['costPaymentId']?.toString(),
      downloadUrl: json['downloadUrl']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String weddingCostId;
  final String? costPaymentId;
  final String downloadUrl;
  final DateTime createdAt;
}

/// Server codes for receipts, as Arabic actions.
String? costReceiptErrorMessage(String? code) => switch (code) {
  'COST_RECEIPT_LIMIT' =>
    'الاتفاق وصل حدّه، 10 إيصالات. ينحذف إيصال قديم قبل ما ينضاف جديد.',
  'COST_HAS_RECEIPTS' =>
    'الاتفاق عليه إيصالات، فما ينحذف قبل ما تنحذف إيصالاته.',
  _ => null,
};
