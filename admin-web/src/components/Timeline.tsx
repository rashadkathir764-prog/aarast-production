type TimelineItem = {
  title: string;
  caption?: string;
  tone?: 'success' | 'warning' | 'danger' | 'gold' | 'muted';
};

export function Timeline({ items }: { items: TimelineItem[] }) {
  return (
    <ol className="timeline">
      {items.map((item) => (
        <li className={`tone-${item.tone ?? 'muted'}`} key={item.title}>
          <strong>{item.title}</strong>
          {item.caption ? <span>{item.caption}</span> : null}
        </li>
      ))}
    </ol>
  );
}
