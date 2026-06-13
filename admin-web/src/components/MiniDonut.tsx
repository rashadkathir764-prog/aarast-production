import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';

type MiniDonutProps = {
  value: number; // total
  label: string;
  data: { name: string; value: number; color: string }[];
};

export function MiniDonut({ value, label, data }: MiniDonutProps) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: '24px', width: '100%', height: '100%' }}>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '12px' }}>
        {data.map((entry, index) => (
          <div key={`legend-${index}`} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '13px' }}>
            <span style={{ color: 'var(--color-muted)', fontWeight: 600 }}>{entry.name}</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
              <span style={{ fontWeight: 700 }}>{Math.round((entry.value / Math.max(1, value)) * 100)}% ({entry.value})</span>
              <div style={{ width: '8px', height: '8px', borderRadius: '50%', background: entry.color }}></div>
            </div>
          </div>
        ))}
      </div>
      <div style={{ position: 'relative', width: '180px', height: '180px' }}>
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              innerRadius={65}
              outerRadius={85}
              paddingAngle={5}
              dataKey="value"
              stroke="none"
              cornerRadius={4}
            >
              {data.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.color} />
              ))}
            </Pie>
            <Tooltip contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }} />
          </PieChart>
        </ResponsiveContainer>
        <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', pointerEvents: 'none' }}>
          <div style={{ textAlign: 'center' }}>
            <strong style={{ display: 'block', fontSize: '24px', color: 'var(--color-burgundy-950)', lineHeight: 1 }}>{value.toLocaleString()}</strong>
            <span style={{ fontSize: '11px', color: 'var(--color-muted)', fontWeight: 700 }}>إجمالي الطلبات</span>
          </div>
        </div>
      </div>
    </div>
  );
}
