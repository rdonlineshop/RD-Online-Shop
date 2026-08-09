List<Map<String, dynamic>> cartItems = [];

List<Map<String, dynamic>> orders = [];

int getTotalPrice() {
  int total = 0;

  for (var item in cartItems) {
    String price = item["price"]
        .toString()
        .replaceAll("Rs.", "")
        .replaceAll("Rs", "")
        .replaceAll(",", "")
        .trim();

    int quantity = item["quantity"] ?? 1;

    int itemPrice = int.tryParse(price) ?? 0;

    total += itemPrice * quantity;
  }

  return total;
}