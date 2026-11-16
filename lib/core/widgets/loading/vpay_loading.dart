import 'package:flutter/material.dart';

const _base = Color(0xFFEBEBEB);
const _highlight = Color(0xFFF7F7F7);

/// A restrained, self-disposing shimmer for content that has not arrived yet.
class VPaySkeleton extends StatefulWidget {
  const VPaySkeleton({
    super.key,
    required this.height,
    this.width,
    this.radius = 12,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<VPaySkeleton> createState() => _VPaySkeletonState();
}

class _VPaySkeletonState extends State<VPaySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
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
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        gradient: MediaQuery.disableAnimationsOf(context)
            ? null
            : LinearGradient(
                begin: Alignment(-2 + 4 * _controller.value, 0),
                end: Alignment(0 + 4 * _controller.value, 0),
                colors: const [_base, _highlight, _base],
              ),
        color: MediaQuery.disableAnimationsOf(context) ? _base : null,
      ),
    ),
  );
}

class VPayCardSkeleton extends StatelessWidget {
  const VPayCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const Column(
    key: Key('cardSkeleton'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      VPaySkeleton(height: 104, radius: 20),
      SizedBox(height: 20),
      VPaySkeleton(height: 200, radius: 20),
    ],
  );
}

class VPayProfileSkeleton extends StatelessWidget {
  const VPayProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    key: const Key('profileLoading'),
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
    children: const [
      Center(child: VPaySkeleton(width: 80, height: 80, radius: 40)),
      SizedBox(height: 16),
      Center(child: VPaySkeleton(width: 160, height: 22)),
      SizedBox(height: 10),
      Center(child: VPaySkeleton(width: 220, height: 14)),
      SizedBox(height: 46),
      VPaySkeleton(height: 176, radius: 16),
      SizedBox(height: 24),
      VPaySkeleton(height: 72, radius: 16),
      SizedBox(height: 24),
      VPaySkeleton(height: 176, radius: 16),
    ],
  );
}

class VPayListSkeleton extends StatelessWidget {
  const VPayListSkeleton({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) => ListView.separated(
    key: const Key('listSkeleton'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
    itemCount: count,
    separatorBuilder: (_, _) => const SizedBox(height: 12),
    itemBuilder: (_, _) => const VPaySkeleton(height: 72, radius: 12),
  );
}

class VPayProcessingIndicator extends StatelessWidget {
  const VPayProcessingIndicator({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    child: const LinearProgressIndicator(
      minHeight: 3,
      color: Color(0xFF0072DC),
      backgroundColor: _highlight,
    ),
  );
}
