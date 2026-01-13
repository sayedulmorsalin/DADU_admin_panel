class Order {
  final String address;
  final String customsFacts;
  final String customsItems;
  final String district;
  final List<OrderItem> items;
  final String paymentTribe;
  final String paymentRref;
  final String phone;
  final String android;
  final String theme;
  final String timestamp;
  final double total;

  Order({
    required this.address,
    required this.customsFacts,
    required this.customsItems,
    required this.district,
    required this.items,
    required this.paymentTribe,
    required this.paymentRref,
    required this.phone,
    required this.android,
    required this.theme,
    required this.timestamp,
    required this.total,
  });
}

class OrderItem {
  final String id;
  final String imageUrl;
  final String name;
  final double price;
  final int quantity;

  OrderItem({
    required this.id,
    required this.imageUrl,
    required this.name,
    required this.price,
    required this.quantity,
  });
}