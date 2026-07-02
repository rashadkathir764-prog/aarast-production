import {
  CartesianGrid,
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';

type MiniLineChartProps = {
  values: number[];
  label: string;
};

export function MiniLineChart({ values, label }: MiniLineChartProps) {
  const data = values.length
    ? values.map((value, index) => ({
        name: `${index + 1}`,
        users: value,
        quoteLeads: value,
      }))
    : [
        { name: '24 أبريل', users: 60, quoteLeads: 40 },
        { name: '1 مايو', users: 130, quoteLeads: 95 },
        { name: '8 مايو', users: 110, quoteLeads: 80 },
        { name: '15 مايو', users: 160, quoteLeads: 115 },
        { name: '22 مايو', users: 125, quoteLeads: 75 },
        { name: 'اليوم', users: 155, quoteLeads: 120 },
      ];

  const secondaryLabel = label.trim() || 'طلبات العروض';

  return (
    <div style={{ width: '100%', height: '100%', display: 'flex', flexDirection: 'column', gap: '12px' }}>
      <div style={{ display: 'flex', justifyContent: 'center', gap: '24px', fontSize: '12px', fontWeight: 500 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#5C5457' }}>
          <div style={{ width: '12px', height: '3px', borderRadius: '2px', background: '#4A1525' }} />
          <span>{secondaryLabel}</span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#5C5457' }}>
          <div style={{ width: '12px', height: '3px', borderRadius: '2px', background: '#C79B3F' }} />
          <span>المستخدمون</span>
        </div>
      </div>

      <div style={{ flex: 1, width: '100%', height: '200px' }}>
        <ResponsiveContainer width="100%" height="100%">
          <LineChart data={data} margin={{ top: 10, right: -10, left: -25, bottom: 0 }}>
            <CartesianGrid strokeDasharray="0" vertical={false} stroke="#F1EFEA" />
            <XAxis
              dataKey="name"
              axisLine={false}
              tickLine={false}
              tick={{ fontSize: 11, fill: '#A1979C', fontWeight: 500 }}
              dy={10}
            />
            <YAxis
              axisLine={false}
              tickLine={false}
              domain={[0, 200]}
              ticks={[0, 50, 100, 150, 200]}
              tick={{ fontSize: 11, fill: '#A1979C', fontWeight: 500 }}
            />
            <Tooltip
              contentStyle={{
                borderRadius: '8px',
                border: 'none',
                boxShadow: '0 2px 8px rgba(0,0,0,0.06)',
                fontFamily: 'inherit',
                fontSize: '12px',
              }}
            />
            <Line
              type="monotone"
              dataKey="quoteLeads"
              stroke="#4A1525"
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 5, strokeWidth: 0 }}
            />
            <Line
              type="monotone"
              dataKey="users"
              stroke="#C79B3F"
              strokeWidth={2}
              dot={false}
              activeDot={{ r: 5, strokeWidth: 0 }}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
