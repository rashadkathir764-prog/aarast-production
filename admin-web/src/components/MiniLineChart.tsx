import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';

type MiniLineChartProps = {
  values: number[];
  label: string;
};

export function MiniLineChart({ values, label }: MiniLineChartProps) {
  // Generate dummy data based on values to match the design visually
  const data = values.map((val, i) => ({
    name: `${i * 3 + 1} مايو`,
    users: val + Math.floor(Math.random() * 20),
    bookings: Math.floor(val * 0.6) + Math.floor(Math.random() * 10),
  }));

  return (
    <div style={{ width: '100%', height: 260 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '16px' }}>
        <select style={{ padding: '4px 12px', borderRadius: '12px', border: '1px solid rgba(74, 7, 31, 0.1)', background: '#fff' }}>
          <option>آخر 30 يوماً</option>
          <option>آخر 7 أيام</option>
        </select>
        <div style={{ display: 'flex', gap: '16px', fontSize: '13px', fontWeight: 600 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><div style={{ width: '12px', height: '2px', background: 'var(--color-burgundy-800)' }}></div> المستخدمون</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}><div style={{ width: '12px', height: '2px', background: 'var(--color-gold-500)' }}></div> الحجوزات</div>
        </div>
      </div>
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={data} margin={{ top: 5, right: 0, left: -20, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="rgba(0,0,0,0.06)" />
          <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: 'var(--color-muted)' }} dy={10} />
          <YAxis axisLine={false} tickLine={false} tick={{ fontSize: 12, fill: 'var(--color-muted)' }} />
          <Tooltip 
            contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}
          />
          <Line type="monotone" dataKey="users" stroke="var(--color-burgundy-800)" strokeWidth={3} dot={{ r: 4, fill: 'var(--color-burgundy-800)', strokeWidth: 2, stroke: '#fff' }} activeDot={{ r: 6 }} />
          <Line type="monotone" dataKey="bookings" stroke="var(--color-gold-500)" strokeWidth={3} dot={{ r: 4, fill: 'var(--color-gold-500)', strokeWidth: 2, stroke: '#fff' }} />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
