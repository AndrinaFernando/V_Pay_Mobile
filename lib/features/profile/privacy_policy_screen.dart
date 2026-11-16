import 'package:flutter/material.dart';

import 'profile_info_page.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileInfoPage(
      title: 'Privacy Policy',
      children: [
        ProfileDraftNotice(
          message: 'Draft requiring review. This information describes the current prototype and requires project approval before publication as a formal policy.',
        ),
        ProfileInfoSection(
          title: 'Account information',
          body:
              'Registration uses your name, email address, and mobile number. '
              'Merchant registration also includes a business name, category, '
              'and address. Firebase Authentication manages sign-in and identity.',
        ),
        ProfileInfoSection(
          title: 'How the app uses data',
          body:
              'The app sends authenticated requests to the VPay backend to '
              'retrieve account and virtual card information, initiate top-ups, '
              'and create merchant payment requests. The profile pages display '
              'the account information returned by the backend.',
        ),
        ProfileInfoSection(
          title: 'Device access',
          body:
              'VPay uses device authentication through the operating system '
              'to control access to the signed-in app.',
        ),
        ProfileInfoSection(
          title: 'Details under review',
          body:
              'Data retention, sharing practices, and procedures for account '
              'changes or deletion require project review. Profile editing and '
              'in-app support are planned for later work.',
        ),
      ],
    );
  }
}
