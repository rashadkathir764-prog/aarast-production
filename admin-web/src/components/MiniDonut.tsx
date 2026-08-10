import { Cell, Pie, PieChart, ResponsiveContainer, Tooltip } from 'recharts';

type MiniDonutProps = {
  value: number;
  label: string;
  data: { name: string; value: number; color: string }[];
};

export function MiniDonut({ value, label, data }: MiniDonutProps) {
  return (
    <div className="mini-donut-chart">
      <div className="mini-donut-chart__visual">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              innerRadius={52}
              outerRadius={72}
              paddingAngle={3}
              dataKey="value"
              stroke="var(--surface)"
              strokeWidth={2}
              cornerRadius={3}
            >
              {data.map((entry) => (
                <Cell key={entry.name} fill={entry.color} />
              ))}
            </Pie>
            <Tooltip />
          </PieChart>
        </ResponsiveContainer>
        <div className="mini-donut-chart__center">
          <strong>{value.toLocaleString()}</strong>
          <span>{label}</span>
        </div>
      </div>

      <ul className="mini-donut-chart__legend">
        {data.map((entry) => {
          const percentage = value > 0 ? Math.round((entry.value / value) * 100) : 0;

          return (
            <li key={entry.name}>
              <span className="mini-donut-chart__legend-label">
                <i aria-hidden="true" style={{ backgroundColor: entry.color }} />
                {entry.name}
              </span>
              <bdi>
                {entry.value} · {percentage}%
              </bdi>
            </li>
          );
        })}
      </ul>
    </div>
  );
}
