import 'package:flutter/material.dart';
import 'home_page.dart';

void main() {
  runApp(const RDOnlineShop());
}

class RDOnlineShop extends StatelessWidget {
  const RDOnlineShop({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RD Online Shop',
      home: const HomePage(),
    );
  }
}