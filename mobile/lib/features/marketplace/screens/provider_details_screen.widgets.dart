part of 'provider_details_screen.dart';

Future<void> _shareProvider(
  BuildContext context,
  MarketplaceProvider provider,
) async {
  final city = provider.city?.nameAr.trim();
  final snippet = city == null || city.isEmpty
      ? provider.businessName
      : '${provider.businessName} — $city';
  await Clipboard.setData(ClipboardData(text: snippet));
  if (!context.mounted) return;
  AarastToast.showSuccess(context, 'تم نسخ بيانات المورد للمشاركة');
}

class _ContactIconButton extends StatelessWidget {
  const _ContactIconButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'المحادثات',
      child: SizedBox(
        width: 54,
        height: 54,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            foregroundColor: AppTheme.burgundy,
            backgroundColor: AppTheme.surface,
            side: const BorderSide(color: AppTheme.border),
            shape: const CircleBorder(),
          ),
          child: const Icon(LucideIcons.messageCircle, size: 22),
        ),
      ),
    );
  }
}

class _DetailsFrame extends StatelessWidget {
  const _DetailsFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: IconButton(
            tooltip: 'رجوع',
            onPressed: () {
              if (context.canPop()) context.pop();
            },
            icon: const Icon(LucideIcons.chevronRight),
          ),
        ),
        const SizedBox(height: 80),
        child,
      ],
    );
  }
}
