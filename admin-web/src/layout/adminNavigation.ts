import {
  BarChart3,
  Flag,
  History,
  Inbox,
  LayoutGrid,
  Package,
  Star,
  Store,
  UserPlus,
  Users,
  type LucideIcon,
} from 'lucide-react';
import { AdminPermission } from '../features/auth/api';

/** A queue whose size the sidebar shows beside its link. */
export type AdminQueueCount = 'inbox' | 'applications' | 'reports';

export type AdminNavigationItem = {
  route: string;
  label: string;
  permission: AdminPermission;
  icon: LucideIcon;
  isActive: (pathname: string) => boolean;
  count?: AdminQueueCount;
  /** A hot count is coral (akit `hot`), the others are quiet. */
  hot?: boolean;
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
  /** «لوحة الإدارة / …» after the group, as drawn. */
  crumb: string[];
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

function nestedRoute(...routes: string[]) {
  return (pathname: string) => routes.some((route) => matchesRoute(pathname, route));
}

function providerDirectoryRoute(pathname: string) {
  return (
    matchesRoute(pathname, '/providers') &&
    !matchesRoute(pathname, '/providers/applications')
  );
}

export const CATALOG_ROUTES = [
  '/categories',
  '/reference-catalogs',
  '/cities',
  '/administrative-areas',
] as const;

/**
 * The seven sections of the admin designs (akit `nav`), holding only the
 * pages that are built. Links for designs that wait for the server are left
 * out until their page exists.
 */
export const adminNavigationGroups: AdminNavigationGroup[] = [
  {
    label: 'اليوم',
    links: [
      {
        route: '/',
        label: 'الصندوق',
        permission: AdminPermission.DASHBOARD_READ,
        icon: Inbox,
        isActive: exactRoute('/'),
        count: 'inbox',
        hot: true,
      },
    ],
  },
  {
    label: 'السوق',
    links: [
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
    label: 'المزودين',
    links: [
      {
        route: '/providers/applications',
        label: 'طلبات الانضمام',
        permission: AdminPermission.PROVIDERS_READ,
        icon: UserPlus,
        isActive: nestedRoute('/providers/applications'),
        count: 'applications',
      },
      {
        route: '/providers',
        label: 'دليل المزودين',
        permission: AdminPermission.PROVIDERS_READ,
        icon: Store,
        isActive: providerDirectoryRoute,
      },
      {
        route: '/services',
        label: 'الخدمات',
        permission: AdminPermission.SERVICES_READ,
        icon: Package,
        isActive: nestedRoute('/services'),
      },
    ],
  },
  {
    label: 'الناس',
    links: [
      {
        route: '/users',
        label: 'المستخدمون',
        permission: AdminPermission.USERS_READ,
        icon: Users,
        isActive: nestedRoute('/users'),
      },
    ],
  },
  {
    label: 'الرقابة',
    links: [
      {
        route: '/conversation-reports',
        label: 'البلاغات',
        permission: AdminPermission.CONVERSATION_REPORTS_READ,
        icon: Flag,
        isActive: nestedRoute('/conversation-reports'),
        count: 'reports',
        hot: true,
      },
      {
        route: '/reviews',
        label: 'التقييمات',
        permission: AdminPermission.REVIEWS_READ,
        icon: Star,
        isActive: nestedRoute('/reviews'),
      },
    ],
  },
  {
    label: 'النظام',
    links: [
      {
        route: '/categories',
        label: 'الكتالوج',
        permission: AdminPermission.CATALOG_READ,
        icon: LayoutGrid,
        isActive: nestedRoute(...CATALOG_ROUTES),
      },
    ],
  },
  {
    label: 'الفريق',
    links: [
      {
        route: '/audit-logs',
        label: 'سجل التدقيق',
        permission: AdminPermission.AUDIT_READ,
        icon: History,
        isActive: nestedRoute('/audit-logs'),
      },
    ],
  },
];

export const adminNavigationItems = adminNavigationGroups.flatMap(
  (group) => group.links.map((link) => ({ ...link, group: group.label })),
);

/** Pages kept without a link of their own. */
const unlinkedLocations = [
  { route: '/notifications', group: 'النظام', title: 'الإشعارات' },
];

const detailLocations = [
  {
    route: '/providers/applications',
    title: 'تفاصيل طلب',
    matches: (pathname: string) =>
      /^\/providers\/applications\/[^/]+$/.test(pathname),
  },
  {
    route: '/providers',
    title: 'تفاصيل مزود',
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
    const unlinked = unlinkedLocations.find((location) =>
      matchesRoute(normalizedPathname, location.route),
    );
    if (unlinked) {
      return {
        group: unlinked.group,
        title: unlinked.title,
        parentTitle: unlinked.title,
        route: unlinked.route,
        isDetail: false,
        crumb: [unlinked.group],
      };
    }
    return {
      group: 'لوحة الإدارة',
      title: 'صفحة غير معروفة',
      parentTitle: 'الصندوق',
      route: '/',
      isDetail: false,
      crumb: [],
    };
  }

  const crumb = [item.group];
  if (item.route === '/categories') crumb.push(item.label);
  if (detail) crumb.push(detail.title);

  return {
    group: item.group,
    title: detail?.title ?? item.label,
    parentTitle: item.label,
    route: item.route,
    isDetail: Boolean(detail),
    crumb,
  };
}
