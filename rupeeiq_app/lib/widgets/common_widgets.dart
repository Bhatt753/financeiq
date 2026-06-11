import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;
  final Color? bgColor;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.icon,
    this.iconColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: iconColor ?? AppColors.textSub),
                const SizedBox(width: 5),
              ],
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: AppColors.textSub,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AdviceCard extends StatelessWidget {
  final Map<String, dynamic> advice;
  const AdviceCard({super.key, required this.advice});

  @override
  Widget build(BuildContext context) {
    final type = advice['type'] as String? ?? 'info';
    final icon = advice['icon'] as String? ?? '💡';
    final title = advice['title'] as String? ?? '';
    final message = advice['message'] as String? ?? '';
    final action = advice['action'] as String? ?? '';

    Color bg, borderColor, titleColor;
    switch (type) {
      case 'success':
        bg = AppColors.greenBadgeBg;
        borderColor = AppColors.borderGreen;
        titleColor = AppColors.greenDark;
        break;
      case 'danger':
        bg = AppColors.redBg;
        borderColor = AppColors.redBorder;
        titleColor = AppColors.redText;
        break;
      case 'warning':
        bg = AppColors.amberBg;
        borderColor = AppColors.amberBorder;
        titleColor = AppColors.amberText;
        break;
      default:
        bg = AppColors.indigoBg;
        borderColor = AppColors.indigoBorder;
        titleColor = AppColors.indigoDark;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ],
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(message,
                style: const TextStyle(
                    color: AppColors.textMid, fontSize: 12, height: 1.5)),
          ],
          if (action.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text('→ $action',
                style: TextStyle(
                    color: titleColor,
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }
}

class DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const DifficultyBadge({super.key, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    Color bg, textColor;
    switch (difficulty.toUpperCase()) {
      case 'ACHIEVED':
        bg = AppColors.greenBadgeBg;
        textColor = AppColors.greenDark;
        break;
      case 'EASY':
        bg = AppColors.surfaceGreen;
        textColor = AppColors.green;
        break;
      case 'MEDIUM':
        bg = AppColors.amberBadgeBg;
        textColor = AppColors.amberText;
        break;
      default:
        bg = AppColors.redBg;
        textColor = AppColors.redText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        difficulty.toUpperCase(),
        style: TextStyle(
            color: textColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: AppColors.green,
        strokeWidth: 2.5,
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.redBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline,
                  color: AppColors.red, size: 32),
            ),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSub, fontSize: 14, height: 1.5)),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: onRetry, child: const Text('Try Again')),
            ]
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSub,
                    fontSize: 14,
                    height: 1.6)),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow(
      {super.key,
      required this.label,
      required this.value,
      this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSub, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// Indian comma format: 1,00,000 / 10,000 / 1,23,456
String formatCurrency(dynamic amount) {
  if (amount == null) return '₹0';
  final d = double.tryParse(amount.toString()) ?? 0.0;
  final isNeg = d < 0;
  final intPart = d.abs().toInt().toString();
  String formatted;
  if (intPart.length <= 3) {
    formatted = intPart;
  } else {
    final last3 = intPart.substring(intPart.length - 3);
    final rest = intPart.substring(0, intPart.length - 3);
    final parts = <String>[];
    for (var i = rest.length; i > 0; i -= 2) {
      parts.add(rest.substring(i > 2 ? i - 2 : 0, i));
    }
    formatted = '${parts.reversed.join(',')},${last3}';
  }
  return '${isNeg ? '-' : ''}₹$formatted';
}

// ── Shimmer loading ────────────────────────────────────────────────────────

class ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutSine));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFFECECEC),
              Color(0xFFF5F5F5),
              Color(0xFFECECEC),
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerLoadingView extends StatelessWidget {
  const ShimmerLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        ShimmerBox(height: 120, borderRadius: BorderRadius.circular(16)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: ShimmerBox(height: 82)),
          const SizedBox(width: 10),
          Expanded(child: ShimmerBox(height: 82)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ShimmerBox(height: 82)),
          const SizedBox(width: 10),
          Expanded(child: ShimmerBox(height: 82)),
        ]),
        const SizedBox(height: 16),
        ShimmerBox(height: 200, borderRadius: BorderRadius.circular(14)),
        const SizedBox(height: 16),
        ShimmerBox(height: 70, borderRadius: BorderRadius.circular(12)),
        const SizedBox(height: 10),
        ShimmerBox(height: 70, borderRadius: BorderRadius.circular(12)),
        const SizedBox(height: 10),
        ShimmerBox(height: 70, borderRadius: BorderRadius.circular(12)),
      ],
    );
  }
}

// ── Smooth page transition ─────────────────────────────────────────────────

Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );

Route<T> slideUpRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(
            parent: animation, curve: const Cubic(0.32, 0.72, 0, 1))),
        child: child,
      ),
    );

// ── Tap-scale press effect ─────────────────────────────────────────────────

class TapScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const TapScaleWrapper({super.key, required this.child, this.onTap});

  @override
  State<TapScaleWrapper> createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<TapScaleWrapper> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: widget.child,
      ),
    );
  }
}
