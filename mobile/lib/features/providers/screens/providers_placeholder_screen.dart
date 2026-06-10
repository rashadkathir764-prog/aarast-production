import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class ProvidersPlaceholderScreen extends StatelessWidget {
  const ProvidersPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.dBg,
      appBar: AppBar(
        title: const Text('الموردين'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Placeholder
              Container(
                decoration: AppTheme.premiumCardDecoration(radius: AppTheme.radiusMd),
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: 'ابحث عن صالة، مصورة، كوشة...',
                    hintStyle: textTheme.bodyMedium?.copyWith(color: AppTheme.dMuted),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.dGold),
                    filled: true,
                    fillColor: AppTheme.dCard2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Categories Placeholder
              Text(
                'التصنيفات',
                style: textTheme.titleMedium?.copyWith(
                  color: AppTheme.dMaroon,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.right,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  reverse: true, // RTL
                  children: [
                    _CategoryCard(icon: Icons.storefront, label: 'قاعات'),
                    _CategoryCard(icon: Icons.camera_alt_outlined, label: 'تصوير'),
                    _CategoryCard(icon: Icons.chair_alt_outlined, label: 'كوشة'),
                    _CategoryCard(icon: Icons.music_note_outlined, label: 'زفات'),
                    _CategoryCard(icon: Icons.restaurant_menu, label: 'ضيافة'),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Coming Soon Message
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.premiumCardDecoration(),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.dGold.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.construction_rounded,
                        color: AppTheme.dGoldDeep,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'سوق الموردين قريباً',
                      style: textTheme.titleLarge?.copyWith(
                        color: AppTheme.dMaroon,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نعمل على إضافة أفضل مزودي خدمات الزفاف (قاعات، تصوير، كوشات والمزيد) لتتمكن من حجزهم مباشرة من التطبيق.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppTheme.dInkSoft,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(left: 12),
      decoration: AppTheme.premiumCardDecoration(radius: AppTheme.radiusMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppTheme.dMaroon, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dInk,
                ),
          ),
        ],
      ),
    );
  }
}
