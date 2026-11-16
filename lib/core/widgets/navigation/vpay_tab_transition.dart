import 'package:flutter/material.dart';

/// A short entrance effect that leaves the supplied tab subtree mounted.
class VPayTabTransition extends StatelessWidget {
  const VPayTabTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curved = animation.drive(CurveTween(curve: Curves.easeInOut));
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.012, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
