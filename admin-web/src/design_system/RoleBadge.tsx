const roleMap: Record<string, { label: string; tone: string }> = {
  ADMIN: { label: 'إدارة', tone: 'gold' },
  PROVIDER: { label: 'مورد', tone: 'info' },
  USER: { label: 'مستخدم', tone: 'muted' },
};

export function RoleBadge({ role }: { role: string }) {
  const item = roleMap[role] ?? { label: role, tone: 'muted' };
  return <span className={`status-badge ${item.tone}`}>{item.label}</span>;
}
