import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../catalogs/catalogs_api.dart'
    show ManagedReferenceCatalog, ManagedReferenceCatalogItem;

enum MoneyStarterPersona { groom, bride, neutral }

MoneyStarterPersona moneyStarterPersonaFromCode(String? value) {
  return switch (value?.trim().toUpperCase()) {
    'GROOM' => MoneyStarterPersona.groom,
    'BRIDE' => MoneyStarterPersona.bride,
    _ => MoneyStarterPersona.neutral,
  };
}

class MoneyStarterCategory {
  const MoneyStarterCategory({
    required this.id,
    required this.name,
    required this.icon,
    this.recommended = false,
  });

  final String id;
  final String name;
  final IconData icon;
  final bool recommended;
}

class MoneyStarterGroup {
  const MoneyStarterGroup({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.categories,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<MoneyStarterCategory> categories;
}

class MoneyStarterCatalog {
  const MoneyStarterCatalog({
    required this.persona,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.groups,
  });

  final MoneyStarterPersona persona;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<MoneyStarterGroup> groups;

  Iterable<MoneyStarterCategory> get categories =>
      groups.expand((group) => group.categories);

  Set<String> get recommendedIds => {
    for (final category in categories)
      if (category.recommended) category.id,
  };
}

/// Starter rows for the mahr. The mahr sits outside the wedding budget
/// (DECISIONS 2026-10-22, C1), so they are never offered as budget items:
/// a06 records it in its own item (the groom) or as money coming in (the
/// bride).
const mahrStarterIds = {'groom-mahr', 'neutral-mahr'};

MoneyStarterCatalog moneyStarterCatalogFor(MoneyStarterPersona persona) {
  return _withoutMahr(switch (persona) {
    MoneyStarterPersona.groom => _groomCatalog,
    MoneyStarterPersona.bride => _brideCatalog,
    MoneyStarterPersona.neutral => _neutralCatalog,
  });
}

MoneyStarterCatalog _withoutMahr(MoneyStarterCatalog catalog) {
  return MoneyStarterCatalog(
    persona: catalog.persona,
    eyebrow: catalog.eyebrow,
    title: catalog.title,
    subtitle: catalog.subtitle,
    groups: [
      for (final group in catalog.groups)
        if (group.categories.any((c) => !mahrStarterIds.contains(c.id)))
          MoneyStarterGroup(
            id: group.id,
            title: group.title,
            subtitle: group.subtitle,
            categories: [
              for (final c in group.categories)
                if (!mahrStarterIds.contains(c.id)) c,
            ],
          ),
    ],
  );
}

/// The names of the items a new plan starts with: the recommended starter
/// rows for [personaCode], from the managed catalog when loaded.
List<String> moneyStarterPlanItemNames(
  ManagedReferenceCatalog? managed,
  String? personaCode,
) {
  final catalog = moneyStarterCatalogFromManaged(
    managed,
    moneyStarterPersonaFromCode(personaCode),
  );
  return [
    for (final category in catalog.categories)
      if (category.recommended) category.name,
  ];
}

MoneyStarterCatalog moneyStarterCatalogFromManaged(
  ManagedReferenceCatalog? managed,
  MoneyStarterPersona persona,
) {
  final fallback = moneyStarterCatalogFor(persona);
  if (managed == null) return fallback;
  final visible =
      managed.items
          .where((item) {
            if (!item.showForCustomer) return false;
            if (mahrStarterIds.contains(item.key)) return false;
            return switch (persona) {
              MoneyStarterPersona.groom => item.showForGroom,
              MoneyStarterPersona.bride => item.showForBride,
              MoneyStarterPersona.neutral =>
                !item.showForGroom && !item.showForBride,
            };
          })
          .toList(growable: false)
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
  if (visible.isEmpty) return fallback;

  final grouped = <String, List<ManagedReferenceCatalogItem>>{};
  for (final item in visible) {
    grouped.putIfAbsent(item.groupKey ?? 'other', () => []).add(item);
  }
  final groups = grouped.entries
      .map((entry) {
        final first = entry.value.first;
        return MoneyStarterGroup(
          id: entry.key,
          title: first.groupNameAr ?? 'بنود إضافية',
          subtitle: first.groupSubtitleAr ?? 'اختر ما يناسب خطتك.',
          categories: entry.value
              .map(
                (item) => MoneyStarterCategory(
                  id: item.key,
                  name: item.nameAr,
                  icon: _managedMoneyIcon(item.icon),
                  recommended: item.isRecommended,
                ),
              )
              .toList(growable: false),
        );
      })
      .toList(growable: false);

  return MoneyStarterCatalog(
    persona: persona,
    eyebrow: fallback.eyebrow,
    title: fallback.title,
    subtitle: fallback.subtitle,
    groups: groups,
  );
}

IconData _managedMoneyIcon(String? key) {
  return switch (key) {
    'users' => LucideIcons.users,
    'gem' => LucideIcons.gem,
    'file-check' => LucideIcons.fileCheck,
    'building-2' => LucideIcons.building2,
    'utensils' => LucideIcons.utensils,
    'camera' => LucideIcons.camera,
    'speaker' => LucideIcons.speaker,
    'car' => LucideIcons.car,
    'moon-star' => LucideIcons.moonStar,
    'bed-double' => LucideIcons.bedDouble,
    'shirt' => LucideIcons.shirt,
    'scissors' => LucideIcons.scissors,
    'watch' => LucideIcons.watch,
    'shopping-bag' => LucideIcons.shoppingBag,
    'spray-can' => LucideIcons.sprayCan,
    'home' => LucideIcons.home,
    'key-round' => LucideIcons.keyRound,
    'plane' => LucideIcons.plane,
    'mail' => LucideIcons.mail,
    'gift' => LucideIcons.gift,
    'navigation' => LucideIcons.navigation,
    'shield-check' => LucideIcons.shieldCheck,
    'sparkles' => LucideIcons.sparkles,
    'wand-2' => LucideIcons.wand2,
    'flower-2' => LucideIcons.flower2,
    'layout-grid' => LucideIcons.layoutGrid,
    'cake-slice' => LucideIcons.cakeSlice,
    'music-2' => LucideIcons.music2,
    'flower' => LucideIcons.flower,
    'package-open' => LucideIcons.packageOpen,
    'hotel' => LucideIcons.hotel,
    'leaf' => LucideIcons.leaf,
    _ => LucideIcons.circle,
  };
}

const _groomCatalog = MoneyStarterCatalog(
  persona: MoneyStarterPersona.groom,
  eyebrow: 'بداية مرتبة للعريس',
  title: 'جهّز ميزانية عرسك',
  subtitle:
      'اخترنا لك البنود اللي عند أغلب العرسان. خلّ اللي يخصك وشيل الباقي، وما نحط مبالغ ولا اتفاقات إلا لما تأكد.',
  groups: [
    MoneyStarterGroup(
      id: 'groom-agreement',
      title: 'أساسيات الزواج',
      subtitle: 'البنود المرتبطة بالعقد والاتفاقات.',
      categories: [
        MoneyStarterCategory(
          id: 'groom-mahr',
          name: 'المهر والاتفاقات',
          icon: LucideIcons.users,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-gold',
          name: 'الذهب والشبكة',
          icon: LucideIcons.gem,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-contract',
          name: 'العقد والمعاملات',
          icon: LucideIcons.fileCheck,
        ),
        MoneyStarterCategory(
          id: 'groom-kiswa',
          name: 'الكسوة',
          icon: LucideIcons.shirt,
          recommended: true,
        ),
      ],
    ),
    MoneyStarterGroup(
      id: 'groom-event',
      title: 'مناسبة الرجال',
      subtitle: 'المكان والضيافة وكل ما يحدث في يوم المناسبة.',
      categories: [
        MoneyStarterCategory(
          id: 'groom-venue',
          name: 'قاعة أو مخدرة الرجال',
          icon: LucideIcons.building2,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-food',
          name: 'الوليمة والضيافة',
          icon: LucideIcons.utensils,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-photo',
          name: 'التصوير والفيديو',
          icon: LucideIcons.camera,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-audio',
          name: 'الصوت والإضاءة',
          icon: LucideIcons.speaker,
        ),
        MoneyStarterCategory(
          id: 'groom-zaffa',
          name: 'الزفة والسيارة',
          icon: LucideIcons.car,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-evening',
          name: 'جلسة أو سهرة العريس',
          icon: LucideIcons.moonStar,
        ),
        MoneyStarterCategory(
          id: 'groom-guest-stay',
          name: 'إقامة الضيوف',
          icon: LucideIcons.bedDouble,
        ),
        MoneyStarterCategory(
          id: 'groom-qat',
          name: 'القات والمقيل',
          icon: LucideIcons.leaf,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-artist',
          name: 'الفنان والفرقة',
          icon: LucideIcons.music2,
        ),
        MoneyStarterCategory(
          id: 'groom-sacrifice',
          name: 'الذبائح',
          icon: LucideIcons.utensils,
        ),
      ],
    ),
    MoneyStarterGroup(
      id: 'groom-look',
      title: 'تجهيز العريس',
      subtitle: 'الإطلالة والاستعداد الشخصي.',
      categories: [
        MoneyStarterCategory(
          id: 'groom-suit',
          name: 'بدلة العريس',
          icon: LucideIcons.shirt,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-grooming',
          name: 'الحلاقة والعناية',
          icon: LucideIcons.scissors,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-accessories',
          name: 'الأحذية والإكسسوارات',
          icon: LucideIcons.watch,
        ),
        MoneyStarterCategory(
          id: 'groom-clothes',
          name: 'ملابس المناسبات',
          icon: LucideIcons.shoppingBag,
        ),
        MoneyStarterCategory(
          id: 'groom-perfume',
          name: 'العطور والبخور',
          icon: LucideIcons.sprayCan,
        ),
      ],
    ),
    MoneyStarterGroup(
      id: 'groom-life',
      title: 'البيت والبداية الجديدة',
      subtitle: 'ما بعد الحفل والمصاريف المشتركة.',
      categories: [
        MoneyStarterCategory(
          id: 'groom-home',
          name: 'تجهيز المنزل',
          icon: LucideIcons.home,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-housing',
          name: 'السكن والإيجار',
          icon: LucideIcons.keyRound,
        ),
        MoneyStarterCategory(
          id: 'groom-honeymoon',
          name: 'شهر العسل',
          icon: LucideIcons.plane,
          // G12 (R2): honeymoon is one of the six the owner named.
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'groom-invites',
          name: 'الدعوات',
          icon: LucideIcons.mail,
        ),
        MoneyStarterCategory(
          id: 'groom-gifts',
          name: 'الهدايا والتوزيعات',
          icon: LucideIcons.gift,
        ),
        MoneyStarterCategory(
          id: 'groom-transport',
          name: 'المواصلات',
          icon: LucideIcons.navigation,
        ),
        MoneyStarterCategory(
          id: 'groom-buffer',
          name: 'مصاريف طارئة',
          icon: LucideIcons.shieldCheck,
          recommended: true,
        ),
      ],
    ),
  ],
);

const _brideCatalog = MoneyStarterCatalog(
  persona: MoneyStarterPersona.bride,
  eyebrow: 'بداية مرتبة للعروسة',
  title: 'جهّزي ميزانية فرحتك',
  subtitle:
      'رتّبنا لك البنود المهمة في مكان واحد. اختاري اللي يخصك، وتقدرين تعدّلين كل شي بعدين.',
  groups: [
    MoneyStarterGroup(
      id: 'bride-look',
      title: 'إطلالة العروسة',
      subtitle: 'كل ما يخص الإطلالة والاستعداد الشخصي.',
      categories: [
        MoneyStarterCategory(
          id: 'bride-dress',
          name: 'فستان العروسة',
          icon: LucideIcons.sparkles,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-makeup',
          name: 'المكياج والشعر',
          icon: LucideIcons.wand2,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-care',
          name: 'العناية والتجهيز',
          icon: LucideIcons.flower2,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-gold',
          name: 'الذهب والإكسسوارات',
          icon: LucideIcons.gem,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-shoes',
          name: 'الأحذية والشنط',
          icon: LucideIcons.shoppingBag,
        ),
        MoneyStarterCategory(
          id: 'bride-clothes',
          name: 'ملابس المناسبات',
          icon: LucideIcons.shirt,
        ),
        MoneyStarterCategory(
          id: 'bride-perfume',
          name: 'العطور والبخور',
          icon: LucideIcons.sprayCan,
        ),
      ],
    ),
    MoneyStarterGroup(
      id: 'bride-event',
      title: 'مناسبة النساء',
      subtitle: 'المكان والتنسيق والضيافة في يوم المناسبة.',
      categories: [
        MoneyStarterCategory(
          id: 'bride-venue',
          name: 'صالة أو مكان النساء',
          icon: LucideIcons.building2,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-decor',
          name: 'الكوشة والديكور',
          icon: LucideIcons.layoutGrid,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-photo',
          name: 'التصوير النسائي',
          icon: LucideIcons.camera,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-food',
          name: 'الضيافة والحلويات',
          icon: LucideIcons.cakeSlice,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-audio',
          name: 'الصوت والزفة',
          icon: LucideIcons.music2,
        ),
        MoneyStarterCategory(
          id: 'bride-invites',
          name: 'الدعوات والتوزيعات',
          icon: LucideIcons.mail,
        ),
        MoneyStarterCategory(
          id: 'bride-henna',
          name: 'ليلة الحناء',
          icon: LucideIcons.flower,
        ),
        MoneyStarterCategory(
          id: 'bride-naqsh',
          name: 'النقش',
          icon: LucideIcons.flower2,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-artist',
          name: 'الفنانة والزفة',
          icon: LucideIcons.music2,
        ),
        MoneyStarterCategory(
          id: 'bride-subhia',
          name: 'الصبحية',
          icon: LucideIcons.cakeSlice,
        ),
      ],
    ),
    MoneyStarterGroup(
      id: 'bride-life',
      title: 'التجهيز والبداية الجديدة',
      subtitle: 'بنود البيت والمصاريف المشتركة بعد المناسبة.',
      categories: [
        MoneyStarterCategory(
          id: 'bride-trousseau',
          name: 'جهاز العروسة',
          icon: LucideIcons.packageOpen,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-home',
          name: 'تجهيز المنزل',
          icon: LucideIcons.home,
          // G12 (R2): the home, as the groom's.
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-room',
          name: 'تجهيز غرفة العروسة',
          icon: LucideIcons.bedDouble,
        ),
        MoneyStarterCategory(
          id: 'bride-honeymoon',
          name: 'شهر العسل',
          icon: LucideIcons.plane,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'bride-gifts',
          name: 'الهدايا',
          icon: LucideIcons.gift,
        ),
        MoneyStarterCategory(
          id: 'bride-transport',
          name: 'المواصلات',
          icon: LucideIcons.navigation,
        ),
        MoneyStarterCategory(
          id: 'bride-guest-stay',
          name: 'إقامة الضيوف',
          icon: LucideIcons.hotel,
        ),
        MoneyStarterCategory(
          id: 'bride-buffer',
          name: 'مصاريف طارئة',
          icon: LucideIcons.shieldCheck,
          recommended: true,
        ),
      ],
    ),
  ],
);

const _neutralCatalog = MoneyStarterCatalog(
  persona: MoneyStarterPersona.neutral,
  eyebrow: 'بداية مالية مرتبة',
  title: 'جهّز أقسام الميزانية',
  subtitle: 'اختر البنود اللي تخص خطتك، وأضف أي بند خاص بكم قبل الحفظ.',
  groups: [
    MoneyStarterGroup(
      id: 'neutral-event',
      title: 'المناسبة',
      subtitle: 'أهم بنود يوم العرس.',
      categories: [
        MoneyStarterCategory(
          id: 'neutral-venue',
          name: 'مكان المناسبة',
          icon: LucideIcons.building2,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'neutral-food',
          name: 'الضيافة والطعام',
          icon: LucideIcons.utensils,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'neutral-photo',
          name: 'التصوير والفيديو',
          icon: LucideIcons.camera,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'neutral-decor',
          name: 'التنسيق والديكور',
          icon: LucideIcons.layoutGrid,
        ),
        MoneyStarterCategory(
          id: 'neutral-audio',
          name: 'الصوت والزفة',
          icon: LucideIcons.music2,
        ),
        MoneyStarterCategory(
          id: 'neutral-qat',
          name: 'القات والمقيل',
          icon: LucideIcons.leaf,
        ),
        MoneyStarterCategory(
          id: 'neutral-mahr',
          name: 'المهر والذهب',
          icon: LucideIcons.gem,
        ),
        // G12: the gold on its own, since the mahr row above is never
        // offered (C1).
        MoneyStarterCategory(
          id: 'neutral-gold',
          name: 'الذهب والشبكة',
          icon: LucideIcons.gem,
        ),
      ],
    ),
    MoneyStarterGroup(
      id: 'neutral-prep',
      title: 'التجهيز والبداية الجديدة',
      subtitle: 'البنود الشخصية والمشتركة.',
      categories: [
        MoneyStarterCategory(
          id: 'neutral-look',
          name: 'الملابس والتجهيز',
          icon: LucideIcons.shirt,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'neutral-invites',
          name: 'الدعوات والتوزيعات',
          icon: LucideIcons.mail,
        ),
        MoneyStarterCategory(
          id: 'neutral-home',
          name: 'تجهيز المنزل',
          icon: LucideIcons.home,
        ),
        MoneyStarterCategory(
          id: 'neutral-honeymoon',
          name: 'شهر العسل',
          icon: LucideIcons.plane,
          recommended: true,
        ),
        MoneyStarterCategory(
          id: 'neutral-transport',
          name: 'المواصلات',
          icon: LucideIcons.navigation,
        ),
        MoneyStarterCategory(
          id: 'neutral-buffer',
          name: 'مصاريف طارئة',
          icon: LucideIcons.shieldCheck,
          recommended: true,
        ),
      ],
    ),
  ],
);
