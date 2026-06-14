import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';

type MiniDonutProps = {
  value: number;
  label: string;
  data: { name: string; value: number; color: string }[];
};

export function MiniDonut({ value, label, data }: MiniDonutProps) {
  return (
    <div 
      style={{ 
        display: 'flex', 
        alignItems: 'center', 
        justifyContent: 'space-between', 
        width: '100%', 
        height: '100%',
        gap: '16px'
      }}
    >
      {/* 1. الرسم البياني الدائري في اليمين */}
      <div style={{ position: 'relative', width: '150px', height: '150px', flexShrink: 0 }}>
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              innerRadius={52}
              outerRadius={72}
              paddingAngle={3}
              dataKey="value"
              stroke="#ffffff"
              strokeWidth={2}
              cornerRadius={3}
            >
              {data.map((entry, index) => (
                <Cell key={`cell-${index}`} fill={entry.color} />
              ))}
            </Pie>
            <Tooltip 
              contentStyle={{ 
                borderRadius: '8px', 
                border: 'none', 
                boxShadow: '0 2px 8px rgba(0,0,0,0.08)',
                fontSize: '12px'
              }} 
            />
          </PieChart>
        </ResponsiveContainer>
        
        <div style={{ position: 'absolute', inset: 0, display: 'grid', placeItems: 'center', pointerEvents: 'none' }}>
          <div style={{ textAlign: 'center' }}>
            <strong style={{ display: 'block', fontSize: '22px', fontWeight: 700, color: '#4A1525', lineHeight: 1.1 }}>
              {value.toLocaleString()}
            </strong>
            <span style={{ fontSize: '10px', color: '#8A7A81', fontWeight: 500, marginTop: '2px', display: 'block' }}>
              {label}
            </span>
          </div>
        </div>
      </div>

      {/* 2. القائمة التوضيحية المحدثة بالملي (النقطة والنسبة يمين، والاسم يسار) */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '10px' }}>
        {data.map((entry, index) => {
          const percentage = value > 0 ? Math.round((entry.value / value) * 100) : 0;
          
          return (
            <div 
              key={`legend-${index}`} 
              style={{ 
                display: 'flex', 
                alignItems: 'center', 
                justifyContent: 'space-between', 
                width: '100%',
                fontSize: '12px'
              }}
            >
              {/* اليمين: النقطة الملونة تليها النسبة والعدد */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '6px' }}>
                <div 
                  style={{ 
                    width: '6px', 
                    height: '6px', 
                    borderRadius: '50%', 
                    background: entry.color,
                    flexShrink: 0
                  }}
                />
                <span style={{ color: '#2B2A2A', fontWeight: 500, direction: 'ltr' }}>
                  {percentage}% ({entry.value})
                </span>
              </div>

              {/* اليسار: اسم الحالة */}
              <span style={{ color: '#5C5457', fontWeight: 500 }}>
                {entry.name}
              </span>
            </div>
          );
        })}
      </div>

    </div>
  );
}