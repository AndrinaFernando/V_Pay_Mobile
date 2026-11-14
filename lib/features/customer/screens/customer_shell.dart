import 'package:flutter/material.dart';

import '../../auth/auth_service.dart';
import '../../auth/models/vpay_user_profile.dart';
import '../../customer_payment/screens/customer_payment_preview_screen.dart';
import '../../customer_payment/screens/customer_qr_scanner_screen.dart';
import '../../customer_payment/services/customer_payment_preview_service.dart';
import 'customer_home_screen.dart';

const _electric = Color(0xFF0072DC);
const _ink = Color(0xFF222222);
const _secondary = Color(0xFF767676);

class CustomerShell extends StatefulWidget {
  const CustomerShell({
    super.key,
    required this.profile,
    required this.authService,
    this.qrScannerBuilder,
    this.paymentPreviewService,
  });

  final VPayUserProfile profile;
  final AuthService authService;
  final CustomerQrScannerViewBuilder? qrScannerBuilder;
  final CustomerPaymentPreviewService? paymentPreviewService;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  late final Widget _home;
  int _selectedIndex = 0;
  bool _isSigningOut = false;

  @override
  void initState() {
    super.initState();
    _home = CustomerHomeScreen(
      profile: widget.profile,
      onScanAndPay: _openQrScanner,
    );
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);

    try {
      await widget.authService.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to sign out. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  Future<void> _openQrScanner() async {
    final paymentReference = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            CustomerQrScannerScreen(scannerBuilder: widget.qrScannerBuilder),
      ),
    );

    if (!mounted || paymentReference == null) return;

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => CustomerPaymentPreviewScreen(
          paymentReference: paymentReference,
          previewService: widget.paymentPreviewService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _home,
            _ScanAndPayTab(onScan: _openQrScanner),
            const _ComingSoonTab(
              icon: Icons.receipt_long_outlined,
              title: 'Activity',
            ),
            _ComingSoonTab(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              footer: TextButton(
                onPressed: _isSigningOut ? null : _signOut,
                child: Text(_isSigningOut ? 'Signing out…' : 'Sign Out'),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFEBEBEB))),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
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

class _ScanAndPayTab extends StatelessWidget {
  const _ScanAndPayTab({required this.onScan});

  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F3FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: _electric,
                  size: 38,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Scan & Pay',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Scan a VPay merchant QR code to begin a payment. The payment details will be verified before you confirm anything.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _secondary, fontSize: 15, height: 1.45),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('scanMerchantQrButton'),
                  onPressed: onScan,
                  style: FilledButton.styleFrom(
                    backgroundColor: _electric,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: const Text(
                    'Scan Merchant QR',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.icon, required this.title, this.footer});

  final IconData icon;
  final String title;
  final Widget? footer;

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
            if (footer != null) ...[const SizedBox(height: 20), footer!],
          ],
        ),
      ),
    );
  }
}
