import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MetricCard extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;
  final IconData? icon;
  final Color? iconColor;

  const MetricCard({
    super.key,
    required this.value,
    required this.label,
    this.valueColor,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, color: iconColor ?? AppColors.textSub, size: 18),
            const SizedBox(height: 10),
          ],
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSub, fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final String label;
  final Color? color;
  final Color? bg;

  const InfoChip({super.key, required this.label, this.color, this.bg});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg ?? c.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(
        child: CircularProgressIndicator(color: AppColors.green, strokeWidth: 2),
      );
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.red, size: 48),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSub, fontSize: 14)),
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      );
}

class EmptyView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onAction;
  final String? actionLabel;

  const EmptyView({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.green.withOpacity(0.2)),
                ),
                child: Icon(icon, color: AppColors.green, size: 32),
              ),
              const SizedBox(height: 20),
              Text(title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSub, fontSize: 13)),
              ],
              if (onAction != null) ...[
                const SizedBox(height: 24),
                ElevatedButton(onPressed: onAction, child: Text(actionLabel ?? 'Get Started')),
              ],
            ],
          ),
        ),
      );
}
