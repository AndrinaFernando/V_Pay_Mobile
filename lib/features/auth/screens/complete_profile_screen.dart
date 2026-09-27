import 'package:flutter/material.dart';

class CompleteProfileScreen extends StatelessWidget {
  const CompleteProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'VPay',
                    style: TextStyle(
                      color: Color(0xFF0072DC),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      border: Border.all(color: const Color(0xFFEBEBEB)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 32,
                      color: Color(0xFF01397C),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Complete your VPay profile',
                    style: TextStyle(
                      color: Color(0xFF222222),
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your email is verified. Your VPay profile still needs to be set up before you can use your account.',
                    style: TextStyle(
                      color: Color(0xFF484848),
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      border: Border.all(color: const Color(0xFFEBEBEB)),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Profile setup will be available in the next step.',
                      style: TextStyle(
                        color: Color(0xFF767676),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
