import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  BarChart3,
  Bell,
  Briefcase,
  CalendarCheck,
  Clock,
  MapPin,
  PackageSearch,
  Star,
  Tag,
  Users,
} from 'lucide-react';
import {
  type AdminStats,
  getProviderApplications,
  getStats,
  type ProviderApplication,
} from '../api/admin';
import { useAuth } from '../auth/AuthProvider';
import { ActionLink } from '../components/ActionButton';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { MiniDonut } from '../components/MiniDonut';
import { PageHeader } from '../components/PageHeader';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate } from './providerHelpers';

export function DashboardPage() {
  const { user } = useAuth();
  const [stats, setStats] = useState<AdminStats | null>(null);
  const [pending, setPending] = useState<ProviderApplication[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  async function load() {
    setIsLoading(true);
    setError(null);
    try {
      const [statsResult, pendingResult] = await Promise.all([
        getStats(),
        getProviderApplications({ status: 'PENDING', limit: 5 }),
      ]);
      setStats(statsResult);
      setPending(pendingResult.items);
    } catch (err) {
      setError(
        err instanceof Error ? err.message : 'تعذر تحميل لوحة التحكم.',
      );
    } finally {
      setIsLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  const title = `مرحباً، ${user?.name ?? 'مدير النظام'}`;
  const header = (
    <PageHeader
      eyebrow="نظرة تشغيلية"
      title={title}
      description="ابدأ بالطلبات التي تحتاج قراراً، ثم استخدم الملخص لمتابعة حالة المنصة."
    />
  );

  if (isLoading) {
    return (
      <section className="dashboard-page" dir="rtl">
        {header}
        <LoadingState title="جارٍ تجهيز لوحة التحكم" />
      </section>
    );
  }

  if (error) {
    return (
      <section className="dashboard-page" dir="rtl">
        {header}
        <ErrorState message={error} onRetry={load} />
      </section>
    );
  }

  if (!stats) {
    return (
      <section className="dashboard-page" dir="rtl">
        {header}
        <EmptyState
          title="لا توجد بيانات"
          message="لم تصل إحصاءات الإدارة بعد."
        />
      </section>
    );
  }

  const attentionCount = stats.pendingProviders + stats.needsChangesProviders;
  const providerStatusData = [
    { name: 'نشط', value: stats.approvedProviders, color: 'var(--success)' },
    { name: 'قيد المراجعة', value: stats.pendingProviders, color: 'var(--info)' },
    {
      name: 'يحتاج تعديل',
      value: stats.needsChangesProviders,
      color: 'var(--warning)',
    },
    { name: 'مرفوض', value: stats.rejectedProviders, color: 'var(--danger)' },
    {
      name: 'موقوف',
      value: stats.suspendedProviders,
      color: 'var(--text-disabled)',
    },
  ];
  const providerStatusTotal = providerStatusData.reduce(
    (total, item) => total + item.value,
    0,
  );

  return (
    <section className="dashboard-page" dir="rtl">
      <PageHeader
        eyebrow="نظرة تشغيلية"
        title={title}
        description="ابدأ بالطلبات التي تحتاج قراراً، ثم استخدم الملخص لمتابعة حالة المنصة."
        actions={
          <ActionLink
            to={attentionCount > 0 ? '/providers/applications' : '/providers'}
            icon={<Clock size={18} />}
          >
            {attentionCount > 0
              ? `مراجعة ${attentionCount} طلب${attentionCount === 1 ? '' : 'ات'}`
              : 'عرض الموردين'}
          </ActionLink>
        }
      />

      <div className="stats-grid dashboard-summary-grid">
        <StatCard
          title="المستخدمون"
          value={stats.totalUsers}
          icon={<Users size={18} />}
          tone="brand"
        />
        <StatCard
          title="الموردون"
          value={stats.totalProviders}
          icon={<Briefcase size={18} />}
          tone="info"
        />
        <StatCard
          title="خطط الزواج"
          value={stats.totalWeddingPlans}
          icon={<CalendarCheck size={18} />}
          tone="success"
        />
        <StatCard
          title="طلبات العروض"
          value={stats.totalQuoteRequests}
          icon={<BarChart3 size={18} />}
          tone="warning"
        />
      </div>

      <div className="dashboard-priority-grid">
        <SectionCard
          title="طلبات الموردين التي تنتظر المراجعة"
          subtitle={
            pending.length > 0
              ? 'اختر طلباً لعرض التفاصيل واتخاذ الإجراء المناسب.'
              : 'لا توجد طلبات جديدة تحتاج مراجعة الآن.'
          }
          actions={<Link to="/providers/applications">عرض الكل</Link>}
        >
          {pending.length === 0 ? (
            <div className="dashboard-empty-note">
              <strong>قائمة المراجعة فارغة</strong>
              <span>ستظهر هنا الطلبات الجديدة فور وصولها.</span>
            </div>
          ) : (
            <ul className="dashboard-pending-list">
              {pending.map((provider) => (
                <li key={provider.id}>
                  <Link to={`/providers/applications/${provider.id}`}>
                    <span className="dashboard-pending-avatar" aria-hidden="true">
                      {provider.businessName.charAt(0)}
                    </span>
                    <span className="dashboard-pending-main">
                      <strong>{provider.businessName}</strong>
                      <span>
                        {provider.primaryCategory?.nameAr ?? 'فئة غير محددة'}
                      </span>
                    </span>
                    <span className="dashboard-pending-date">
                      {formatDate(provider.createdAt)}
                    </span>
                    <StatusBadge status={provider.status} />
                  </Link>
                </li>
              ))}
            </ul>
          )}
        </SectionCard>

        <SectionCard
          title="صورة العمل اليوم"
          subtitle="مؤشرات سريعة تساعد على ترتيب الأولويات."
        >
          <ul className="dashboard-health-list">
            <li>
              <span>طلبات جديدة</span>
              <strong>{stats.pendingProviders}</strong>
            </li>
            <li>
              <span>طلبات تحتاج تعديل</span>
              <strong>{stats.needsChangesProviders}</strong>
            </li>
            <li>
              <span>موردون نشطون</span>
              <strong>{stats.approvedProviders}</strong>
            </li>
            <li>
              <span>مدن مفعّلة</span>
              <strong>{stats.totalCities}</strong>
            </li>
          </ul>
        </SectionCard>
      </div>

      <div className="dashboard-priority-grid">
        <SectionCard
          title="حالة الموردين"
          subtitle="توزيع مرئي للحالة الحالية، وليس مؤشراً مالياً أو حجزاً."
        >
          <MiniDonut
            value={providerStatusTotal}
            label="مورد"
            data={providerStatusData}
          />
        </SectionCard>

        <SectionCard
          title="وصول سريع"
          subtitle="انتقل إلى مساحة العمل المطلوبة دون تكرار الإجراءات."
        >
          <div className="dashboard-actions">
            <Link className="dashboard-action" to="/providers/applications">
              <Clock size={20} aria-hidden="true" />
              <span>طلبات الموردين</span>
            </Link>
            <Link className="dashboard-action" to="/providers">
              <Briefcase size={20} aria-hidden="true" />
              <span>دليل الموردين</span>
            </Link>
            <Link className="dashboard-action" to="/categories">
              <Tag size={20} aria-hidden="true" />
              <span>فئات الموردين</span>
            </Link>
            <Link className="dashboard-action" to="/cities">
              <MapPin size={20} aria-hidden="true" />
              <span>المدن والمناطق</span>
            </Link>
            <Link className="dashboard-action" to="/services">
              <PackageSearch size={20} aria-hidden="true" />
              <span>الخدمات</span>
            </Link>
            <Link className="dashboard-action" to="/reviews">
              <Star size={20} aria-hidden="true" />
              <span>مراقبة التقييمات</span>
            </Link>
            <Link className="dashboard-action" to="/notifications">
              <Bell size={20} aria-hidden="true" />
              <span>إشعارات الحساب</span>
            </Link>
            <Link className="dashboard-action" to="/reports">
              <BarChart3 size={20} aria-hidden="true" />
              <span>التقارير التشغيلية</span>
            </Link>
          </div>
        </SectionCard>
      </div>
    </section>
  );
}
