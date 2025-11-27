import 'package:flutter/material.dart';

class InsightCard extends StatelessWidget {
  const InsightCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    this.icon,
    this.gradient,
  });

  final String title;
  final String value;
  final String? subtitle;
  final IconData? icon;
  final List<Color>? gradient;

  @override
  Widget build(BuildContext context) {
    final colors = gradient ??
        [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primary.withOpacity(0.7),
        ];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withOpacity(0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white.withOpacity(0.2),
              child: Icon(icon, color: Colors.white),
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

