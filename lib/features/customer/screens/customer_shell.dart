import 'package:flutter/material.dart';

import '../../../core/widgets/navigation/vpay_tab_transition.dart';
import '../../auth/auth_service.dart';
import '../../auth/models/vpay_user_profile.dart';
import '../../auth/services/user_api_service.dart';
import '../../profile/profile_screen.dart';
import 'customer_home_screen.dart';

const _electric = Color(0xFF0072DC);
const _ink = Color(0xFF222222);
const _secondary = Color(0xFF767676);

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    super.key,
    required this.profile,
    required this.authService,
    this.userApiService,
  });

  final VPayUserProfile profile;
  final AuthService authService;
  final UserApiService? userApiService;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell>
    with SingleTickerProviderStateMixin {
  late VPayUserProfile _profile;
  int _selectedIndex = 0;
  late final AnimationController _tabAnimation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  void _onProfileUpdated(VPayUserProfile profile) {
    setState(() => _profile = profile);
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
    if (MediaQuery.disableAnimationsOf(context)) return;
    _tabAnimation.forward(from: 0);
  }

  @override
  void dispose() {
    _tabAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: VPayTabTransition(
          animation: _tabAnimation,
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              CustomerHomeScreen(profile: _profile),
              const _ComingSoonTab(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scan & Pay',
              ),
              const _ComingSoonTab(
                icon: Icons.receipt_long_outlined,
                title: 'Activity',
              ),
              ProfileScreen(
                profile: _profile,
                authService: widget.authService,
                userApiService: widget.userApiService,
                onProfileUpdated: _onProfileUpdated,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEBEBEB))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _selectTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: _electric,
          unselectedItemColor: _secondary,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_scanner_rounded),
              label: 'Scan & Pay',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Activity',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: _electric),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: _ink,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Coming soon',
              style: TextStyle(color: _secondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
