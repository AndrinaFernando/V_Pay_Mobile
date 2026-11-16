import 'package:flutter/material.dart';

class CustomerActivityNotice extends StatelessWidget {
  const CustomerActivityNotice({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('customerActivityIncompleteNotice'),
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    color: const Color(0xFFFFF7ED),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: Color(0xFF9A5500), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF794400), fontSize: 13),
          ),
        ),
      ],
    ),
  );
}
