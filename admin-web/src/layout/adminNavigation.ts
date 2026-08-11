import {
  BarChart3,
  Inbox,
  LayoutGrid,
  ListTree,
  MapPin,
  MessageSquareText,
  PackageSearch,
  ShieldAlert,
  ShieldCheck,
  Star,
  Tag,
  UserCircle,
  Users,
  type LucideIcon,
} from 'lucide-react';
import { AdminPermission } from '../auth/adminPermissions';

export type AdminNavigationItem = {
  route: string;
  label: string;
  permission: AdminPermission;
  icon: LucideIcon;
  isActive: (pathname: string) => boolean;
};

export type AdminNavigationGroup = {
  label: string;
  links: AdminNavigationItem[];
};

export type AdminLocation = {
  group: string;
  title: string;
  parentTitle: string;
  route: string;
  isDetail: boolean;
};

function normalizePathname(pathname: string) {
  const normalized = pathname.replace(/\/+$/, '');
  return normalized || '/';
}

function matchesRoute(pathname: string, route: string) {
  const normalizedPathname = normalizePathname(pathname);
  return (
    normalizedPathname === route ||
    normalizedPathname.startsWith(`${route}/`)
  );
}

function exactRoute(route: string) {
  return (pathname: string) => normalizePathname(pathname) === route;
}

function nestedRoute(route: string) {
  return (pathname: string) => matchesRoute(pathname, route);
}

function providerDirectoryRoute(pathname: string) {
  return (
    matchesRoute(pathname, '/providers') &&
    !matchesRoute(pathname, '/providers/applications')
  );
}

export const adminNavigationGroups: AdminNavigationGroup[] = [
  {
    label: 'نظرة عامة',
    links: [
      {
        route: '/',
        label: 'لوحة التحكم',
        permission: AdminPermission.DASHBOARD_READ,
        icon: LayoutGrid,
        isActive: exactRoute('/'),
      },
      {
        route: '/reports',
        label: 'التقارير',
        permission: AdminPermission.REPORTS_READ,
        icon: BarChart3,
        isActive: nestedRoute('/reports'),
      },
    ],
  },
  {
    label: 'السوق والكتالوج',
    links: [
      {
        route: '/providers',
        label: 'الموردون',
        permission: AdminPermission.PROVIDERS_READ,
        icon: Users,
        isActive: providerDirectoryRoute,
      },
      {
        route: '/providers/applications',
        label: 'طلبات الموردين',
        permission: AdminPermission.PROVIDERS_READ,
        icon: Inbox,
        isActive: nestedRoute('/providers/applications'),
      },
      {
        route: '/services',
        label: 'الخدمات',
        permission: AdminPermission.SERVICES_READ,
        icon: PackageSearch,
        isActive: nestedRoute('/services'),
      },
      {
        route: '/reviews',
        label: 'التقييمات',
        permission: AdminPermission.REVIEWS_READ,
        icon: Star,
        isActive: nestedRoute('/reviews'),
      },
      {
        route: '/categories',
        label: 'فئات الموردين',
        permission: AdminPermission.CATALOG_READ,
        icon: Tag,
        isActive: nestedRoute('/categories'),
      },
      {
        route: '/reference-catalogs',
        label: 'الكتالوجات الديناميكية',
        permission: AdminPermission.CATALOG_READ,
        icon: ListTree,
        isActive: nestedRoute('/reference-catalogs'),
      },
      {
        route: '/administrative-areas',
        label: 'المحافظات والمديريات',
        permission: AdminPermission.CATALOG_READ,
        icon: MapPin,
        isActive: nestedRoute('/administrative-areas'),
      },
      {
        route: '/cities',
        label: 'المدن والمناطق',
        permission: AdminPermission.CATALOG_READ,
        icon: MapPin,
        isActive: nestedRoute('/cities'),
      },
    ],
  },
  {
    label: 'الحسابات والرقابة',
    links: [
      {
        route: '/users',
        label: 'المستخدمون',
        permission: AdminPermission.USERS_READ,
        icon: UserCircle,
        isActive: nestedRoute('/users'),
      },
      {
        route: '/conversation-reports',
        label: 'بلاغات المحادثات',
        permission: AdminPermission.CONVERSATION_REPORTS_READ,
        icon: ShieldAlert,
        isActive: nestedRoute('/conversation-reports'),
      },
      {
        route: '/notifications',
        label: 'الإشعارات',
        permission: AdminPermission.NOTIFICATIONS_READ,
        icon: MessageSquareText,
        isActive: nestedRoute('/notifications'),
      },
      {
        route: '/audit-logs',
        label: 'سجل التدقيق',
        permission: AdminPermission.AUDIT_READ,
        icon: ShieldCheck,
        isActive: nestedRoute('/audit-logs'),
      },
    ],
  },
];

export const adminNavigationItems = adminNavigationGroups.flatMap(
  (group) => group.links.map((link) => ({ ...link, group: group.label })),
);

const detailLocations = [
  {
    route: '/providers/applications',
    title: 'تفاصيل طلب مورد',
    matches: (pathname: string) =>
      /^\/providers\/applications\/[^/]+$/.test(pathname),
  },
  {
    route: '/providers',
    title: 'تفاصيل مورد',
    matches: (pathname: string) =>
      /^\/providers\/(?!applications(?:\/|$)|new$)[^/]+$/.test(pathname),
  },
  {
    route: '/users',
    title: 'تفاصيل مستخدم',
    matches: (pathname: string) => /^\/users\/[^/]+$/.test(pathname),
  },
];

export function resolveAdminLocation(pathname: string): AdminLocation {
  const normalizedPathname = normalizePathname(pathname);
  const detail = detailLocations.find((location) =>
    location.matches(normalizedPathname),
  );
  const item = adminNavigationItems.find((candidate) =>
    candidate.isActive(detail?.route ?? normalizedPathname),
  );

  if (!item) {
    return {
      group: 'لوحة الإدارة',
      title: 'صفحة غير معروفة',
      parentTitle: 'لوحة التحكم',
      route: '/',
      isDetail: false,
    };
  }

  return {
    group: item.group,
    title: detail?.title ?? item.label,
    parentTitle: item.label,
    route: item.route,
    isDetail: Boolean(detail),
  };
}
