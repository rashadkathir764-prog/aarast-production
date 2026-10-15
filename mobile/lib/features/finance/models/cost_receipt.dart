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
    'وصلت التكلفة إلى الحد (10 إيصالات). احذف إيصالًا قديمًا أولًا.',
  'COST_HAS_RECEIPTS' => 'لهذه التكلفة إيصالات. احذفها أولًا ثم احذف التكلفة.',
  _ => null,
};
