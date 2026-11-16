import 'package:flutter/material.dart';

import 'profile_info_page.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileInfoPage(
      title: 'Terms & Conditions',
      children: [
        ProfileDraftNotice(
          message: 'Draft for information. Formal terms require project review and approval.',
        ),
        ProfileInfoSection(
          title: 'Using the prototype',
          body:
              'VPay is being developed for university payment scenarios involving '
              'customers and merchants. Features and service availability may '
              'change during development.',
        ),
        ProfileInfoSection(
          title: 'Your account',
          body:
              'Use accurate contact and business details when registering. Keep '
              'your sign-in credentials private and log out on shared devices.',
        ),
        ProfileInfoSection(
          title: 'Payments during development',
          body:
              'Follow the project team’s instructions for demonstrations and '
              'testing. Approved conditions for top-ups, payments, and any '
              'financial responsibilities still require project review.',
        ),
      ],
    );
  }
}
