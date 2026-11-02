enum ReturnStatus { inReview, refunded, rejected }

class ReturnRequest {
  const ReturnRequest({
    required this.id,
    required this.orderId,
    required this.productName,
    required this.requestedDate,
    required this.refundAmount,
    required this.status,
    this.reason,
  });

  final String id;
  final String orderId;
  final String productName;
  final String requestedDate;
  final double refundAmount;
  final ReturnStatus status;
  final String? reason;

  factory ReturnRequest.fromJson(Map<String, dynamic> json) {
    final statusStr = '${json['status'] ?? 'inReview'}';
    final status = switch (statusStr.toLowerCase()) {
      'refunded' => ReturnStatus.refunded,
      'rejected' => ReturnStatus.rejected,
      _ => ReturnStatus.inReview,
    };
    return ReturnRequest(
      id: '${json['id'] ?? ''}',
      orderId: '${json['orderId'] ?? json['order_id'] ?? ''}',
      productName: '${json['productName'] ?? json['product_name'] ?? ''}',
      requestedDate:
          '${json['requestedDate'] ?? json['requested_date'] ?? ''}',
      refundAmount: (json['refundAmount'] as num?)?.toDouble() ?? 0,
      status: status,
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderId': orderId,
        'productName': productName,
        'requestedDate': requestedDate,
        'refundAmount': refundAmount,
        'status': status.name,
        'reason': reason,
      };
}
