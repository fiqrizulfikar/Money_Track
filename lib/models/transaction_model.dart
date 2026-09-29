class TransactionModel {
  int? id;
  String? userId;
  String title;
  double amount;
  String category;
  DateTime date;
  bool isExpense;
  String? note;

  TransactionModel({
    this.id,
    this.userId,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.isExpense,
    this.note,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'is_expense': isExpense,
      'note': note,
    };
    if (id != null) map['id'] = id;
    if (userId != null) map['user_id'] = userId;
    return map;
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'],
      userId: map['user_id'],
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      category: map['category'] ?? '',
      date: map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
      isExpense: map['is_expense'] ?? false,
      note: map['note'],
    );
  }
}
