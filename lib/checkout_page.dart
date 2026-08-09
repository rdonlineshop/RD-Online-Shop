import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'order_data.dart';
import 'order_history_page.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() =>
      _CheckoutPageState();
}

class _CheckoutPageState
    extends State<CheckoutPage> {

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController phoneController =
      TextEditingController();

  String deliveryAddress =
      "3230, Al-Manakh, Riyadh, Riyadh Province, Saudi Arabia";

  String selectedPayment =
      "Cash on Delivery";

  bool isLoadingLocation = false;

  final double totalAmount = 1100;

  // ==========================================
  // CURRENT LOCATION
  // ==========================================

  Future<void> _getCurrentLocation() async {
    setState(() {
      isLoadingLocation = true;
    });

    try {
      bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                "Please turn on GPS / Location.",
              ),
            ),
          );
        }

        setState(() {
          isLoadingLocation = false;
        });

        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                "Location permission denied.",
              ),
            ),
          );
        }

        setState(() {
          isLoadingLocation = false;
        });

        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(
            const SnackBar(
              content: Text(
                "Location permission permanently denied.",
              ),
            ),
          );
        }

        setState(() {
          isLoadingLocation = false;
        });

        return;
      }

      Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      List<Placemark> placemarks =
          await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place =
            placemarks.first;

        String address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country,
        ]
            .where(
              (e) =>
                  e != null && e.isNotEmpty,
            )
            .join(", ");

        setState(() {
          deliveryAddress = address;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content:
                Text("Location error: $e"),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        isLoadingLocation = false;
      });
    }
  }

  // ==========================================
  // PLACE ORDER
  // ==========================================

  Future<void> _placeOrder() async {
    if (nameController.text
            .trim()
            .isEmpty ||
        phoneController.text
            .trim()
            .isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            "Please enter your name and mobile number.",
          ),
        ),
      );

      return;
    }

    // CREATE UNIQUE ORDER ID
    final String orderId =
        "RD${DateTime.now().millisecondsSinceEpoch}";

    // SAVE ORDER PERMANENTLY
    await addOrder({
      "id": orderId,
      "name":
          nameController.text.trim(),
      "phone":
          phoneController.text.trim(),
      "address": deliveryAddress,
      "payment": selectedPayment,
      "amount":
          totalAmount.toStringAsFixed(0),
      "status": "Pending",
    });

    // SUCCESS MESSAGE
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            "Order Placed 🎉",
          ),

          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                "Your order has been placed successfully.",
              ),

              const SizedBox(height: 12),

              Text(
                "Order ID: $orderId",
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 16,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Amount: Rs. ${totalAmount.toStringAsFixed(0)}",
              ),

              const SizedBox(height: 5),

              Text(
                "Payment: $selectedPayment",
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const OrderHistoryPage(),
                  ),
                );
              },

              child: const Text(
                "View Order",
              ),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // DISPOSE
  // ==========================================

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();

    super.dispose();
  }

  // ==========================================
  // BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Checkout",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding:
            const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,

          children: [

            // CUSTOMER INFORMATION
            const Text(
              "Customer Information",
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller:
                  nameController,

              decoration:
                  InputDecoration(
                labelText:
                    "Full Name",

                prefixIcon:
                    const Icon(
                  Icons.person,
                ),

                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller:
                  phoneController,

              keyboardType:
                  TextInputType.phone,

              decoration:
                  InputDecoration(
                labelText:
                    "Mobile Number",

                prefixIcon:
                    const Icon(
                  Icons.phone,
                ),

                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 25),

            // DELIVERY ADDRESS
            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,

              children: [
                const Text(
                  "Delivery Address",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                TextButton.icon(
                  onPressed:
                      isLoadingLocation
                          ? null
                          : _getCurrentLocation,

                  icon: isLoadingLocation
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.my_location,
                        ),

                  label: const Text(
                    "Use Current Location",
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Container(
              width: double.infinity,

              padding:
                  const EdgeInsets.all(
                16,
              ),

              decoration:
                  BoxDecoration(
                border: Border.all(
                  color:
                      Colors.grey.shade300,
                ),

                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),

              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.red,
                  ),

                  const SizedBox(
                    width: 10,
                  ),

                  Expanded(
                    child: Text(
                      deliveryAddress,

                      style:
                          const TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // PAYMENT
            const Text(
              "Payment Method",
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            _paymentOption(
              "Cash on Delivery",
              Icons.money,
            ),

            _paymentOption(
              "eSewa",
              Icons.account_balance_wallet,
            ),

            _paymentOption(
              "Khalti",
              Icons.wallet,
            ),

            _paymentOption(
              "Bank / eBanking",
              Icons.account_balance,
            ),

            _paymentOption(
              "Mobile Banking",
              Icons.phone_android,
            ),

            _paymentOption(
              "Debit / Credit Card",
              Icons.credit_card,
            ),

            _paymentOption(
              "connectIPS",
              Icons.payment,
            ),

            const SizedBox(height: 20),

            const Divider(),

            const SizedBox(height: 10),

            // TOTAL
            Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceBetween,

              children: [
                const Text(
                  "Total Amount",
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                Text(
                  "Rs. ${totalAmount.toStringAsFixed(0)}",

                  style:
                      const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // PLACE ORDER
            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton(
                onPressed:
                    _placeOrder,

                style:
                    ElevatedButton.styleFrom(
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),

                child: const Text(
                  "Place Order",

                  style:
                      TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // PAYMENT OPTION
  // ==========================================

  Widget _paymentOption(
    String title,
    IconData icon,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),

      child:
          RadioListTile<String>(
        value: title,

        groupValue:
            selectedPayment,

        onChanged: (value) {
          setState(() {
            selectedPayment =
                value!;
          });
        },

        title: Text(
          title,

          style:
              const TextStyle(
            fontWeight:
                FontWeight.w500,
          ),
        ),

        secondary:
            Icon(icon),
      ),
    );
  }
}