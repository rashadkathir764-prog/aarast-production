import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  AdminStats,
  getProviderApplications,
  getStats,
  ProviderApplication,
} from '../api/admin';
import { useAuth } from '../auth/AuthProvider';
import { DataTable } from '../components/DataTable';
import { EmptyState } from '../components/EmptyState';
import { ErrorState } from '../components/ErrorState';
import { LoadingState } from '../components/LoadingState';
import { MiniDonut } from '../components/MiniDonut';
import { MiniLineChart } from '../components/MiniLineChart';
import { SectionCard } from '../components/SectionCard';
import { StatCard } from '../components/StatCard';
import { StatusBadge } from '../components/StatusBadge';
import { Users, Briefcase, CalendarCheck, MapPin, Clock, CreditCard, UserPlus, BarChart2, Gift, Megaphone, ChevronDown } from 'lucide-react';

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

  const distribution = [
    { label: 'مؤكد', value: 524, color: '#4A1525' },
    { label: 'قيد المراجعة', value: 299, color: '#A27B5C' },
    { label: 'قيد التنفيذ', value: 224, color: '#D4ADFC' },
    { label: 'مكتمل', value: 125, color: '#867070' },
    { label: 'ملغى', value: 76, color: '#D5B4B4' },
  ];
  
  const donutData = distribution.map(item => ({
    name: item.label,
    value: item.value,
    color: item.color
  }));

  const chartValues = [100, 150, 120, 160, 110, 140, 120];

  const mockPendingProviders = [
    { id: '1', businessName: 'استديو لمسة ضوء', category: 'تصوير فوتوغرافي', time: 'منذ 30 دقيقة' },
    { id: '2', businessName: 'قصر ورد للاحتفالات', category: 'قاعات أفراح', time: 'منذ ساعة' },
    { id: '3', businessName: 'زهور المملكة', category: 'تنسيق زهور', time: 'منذ ساعتين' },
    { id: '4', businessName: 'ليالي الطرب', category: 'فرقة موسيقية', time: 'منذ 3 ساعات' },
    { id: '5', businessName: 'حلويات مرام', category: 'صيانة وحلويات', time: 'منذ 5 ساعات' },
  ];

  return (
    <section className="dashboard-page" style={{ padding: '24px', background: '#FCFBF7', minHeight: '100vh' }} dir="rtl">
      
      {/* الترحيب العلوي */}
      <div style={{ marginBottom: '24px', textAlign: 'right' }}>
        <h1 style={{ fontSize: '28px', fontWeight: 700, color: '#4A1525', display: 'flex', alignItems: 'center', gap: '8px', margin: 0 }}>
          مرحباً عماد <span style={{ fontSize: '28px' }}>👋</span>
        </h1>
        <p style={{ margin: '4px 0 0', color: '#8A7A81', fontSize: '14px' }}>
          إليك نظرة عامة على أداء منصة أعرست اليوم
        </p>
      </div>

      {/* كروت الإحصاءات */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(6, minmax(0, 1fr))', gap: '16px', marginBottom: '24px' }}>
        <StatCard title="إجمالي المستخدمين" value="4,892" icon={<Users size={18} />} trend={22} hint="عن الشهر الماضي" />
        <StatCard title="إجمالي الموردين" value="1,263" icon={<Briefcase size={18} />} trend={15} hint="عن الشهر الماضي" />
        <StatCard title="إجمالي الحجوزات" value="1,248" icon={<CalendarCheck size={18} />} trend={12} hint="عن الشهر الماضي" />
        <StatCard title="الإيرادات (هذا الشهر)" value="258,450" icon={<CreditCard size={18} />} trend={18} hint="عن الشهر الماضي" />
        <StatCard title="المدن" value="6" icon={<MapPin size={18} />} hint="مدن نشطة" />
        <StatCard title="الطلبات المعلقة" value="42" icon={<Clock size={18} />} trend={-8} hint="عن أمس" tone="danger" />
      </div>

      {/* الشبكة الوسطى: الترتيب الأفقي مطابق تماماً للتصميم */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1.4fr 1fr', gap: '24px', marginBottom: '24px' }}>
        
        {/* 1. طلبات الموردين (اليمن) */}
        <SectionCard
          title="طلبات الموردين الجديدة"
          actions={<Link to="/providers/applications" style={{ fontSize: '13px', color: '#8A7A81', textDecoration: 'none' }}>عرض الكل</Link>}
        >
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', height: '240px', overflowY: 'auto' }}>
            {mockPendingProviders.map((provider) => (
              <div key={provider.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', paddingBottom: '12px', borderBottom: '1px solid #F5F4F0' }}>
                
                {/* اليسار: شارة جديد والوقت أفقياً بجانب بعضهما */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                  <span style={{ fontSize: '10px', color: '#2D8A5D', background: '#E8F5E9', padding: '2px 8px', borderRadius: '4px', fontWeight: 600 }}>جديد</span>
                  <div style={{ fontSize: '11px', color: '#A1979C' }}>{provider.time}</div>
                </div>

                {/* اليمين: رص النص أولاً ثم الدائرة اللوجو على يسار النص ليتجه التدفق البرمجي لليمين بالكامل */}
                <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                  <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: '13px', fontWeight: 600, color: '#2B2A2A' }}>{provider.businessName}</div>
                    <div style={{ fontSize: '11px', color: '#8A7A81', marginTop: '2px' }}>{provider.category}</div>
                  </div>
                  <div style={{ width: '36px', height: '36px', borderRadius: '50%', background: '#1A1A1A', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#FFF', fontSize: '14px', fontWeight: 'bold', flexShrink: 0 }}>
                    {provider.businessName.charAt(0)}
                  </div>
                </div>

              </div>
            ))}
          </div>
          <Link to="/providers/applications" style={{ display: 'block', textAlign: 'center', marginTop: '12px', padding: '10px', background: '#FFF7FA', color: '#4A1525', borderRadius: '8px', fontWeight: 600, fontSize: '13px', textDecoration: 'none' }}>
            إدارة طلبات الموردين ‹
          </Link>
        </SectionCard>

        {/* 2. Activity / النشاط (المنتصف) */}
        <SectionCard 
          title="النشاط خلال آخر 30 يوماً"
          actions={
            <div style={{ display: 'flex', alignItems: 'center', gap: '4px', background: '#F5F4F0', padding: '4px 12px', borderRadius: '8px', fontSize: '12px', color: '#4A1525' }}>
              <span>آخر 30 يوماً</span>
              <ChevronDown size={14} />
            </div>
          }
        >
          <div style={{ height: '240px' }}>
            <MiniLineChart values={chartValues} label="النشاط" />
          </div>
        </SectionCard>

        {/* 3. توزيع الطلبات حسب الحالة (اليسار) */}
        <SectionCard title="توزيع الطلبات حسب الحالة">
          <div style={{ height: '240px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <MiniDonut value={1248} label="إجمالي الطلبات" data={donutData} />
          </div>
        </SectionCard>
      </div>

      {/* الشبكة السفلية: الحجوزات والإجراءات السريعة */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 2fr', gap: '24px' }}>
        
        {/* 1. إجراءات سريعة (اليمين) */}
        <SectionCard title="إجراءات سريعة">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            <Link to="/cities/new" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px', padding: '16px 8px', background: '#FFFDF9', border: '1px solid #EFECE6', borderRadius: '12px', color: '#4A1525', textAlign: 'center', textDecoration: 'none' }}>
              <MapPin size={24} color="#C79B3F" strokeWidth={1.5} />
              <span style={{ fontSize: '12px', fontWeight: 600, lineHeight: 1.3 }}>إضافة<br/>مدينة جديدة</span>
            </Link>
            <Link to="/providers/new" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px', padding: '16px 8px', background: '#FFFDF9', border: '1px solid #EFECE6', borderRadius: '12px', color: '#4A1525', textAlign: 'center', textDecoration: 'none' }}>
              <UserPlus size={24} color="#C79B3F" strokeWidth={1.5} />
              <span style={{ fontSize: '12px', fontWeight: 600, lineHeight: 1.3 }}>إضافة<br/>مورد جديد</span>
            </Link>
            <Link to="/reports" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px', padding: '16px 8px', background: '#FFFDF9', border: '1px solid #EFECE6', borderRadius: '12px', color: '#4A1525', textAlign: 'center', textDecoration: 'none' }}>
              <BarChart2 size={24} color="#C79B3F" strokeWidth={1.5} />
              <span style={{ fontSize: '12px', fontWeight: 600, lineHeight: 1.3 }}>إضافة<br/>التقارير</span>
            </Link>
            <Link to="/services/new" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '8px', padding: '16px 8px', background: '#FFFDF9', border: '1px solid #EFECE6', borderRadius: '12px', color: '#4A1525', textAlign: 'center', textDecoration: 'none' }}>
              <Gift size={24} color="#C79B3F" strokeWidth={1.5} />
              <span style={{ fontSize: '12px', fontWeight: 600, lineHeight: 1.3 }}>إضافة<br/>خدمة جديدة</span>
            </Link>
          </div>
          <button style={{ width: '100%', marginTop: '16px', padding: '12px', display: 'flex', justifyContent: 'center', alignItems: 'center', gap: '8px', background: '#FFFDF9', border: '1px solid #EFECE6', borderRadius: '12px', color: '#4A1525', fontWeight: 700, fontSize: '13px', cursor: 'pointer' }}>
             <Megaphone size={16} color="#4A1525" />
             إرسال إشعار جماعي
          </button>
        </SectionCard>

        {/* 2. أحدث الحجوزات (اليسار) */}
        <SectionCard
          title="أحدث الحجوزات"
          actions={<Link to="/bookings" style={{ fontSize: '13px', color: '#8A7A81', textDecoration: 'none' }}>عرض الكل</Link>}
        >
          <DataTable
            columns={['رقم الحجز', 'العميل', 'المورد', 'الخدمة', 'التاريخ', 'المبلغ', 'الحالة']}
            dense
            minWidth={550}
          >
            <tr>
              <td style={{ fontWeight: 700, color: '#4A1525' }}>#B-1256</td>
              <td>سارة محمد</td>
              <td>استديو بريق</td>
              <td>تصوير فوتوغرافي</td>
              <td>2025/05/23</td>
              <td style={{ fontWeight: 600 }}>12,500 ر.س</td>
              <td><StatusBadge status="ACTIVE" /></td>
            </tr>
            <tr>
              <td style={{ fontWeight: 700, color: '#4A1525' }}>#B-1255</td>
              <td>أحمد القحطاني</td>
              <td>زهور المملكة</td>
              <td>تنسيق زهور</td>
              <td>2025/05/22</td>
              <td style={{ fontWeight: 600 }}>8,750 ر.س</td>
              <td><StatusBadge status="PENDING_REVIEW" /></td>
            </tr>
            <tr>
              <td style={{ fontWeight: 700, color: '#4A1525' }}>#B-1254</td>
              <td>نورة عبدالرحمن</td>
              <td>قصر ورد</td>
              <td>قاعة + ضيافة</td>
              <td>2025/05/22</td>
              <td style={{ fontWeight: 600 }}>15,000 ر.س</td>
              <td><StatusBadge status="NEEDS_CHANGES" /></td>
            </tr>
            <tr>
              <td style={{ fontWeight: 700, color: '#4A1525' }}>#B-1253</td>
              <td>فهد السبيعي</td>
              <td>ليالي الطرب</td>
              <td>فرقة موسيقية</td>
              <td>2025/05/21</td>
              <td style={{ fontWeight: 600 }}>6,300 ر.س</td>
              <td><StatusBadge status="ACTIVE" /></td>
            </tr>
            <tr>
              <td style={{ fontWeight: 700, color: '#4A1525' }}>#B-1252</td>
              <td>ليلى العتيبي</td>
              <td>حلويات مرام</td>
              <td>كيك وحلويات</td>
              <td>2025/05/20</td>
              <td style={{ fontWeight: 600 }}>9,200 ر.س</td>
              <td><StatusBadge status="COMPLETED" /></td>
            </tr>
          </DataTable>
          <Link to="/bookings" style={{ display: 'block', textAlign: 'center', marginTop: '16px', color: '#8A7A81', fontWeight: 600, fontSize: '13px', textDecoration: 'none' }}>
            عرض كل الحجوزات ‹
          </Link>
        </SectionCard>
      </div>

    </section>
  );
}