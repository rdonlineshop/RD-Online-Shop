import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/product_data.dart';
import 'data/wishlist_data.dart';
import 'firebase_options.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final FirebaseAuth auth = FirebaseAuth.instance;

  if (auth.currentUser?.isAnonymous != true) {
    await auth.signOut();
    await auth.signInAnonymously();
  }

  await Future.wait(<Future<void>>[
    loadWishlist(),
    loadProducts(),
  ]);

  runApp(
    const RDOnlineShop(),
  );
}

class RDOnlineShop extends StatelessWidget {
  const RDOnlineShop({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RD Online Shop',
      home: const HomePage(),
    );
  }
}
