import React from 'react';

export default function StatusBadge({ status, size = 'sm' }) {
  if (!status) return null;

  const normalized = String(status).toLowerCase().trim();

  let colorClasses = 'bg-surface-container text-on-surface-variant';
  let label = status;

  switch (normalized) {
    case 'placed':
      colorClasses = 'bg-primary-fixed text-on-primary-fixed';
      label = 'Placed';
      break;
    case 'preparing':
      colorClasses = 'bg-secondary-container text-on-secondary-container';
      label = 'Preparing';
      break;
    case 'ready_for_pickup':
      colorClasses = 'bg-tertiary-fixed text-on-tertiary-fixed';
      label = 'Ready for Pickup';
      break;
    case 'active':
      colorClasses = 'bg-primary-container text-on-primary-container';
      label = 'Active';
      break;
    case 'delivered':
    case 'completed':
      colorClasses = 'bg-tertiary-container text-on-tertiary-container';
      label = 'Delivered';
      break;
    case 'refund_pending':
      colorClasses = 'bg-error-container text-on-error-container';
      label = 'Refund Pending';
      break;
    case 'cancelled':
    case 'rejected':
      colorClasses = 'bg-error text-on-error';
      label = normalized === 'rejected' ? 'Rejected' : 'Cancelled';
      break;

    case 'awaiting_review':
    case 'refund_requested':
      colorClasses = 'bg-secondary-fixed text-on-secondary-fixed';
      label = normalized === 'awaiting_review' ? 'Awaiting Review' : 'Requested';
      break;
    case 'refund_under_review':
    case 'under_review':
      colorClasses = 'bg-primary-fixed text-on-primary-fixed';
      label = 'Under Review';
      break;
    case 'approved':
      colorClasses = 'bg-tertiary-fixed text-on-tertiary-fixed';
      label = 'Approved';
      break;
    case 'credited':
      colorClasses = 'bg-tertiary-container text-on-tertiary-container';
      label = 'Credited';
      break;

    case 'available':
    case 'in_stock':
    case 'true':
      colorClasses = 'bg-tertiary-container text-on-tertiary-container';
      label = 'Available';
      break;
    case 'unavailable':
    case 'out_of_stock':
    case 'false':
      colorClasses = 'bg-error-container text-on-error-container';
      label = 'Unavailable';
      break;

    case 'ready':
      colorClasses = 'bg-tertiary-container text-on-tertiary-container';
      label = 'Ready';
      break;
    case 'pending':
      colorClasses = 'bg-surface-container-high text-on-surface-variant';
      label = 'Pending';
      break;

    default:
      label = status.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());
  }

  const sizeClasses =
    size === 'xs'
      ? 'px-1.5 py-0.5 text-[10px]'
      : size === 'md'
      ? 'px-3 py-1 text-[13px]'
      : 'px-2 py-0.5 text-label-caps';

  return (
    <span
      className={`inline-flex items-center gap-1 font-label-caps uppercase tracking-wider rounded-full font-bold ${sizeClasses} ${colorClasses}`}
    >
      <span className="w-1.5 h-1.5 rounded-full bg-current opacity-70"></span>
      {label}
    </span>
  );
}
