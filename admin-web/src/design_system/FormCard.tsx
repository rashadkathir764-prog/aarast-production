import { ReactNode } from 'react';
import { SectionCard } from './SectionCard';

type FormCardProps = {
  title: string;
  subtitle?: string;
  children: ReactNode;
};

export function FormCard({ title, subtitle, children }: FormCardProps) {
  return (
    <SectionCard title={title} subtitle={subtitle} className="form-card">
      {children}
    </SectionCard>
  );
}
