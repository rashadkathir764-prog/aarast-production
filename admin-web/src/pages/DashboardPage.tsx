import { CSSProperties, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  AdminStats,
  getProviderApplications,
  getStats,
  ProviderApplication,
} from '../api/admin';
import { useAuth } from '../auth/AuthProvider';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { MiniDonut } from '../components/MiniDonut';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import {
  Briefcase,
  CalendarCheck,
  Clock,
  MapPin,
  Tag,
  Users,
} from 'lucide-react';
import { formatDate } from './providerHelpers';

const quickActionStyle: CSSProperties = {
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  gap: '8px',
  padding: '16px 8px',
  background: '#FFFDF9',
  border: '1px solid #EFECE6',
  borderRadius: '12px',
  color: '#4A1525',
  textAlign: 'center',
  textDecoration: 'none',
};

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

  const providerStatusData = [
    { name: 'نشط', value: stats.approvedProviders, color: '#4A1525' },
    { name: 'قيد المراجعة', value: stats.pendingProviders, color: '#1565C0' },
    { name: 'يحتاج تعديل', value: stats.needsChangesProviders, color: '#B78103' },
    { name: 'مرفوض', value: stats.rejectedProviders, color: '#C62828' },
    { name: 'موقوف', value: stats.suspendedProviders, color: '#616161' },
  ];
  const providerStatusTotal = providerStatusData.reduce(
    (total, item) => total + item.value,
    0,
  );

  return (
    <section className="dashboard-page" style={{ padding: '24px', background: '#FCFBF7', minHeight: '100vh' }} dir="rtl">
      <div style={{ marginBottom: '24px', textAlign: 'right' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, color: '#4A1525', display: 'flex', alignItems: 'center', gap: '8px', margin: 0 }}>
          مرحبا {user?.name ?? 'مدير النظام'}
        </h1>
        <p style={{ margin: '4px 0 0', color: '#8A7A81', fontSize: '14px' }}>
          هذه الأرقام من APIs الإدارة المتاحة حاليا، وما لا يملك API يظهر كحالة قيد التجهيز.
        </p>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, minmax(0, 1fr))', gap: '16px', marginBottom: '24px' }}>
        <StatCard title="المستخدمون" value={stats.totalUsers} icon={<Users size={18} />} tone="gold" />
        <StatCard title="الموردون" value={stats.totalProviders} icon={<Briefcase size={18} />} tone="info" />
        <StatCard title="طلبات الموردين" value={stats.pendingProviders} icon={<Clock size={18} />} tone={stats.pendingProviders > 0 ? 'warning' : 'success'} />
        <StatCard title="طلبات العروض" value={stats.totalQuoteRequests} icon={<CalendarCheck size={18} />} tone="warning" />
        <StatCard title="المدن" value={stats.totalCities} icon={<MapPin size={18} />} tone="success" />
        <StatCard title="الفئات" value={stats.totalProviderCategories} icon={<Tag size={18} />} tone="gold" />
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.4fr 1fr', gap: '24px', marginBottom: '24px' }}>
        <SectionCard
          title="طلبات الموردين الجديدة"
          actions={<Link to="/providers/applications" style={{ fontSize: '13px', color: '#8A7A81', textDecoration: 'none' }}>عرض الكل</Link>}
        >
          {pending.length === 0 ? (
            <EmptyState
              title="لا توجد طلبات معلقة"
              message="لا توجد طلبات موردين جديدة حسب API الحالي."
            />
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', minHeight: '240px', overflowY: 'auto' }}>
              {pending.map((provider) => (
                <Link
                  key={provider.id}
                  to={`/providers/applications/${provider.id}`}
                  style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid #F5F4F0', color: 'inherit', textDecoration: 'none' }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <StatusBadge status={provider.status} />
                    <div style={{ fontSize: '11px', color: '#A1979C' }}>{formatDate(provider.createdAt)}</div>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <div style={{ textAlign: 'right' }}>
                      <div style={{ fontSize: '13px', fontWeight: 600, color: '#2B2A2A' }}>{provider.businessName}</div>
                      <div style={{ fontSize: '11px', color: '#8A7A81', marginTop: '2px' }}>
                        {provider.primaryCategory?.nameAr ?? 'فئة غير محددة'}
                      </div>
                    </div>
                    <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#1A1A1A', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#FFF', fontSize: '14px', fontWeight: 'bold', flexShrink: 0 }}>
                      {provider.businessName.charAt(0)}
                    </div>
                  </div>
                </Link>
              ))}
            </div>
          )}
          <Link to="/providers/applications" style={{ display: 'block', textAlign: 'center', marginTop: '12px', padding: '10px', background: '#FFF7FA', color: '#4A1525', borderRadius: '8px', fontWeight: 600, fontSize: '13px', textDecoration: 'none' }}>
            إدارة طلبات الموردين
          </Link>
        </SectionCard>

        <SectionCard
          title="النشاط خلال آخر 30 يوما"
          actions={
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px', background: '#F5F4F0', padding: '4px 12px', borderRadius: '8px', fontSize: '12px', color: '#4A1525' }}>
              <span>غير مفعّل</span>
            </div>
          }
        >
          <EmptyState
            title="تقارير النشاط تحتاج API"
            message="لا يوجد endpoint إداري للتقارير الزمنية، لذلك لا يتم عرض مخطط أو أرقام محاكاة."
            tone="api"
          />
        </SectionCard>

        <SectionCard title="توزيع الموردين حسب الحالة">
          <div style={{ height: '240px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <MiniDonut
              value={providerStatusTotal}
              label="مورد"
              data={providerStatusData}
            />
          </div>
        </SectionCard>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '24px' }}>
        <SectionCard title="إجراءات متاحة">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <Link to="/cities" style={quickActionStyle}>
              <MapPin size={24} color="#C79B3F" strokeWidth={1.5} />
              <span style={{ fontSize: '12px', fontWeight: 600, lineHeight: 1.3 }}>إضافة أو تعديل<br />مدينة</span>
            </Link>
            <Link to="/categories" style={quickActionStyle}>
              <Tag size={24} color="#C79B3F" strokeWidth={1.5} />
              <span style={{ fontSize: '12px', fontWeight: 600, lineHeight: 1.3 }}>إدارة<br />الفئات</span>
            </Link>
            <Link to="/providers/applications" style={quickActionStyle}>
              <Clock size={24} color="#C79B3F" strokeWidth={1.5} />
              <span style={{ fontSize: '12px', fontWeight: 600, lineHeight: 1.3 }}>مراجعة<br />طلبات الموردين</span>
            </Link>
            <Link to="/providers" style={quickActionStyle}>
              <Briefcase size={24} color="#C79B3F" strokeWidth={1.5} />
              <span style={{ fontSize: '12px', fontWeight: 600, lineHeight: 1.3 }}>إدارة<br />الموردين</span>
            </Link>
          </div>
        </SectionCard>

        <SectionCard
          title="الحجوزات والطلبات"
        >
          <EmptyState
            title="لا يوجد Admin API للحجوزات"
            message="قائمة APIs المتاحة لا تتضمن endpoint لإدارة الحجوزات، لذلك تم حذف الجدول الوهمي والإبقاء على صفحة حالة آمنة."
            tone="api"
          />
        </SectionCard>
      </div>
    </section>
  );
}
