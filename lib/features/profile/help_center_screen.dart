import 'package:flutter/material.dart';

import 'profile_info_page.dart';
import 'vpay_colors.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileInfoPage(
      title: 'Help Center',
      children: [
        SizedBox(height: 40),
        CircleAvatar(
          radius: 40,
          backgroundColor: VPayColors.surface,
          child: Icon(
            Icons.support_agent_rounded,
            color: VPayColors.electric,
            size: 40,
          ),
        ),
        SizedBox(height: 24),
        Text(
          'Help & Support',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: VPayColors.ink,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Support features are coming soon. We’re preparing help resources, '
          'FAQs, and contact options for a future update.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: VPayColors.secondary,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
