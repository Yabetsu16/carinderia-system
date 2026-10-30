class CreateOrderItem {
  final int menuItemId;
  final int quantity;
  final String? specialInstruction;

  CreateOrderItem({
    required this.menuItemId,
    required this.quantity,
    this.specialInstruction,
  });

  Map<String, dynamic> toJson() {
    return {
      'menuItemId': menuItemId,
      'quantity': quantity,
      'specialInstruction': specialInstruction ?? '',
    };
  }
}
