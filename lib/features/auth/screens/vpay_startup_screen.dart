import 'package:flutter/material.dart';

const _blue = Color(0xFF0072DC);
const _logo = 'assets/branding/logos/Long Logo Light Mode.png';

/// Shows Flutter UI immediately while the caller initializes app services.
class VPayStartupGate extends StatefulWidget {
  const VPayStartupGate({
    super.key,
    required this.initialize,
    required this.child,
  });

  final Future<void> Function() initialize;
  final Widget child;

  @override
  State<VPayStartupGate> createState() => _VPayStartupGateState();
}

class _VPayStartupGateState extends State<VPayStartupGate> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = Future.sync(widget.initialize);
  }

  void _retry() {
    setState(() {
      _initialization = Future.sync(widget.initialize);
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const VPayStartupScreen();
      }
      if (snapshot.hasError) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(_logo, width: 220, semanticLabel: 'VPay'),
                    const Text(
                      'VPay could not start. Check your connection and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      style: FilledButton.styleFrom(backgroundColor: _blue),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return widget.child;
    },
  );
}

class VPayStartupScreen extends StatefulWidget {
  const VPayStartupScreen({super.key});

  @override
  State<VPayStartupScreen> createState() => _VPayStartupScreenState();
}

class _VPayStartupScreenState extends State<VPayStartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: Semantics(
          label: 'Starting VPay',
          child: SizedBox(
            width: 280,
            height: 280,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final phase = _controller.value;
                return Stack(
                  children: [
                    Image.asset(
                      _logo,
                      key: const Key('startupLogo'),
                      width: 280,
                      height: 280,
                      fit: BoxFit.contain,
                      semanticLabel: 'VPay logo',
                    ),
                    if (!MediaQuery.disableAnimationsOf(context) &&
                        phase < 1 / 6)
                      ShaderMask(
                        key: const Key('startupSweep'),
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) {
                          final x = -1.5 + phase * 18;
                          return LinearGradient(
                            begin: Alignment(x - 0.5, 0),
                            end: Alignment(x + 0.5, 0),
                            colors: const [
                              Colors.transparent,
                              Color(0x66FFFFFF),
                              Colors.transparent,
                            ],
                          ).createShader(bounds);
                        },
                        child: Image.asset(
                          _logo,
                          width: 280,
                          height: 280,
                          fit: BoxFit.contain,
                          excludeFromSemantics: true,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
