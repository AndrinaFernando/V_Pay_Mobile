import 'package:flutter/material.dart';

import 'profile_info_page.dart';

class AboutVPayScreen extends StatelessWidget {
  const AboutVPayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileInfoPage(
      title: 'About VPay',
      children: [
        Center(
          child: Image.asset(
            'assets/branding/logos/Long Logo Light Mode.png',
            width: 160,
            height: 96,
            fit: BoxFit.contain,
            semanticLabel: 'VPay',
          ),
        ),
        const SizedBox(height: 24),
        const ProfileInfoSection(
          title: 'What is VPay?',
          body:
              'VPay is a university mobile payment application being developed '
              'to connect customers and campus merchants through digital payments.',
        ),
        const ProfileInfoSection(
          title: 'The payment experience',
          body:
              'The prototype includes virtual card information, account top-ups, '
              'and merchant payment requests with QR codes. Customer QR-based '
              'payments are being integrated and may be unavailable in this build.',
        ),
        const ProfileInfoSection(
          title: 'Project status',
          body:
              'VPay is a university project under active development. Feature '
              'availability depends on the current build and connected services.',
        ),
      ],
    );
  }
}
