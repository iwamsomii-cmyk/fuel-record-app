class FuelRecord {
  final String id;
  final String pumpName;

  // Manually chosen by the user when starting the record (not auto-captured).
  final DateTime preparedByDate;

  final double openingMeterReading; // mandatory, entered at record start
  final double? closingMeterReading; // filled in later, at submit time
  final double? openingBalance;     // optional
  final double? closingBalance;     // optional

  // Footer block, filled after all receipt items are added. This is the
  // single "Prepared By" signature for the whole record.
  final double? totalQuantitySold;
  final String? totalPreparedByName;
  final String? totalPreparedBySignature;
  final DateTime? totalPreparedByDate;
  final DateTime? timeClosed;

  final bool submitted; // false = still a local/offline draft, true = uploaded via SUBMIT
  final DateTime createdAt;

  FuelRecord({
    required this.id,
    required this.pumpName,
    required this.preparedByDate,
    required this.openingMeterReading,
    this.closingMeterReading,
    this.openingBalance,
    this.closingBalance,
    this.totalQuantitySold,
    this.totalPreparedByName,
    this.totalPreparedBySignature,
    this.totalPreparedByDate,
    this.timeClosed,
    this.submitted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'pumpName': pumpName,
        'preparedByDate': preparedByDate.toIso8601String(),
        'openingMeterReading': openingMeterReading,
        'closingMeterReading': closingMeterReading,
        'openingBalance': openingBalance,
        'closingBalance': closingBalance,
        'totalQuantitySold': totalQuantitySold,
        'totalPreparedByName': totalPreparedByName,
        'totalPreparedBySignature': totalPreparedBySignature,
        'totalPreparedByDate': totalPreparedByDate?.toIso8601String(),
        'timeClosed': timeClosed?.toIso8601String(),
        'submitted': submitted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory FuelRecord.fromMap(String id, Map<String, dynamic> map) {
    return FuelRecord(
      id: id,
      pumpName: map['pumpName'] ?? '',
      preparedByDate:
          DateTime.tryParse(map['preparedByDate'] ?? '') ?? DateTime.now(),
      openingMeterReading: (map['openingMeterReading'] ?? 0).toDouble(),
      closingMeterReading: map['closingMeterReading']?.toDouble(),
      openingBalance: map['openingBalance']?.toDouble(),
      closingBalance: map['closingBalance']?.toDouble(),
      totalQuantitySold: map['totalQuantitySold']?.toDouble(),
      totalPreparedByName: map['totalPreparedByName'],
      totalPreparedBySignature: map['totalPreparedBySignature'],
      totalPreparedByDate: map['totalPreparedByDate'] != null
          ? DateTime.tryParse(map['totalPreparedByDate'])
          : null,
      timeClosed: map['timeClosed'] != null
          ? DateTime.tryParse(map['timeClosed'])
          : null,
      submitted: map['submitted'] ?? false,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  FuelRecord copyWith({
    double? closingMeterReading,
    double? totalQuantitySold,
    String? totalPreparedByName,
    String? totalPreparedBySignature,
    DateTime? totalPreparedByDate,
    DateTime? timeClosed,
    bool? submitted,
  }) {
    return FuelRecord(
      id: id,
      pumpName: pumpName,
      preparedByDate: preparedByDate,
      openingMeterReading: openingMeterReading,
      closingMeterReading: closingMeterReading ?? this.closingMeterReading,
      openingBalance: openingBalance,
      closingBalance: closingBalance,
      totalQuantitySold: totalQuantitySold ?? this.totalQuantitySold,
      totalPreparedByName: totalPreparedByName ?? this.totalPreparedByName,
      totalPreparedBySignature:
          totalPreparedBySignature ?? this.totalPreparedBySignature,
      totalPreparedByDate: totalPreparedByDate ?? this.totalPreparedByDate,
      timeClosed: timeClosed ?? this.timeClosed,
      submitted: submitted ?? this.submitted,
      createdAt: createdAt,
    );
  }
}
