import 'package:flutter/material.dart';

/// The official VPay logo used by Merchant screens.
class MerchantBrandLogo extends StatelessWidget {
  const MerchantBrandLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/logos/Logo Blue V2.0.png',
      height: height,
      width: height * 2.7,
      fit: BoxFit.contain,
      semanticLabel: 'VPay',
    );
  }
}
