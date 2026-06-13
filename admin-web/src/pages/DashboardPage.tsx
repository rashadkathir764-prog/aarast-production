import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  AdminStats,
  getProviderApplications,
  getStats,
  ProviderApplication,
} from '../api/admin';
import { useAuth } from '../auth/AuthProvider';
import { ActionLink } from '../components/ActionButton';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { MiniDonut } from '../components/MiniDonut';
import { MiniLineChart } from '../components/MiniLineChart';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { formatDate } from './providerHelpers';
import { Users, Briefcase, CalendarCheck, MapPin, Clock, CreditCard, UserPlus, Gift, BarChart2, Megaphone } from 'lucide-react';

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
    load();
  }, []);

  if (isLoading) return <LoadingState title="جاري تجهيز لوحة التحكم" />;
  if (error) return <ErrorState message={error} onRetry={load} />;
  if (!stats) {
    return (
      <EmptyState
        title="لا توجد بيانات"
        message="لم تصل إحصاءات الإدارة بعد."
      />
    );
  }

  const reviewTotal =
    stats.pendingProviders +
    stats.needsChangesProviders +
    stats.approvedProviders +
    stats.rejectedProviders +
    stats.suspendedProviders;
  const activeReviewCount = stats.pendingProviders + stats.needsChangesProviders;
  const approvalRate = Math.round(
    (stats.approvedProviders / Math.max(reviewTotal, 1)) * 100,
  );
  const distribution = [
    {
      label: 'مؤكد',
      value: stats.approvedProviders,
      color: '#2d8a5d',
    },
    {
      label: 'قيد المراجعة',
      value: stats.pendingProviders,
      color: '#c79b3f',
    },
    {
      label: 'قيد التنفيذ',
      value: stats.needsChangesProviders,
      color: '#386f93',
    },
    {
      label: 'ملغى',
      value: stats.rejectedProviders,
      color: '#75646d',
    },
  ];
  
  const donutData = distribution.map(item => ({
    name: item.label,
    value: item.value,
    color: item.color
  }));

  const chartValues = [
    stats.totalUsers,
    stats.totalProviders,
    stats.totalQuoteRequests,
    stats.totalWeddingPlans,
    stats.totalCities,
    stats.totalProviderCategories,
    activeReviewCount,
  ];

  return (
    <section className="page-stack dashboard-page">
      <div style={{ position: 'relative', overflow: 'hidden', padding: '32px 24px', background: '#fff', borderRadius: '16px', border: '1px solid rgba(74, 7, 31, 0.05)', marginBottom: '8px' }}>
        <div style={{ position: 'absolute', top: '-50px', left: '-50px', width: '300px', height: '300px', opacity: 0.03, pointerEvents: 'none', backgroundImage: 'url("data:image/svg+xml,%3Csvg width=\'100\' height=\'100\' viewBox=\'0 0 100 100\' xmlns=\'http://www.w3.org/2000/svg\'%3E%3Cpath d=\'M50 0c27.614 0 50 22.386 50 50s-22.386 50-50 50S0 77.614 0 50 22.386 0 50 0zm0 10C27.909 10 10 27.909 10 50s17.909 40 40 40 40-17.909 40-40S72.091 10 50 10zm0 20c11.046 0 20 8.954 20 20s-8.954 20-20 20-20-8.954-20-20 8.954-20 20-20z\' fill=\'%236f0b31\' fill-rule=\'evenodd\'/%3E%3C/svg%3E")' }} />
        <div style={{ position: 'relative', zIndex: 1 }}>
          <h1 style={{ fontSize: '32px', margin: 0, color: 'var(--color-burgundy-950)', display: 'flex', alignItems: 'center', gap: '12px' }}>
            مرحباً عماد <span style={{ fontSize: '36px' }}>👋</span>
          </h1>
          <p style={{ margin: '8px 0 0', color: 'var(--color-muted)', fontSize: '15px' }}>إليك نظرة عامة على أداء منصة أعرست اليوم</p>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '16px', marginBottom: '8px' }}>
        <StatCard
          title="إجمالي المستخدمين"
          value={stats.totalUsers}
          icon={<Users size={20} strokeWidth={2} />}
          trend={22}
          hint="مستخدم"
        />
        <StatCard
          title="إجمالي الموردين"
          value={stats.totalProviders}
          icon={<Briefcase size={20} strokeWidth={2} />}
          trend={15}
          hint="مورد"
        />
        <StatCard
          title="إجمالي الحجوزات"
          value={stats.totalQuoteRequests}
          icon={<CalendarCheck size={20} strokeWidth={2} />}
          trend={12}
          hint="حجز"
        />
        <StatCard
          title="الإيرادات (هذا الشهر)"
          value="258,450"
          icon={<CreditCard size={20} strokeWidth={2} />}
          trend={18}
          hint="ر.س"
        />
        <StatCard
          title="المدن"
          value={stats.totalCities}
          icon={<MapPin size={20} strokeWidth={2} />}
          hint="مدن نشطة"
        />
        <StatCard
          title="الطلبات المعلقة"
          value={activeReviewCount}
          icon={<Clock size={20} strokeWidth={2} />}
          trend={-8}
          hint="طلب قيد المراجعة"
          tone="warning"
        />
      </div>

      <div className="dashboard-grid" style={{ gridTemplateColumns: '1.2fr 1.8fr 1fr', gap: '16px' }}>
        <SectionCard title="توزيع الطلبات حسب الحالة">
          <div style={{ height: '260px' }}>
            <MiniDonut
              value={stats.totalQuoteRequests}
              label="إجمالي الطلبات"
              data={donutData}
            />
          </div>
        </SectionCard>

        <SectionCard title="النشاط خلال آخر 30 يوماً">
          <MiniLineChart values={chartValues} label="النشاط" />
        </SectionCard>

        <SectionCard
          title="طلبات الموردين الجديدة"
          actions={
            <Link className="text-link" to="/providers/applications" style={{ fontSize: '13px' }}>
              عرض الكل
            </Link>
          }
        >
          {pending.length === 0 ? (
            <EmptyState
              title="لا توجد طلبات جديدة"
              message="طلبات الموردين الجديدة ستظهر هنا فور وصولها."
            />
          ) : (
            <div className="request-list">
              {pending.map((provider) => (
                <Link
                  key={provider.id}
                  to={`/providers/applications/${provider.id}`}
                  className="request-row"
                  style={{ gridTemplateColumns: '44px minmax(0, 1fr) auto', padding: '12px 0' }}
                >
                  <span className="request-logo" style={{ borderRadius: '50%', background: '#000', color: '#fff', fontSize: '18px' }}>
                    {provider.businessName.slice(0, 1)}
                  </span>
                  <div>
                    <strong style={{ fontSize: '14px' }}>{provider.businessName}</strong>
                    <small>{provider.primaryCategory?.nameAr ?? 'فئة غير محددة'}</small>
                  </div>
                  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: '8px' }}>
                    <span style={{ fontSize: '11px', color: 'var(--color-success)', background: 'rgba(45, 138, 93, 0.1)', padding: '2px 8px', borderRadius: '999px', fontWeight: 800 }}>جديد</span>
                    <time dateTime={provider.createdAt} style={{ fontSize: '11px', color: 'var(--color-muted)' }}>
                      منذ ساعتين
                    </time>
                  </div>
                </Link>
              ))}
            </div>
          )}
          <Link to="/providers/applications" style={{ display: 'block', textAlign: 'center', marginTop: '16px', padding: '12px', background: 'rgba(199, 155, 63, 0.05)', color: 'var(--color-burgundy-900)', borderRadius: '8px', fontWeight: 700, fontSize: '13px' }}>
            إدارة طلبات الموردين ›
          </Link>
        </SectionCard>
      </div>

      <div className="dashboard-bottom-grid" style={{ gridTemplateColumns: '2fr 1fr', gap: '16px' }}>
        <SectionCard
          title="أحدث الحجوزات"
          actions={
            <Link className="text-link" to="/bookings" style={{ fontSize: '13px' }}>
              عرض الكل
            </Link>
          }
        >
          <DataTable
            columns={[
              'الحالة',
              'المبلغ',
              'التاريخ',
              'الخدمة',
              'المورد',
              'العميل',
              'رقم الحجز',
            ]}
            dense
            minWidth={640}
          >
            <tr>
              <td><StatusBadge status="ACTIVE" /></td>
              <td>12,500 ر.س</td>
              <td>2025/05/23</td>
              <td>تصوير فوتوغرافي</td>
              <td>استديو بريق</td>
              <td>سارة محمد</td>
              <td style={{ fontWeight: 700 }}>#B-1256</td>
            </tr>
            <tr>
              <td><StatusBadge status="PENDING_REVIEW" /></td>
              <td>8,750 ر.س</td>
              <td>2025/05/22</td>
              <td>تنسيق زهور</td>
              <td>زهور المملكة</td>
              <td>أحمد القحطاني</td>
              <td style={{ fontWeight: 700 }}>#B-1255</td>
            </tr>
            <tr>
              <td><StatusBadge status="NEEDS_CHANGES" /></td>
              <td>15,000 ر.س</td>
              <td>2025/05/22</td>
              <td>قاعة + ضيافة</td>
              <td>قصر ورد</td>
              <td>نورة عبدالرحمن</td>
              <td style={{ fontWeight: 700 }}>#B-1254</td>
            </tr>
            <tr>
              <td><StatusBadge status="COMPLETED" /></td>
              <td>6,300 ر.س</td>
              <td>2025/05/21</td>
              <td>فرقة موسيقية</td>
              <td>ليالي الطرب</td>
              <td>فهد السبيعي</td>
              <td style={{ fontWeight: 700 }}>#B-1253</td>
            </tr>
          </DataTable>
          <Link to="/bookings" style={{ display: 'block', textAlign: 'center', marginTop: '16px', color: 'var(--color-muted)', fontWeight: 700, fontSize: '13px' }}>
            عرض كل الحجوزات ›
          </Link>
        </SectionCard>

        <SectionCard title="إجراءات سريعة" className="quick-actions-card">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
            <Link to="/cities/new" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', padding: '24px 12px', background: 'rgba(255, 250, 243, 0.7)', border: '1px solid rgba(199, 155, 63, 0.2)', borderRadius: '12px', color: 'var(--color-burgundy-950)', textAlign: 'center' }}>
              <MapPin size={28} color="var(--color-gold-500)" strokeWidth={1.5} />
              <strong style={{ fontSize: '13px', lineHeight: 1.4 }}>إضافة<br/>مدينة جديدة</strong>
            </Link>
            <Link to="/providers/new" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', padding: '24px 12px', background: 'rgba(255, 250, 243, 0.7)', border: '1px solid rgba(199, 155, 63, 0.2)', borderRadius: '12px', color: 'var(--color-burgundy-950)', textAlign: 'center' }}>
              <UserPlus size={28} color="var(--color-gold-500)" strokeWidth={1.5} />
              <strong style={{ fontSize: '13px', lineHeight: 1.4 }}>إضافة<br/>مورد جديد</strong>
            </Link>
            <Link to="/reports" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', padding: '24px 12px', background: 'rgba(255, 250, 243, 0.7)', border: '1px solid rgba(199, 155, 63, 0.2)', borderRadius: '12px', color: 'var(--color-burgundy-950)', textAlign: 'center' }}>
              <BarChart2 size={28} color="var(--color-gold-500)" strokeWidth={1.5} />
              <strong style={{ fontSize: '13px', lineHeight: 1.4 }}>إضافة<br/>التقارير</strong>
            </Link>
            <Link to="/services/new" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '12px', padding: '24px 12px', background: 'rgba(255, 250, 243, 0.7)', border: '1px solid rgba(199, 155, 63, 0.2)', borderRadius: '12px', color: 'var(--color-burgundy-950)', textAlign: 'center' }}>
              <Gift size={28} color="var(--color-gold-500)" strokeWidth={1.5} />
              <strong style={{ fontSize: '13px', lineHeight: 1.4 }}>إضافة<br/>خدمة جديدة</strong>
            </Link>
          </div>
          <button style={{ width: '100%', marginTop: '16px', padding: '16px', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px', background: 'rgba(199, 155, 63, 0.1)', border: '1px solid rgba(199, 155, 63, 0.2)', borderRadius: '12px', color: 'var(--color-burgundy-900)', fontWeight: 700, cursor: 'pointer' }}>
             <Megaphone size={18} />
             إرسال إشعار جماعي
          </button>
        </SectionCard>
      </div>

    </section>
  );
}
