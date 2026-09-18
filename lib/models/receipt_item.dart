class ReceiptItem {
  final String id;
  final String pe;          // Issuing officer / department code, per the paper book's "PE" column
  final String driver;
  final String token;
  final String chassisNo;
  final double qty;
  final String signature;   // captured as text/initials for now; can be swapped for a signature-pad image later
  final String contract;
  final DateTime createdAt;

  ReceiptItem({
    required this.id,
    required this.pe,
    required this.driver,
    required this.token,
    required this.chassisNo,
    required this.qty,
    required this.signature,
    required this.contract,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'pe': pe,
        'driver': driver,
        'token': token,
        'chassisNo': chassisNo,
        'qty': qty,
        'signature': signature,
        'contract': contract,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReceiptItem.fromMap(String id, Map<String, dynamic> map) {
    return ReceiptItem(
      id: id,
      pe: map['pe'] ?? '',
      driver: map['driver'] ?? '',
      token: map['token'] ?? '',
      chassisNo: map['chassisNo'] ?? '',
      qty: (map['qty'] ?? 0).toDouble(),
      signature: map['signature'] ?? '',
      contract: map['contract'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }
}
