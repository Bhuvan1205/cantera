import React from 'react';

export function Alert({ type = 'error', message, title, onClose }) {
  if (!message) return null;

  let bgClass = 'bg-error-container text-on-error-container border-error/30';
  let icon = 'error';

  if (type === 'success') {
    bgClass = 'bg-tertiary-container/20 text-tertiary border-tertiary/30';
    icon = 'check_circle';
  } else if (type === 'info') {
    bgClass = 'bg-primary-fixed/40 text-primary border-primary/20';
    icon = 'info';
  } else if (type === 'warning') {
    bgClass = 'bg-secondary-fixed/50 text-on-secondary-fixed border-secondary/30';
    icon = 'warning';
  }

  return (
    <div className={`p-md rounded-xl border flex items-start gap-sm shadow-sm ${bgClass}`}>
      <span className="material-symbols-outlined text-[20px] flex-shrink-0 mt-0.5">{icon}</span>
      <div className="flex-1 text-body-sm">
        {title && <p className="font-bold mb-0.5">{title}</p>}
        <p>{message}</p>
      </div>
      {onClose && (
        <button onClick={onClose} className="opacity-70 hover:opacity-100 p-0.5 rounded">
          <span className="material-symbols-outlined text-[16px]">close</span>
        </button>
      )}
    </div>
  );
}

export function LoadingSpinner({ text = 'Loading data...', size = 'md' }) {
  return (
    <div className="flex flex-col items-center justify-center p-xl gap-sm text-on-surface-variant">
      <span className="material-symbols-outlined animate-spin text-[32px] text-primary">
        refresh
      </span>
      {text && <p className="font-body-sm text-on-surface-variant font-medium">{text}</p>}
    </div>
  );
}

export function EmptyState({ icon = 'inbox', title = 'No records found', description = 'There is currently no data to display.', action }) {
  return (
    <div className="flex flex-col items-center justify-center py-xl px-lg text-center text-on-surface-variant/80">
      <div className="w-16 h-16 rounded-full bg-surface-container flex items-center justify-center mb-md">
        <span className="material-symbols-outlined text-[32px] opacity-60 text-outline">{icon}</span>
      </div>
      <h3 className="font-title-sm text-on-surface mb-xs">{title}</h3>
      <p className="font-body-sm max-w-sm mb-md text-on-surface-variant">{description}</p>
      {action && <div>{action}</div>}
    </div>
  );
}
