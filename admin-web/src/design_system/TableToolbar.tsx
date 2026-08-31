import { ReactNode } from 'react';

type TableToolbarProps = {
  children: ReactNode;
  actions?: ReactNode;
};

export function TableToolbar({ children, actions }: TableToolbarProps) {
  return (
    <div className="table-toolbar">
      <div className="table-toolbar__filters">{children}</div>
      {actions ? <div className="table-toolbar__actions">{actions}</div> : null}
    </div>
  );
}
