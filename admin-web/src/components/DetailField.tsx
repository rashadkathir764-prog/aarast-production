import { ReactNode } from 'react';

type DetailFieldProps = {
  label: string;
  children: ReactNode;
};

export function DetailField({ label, children }: DetailFieldProps) {
  return (
    <div className="detail-field">
      <span>{label}</span>
      <strong>{children}</strong>
    </div>
  );
}
