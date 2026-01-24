import React from 'react';
import { ChevronUp, ChevronDown, ChevronsUpDown } from 'lucide-react';
import { EmptyState } from './Card';

/* ==========================================================================
   Data Table Component
   ========================================================================== */

export interface Column<T> {
  key: string;
  header: string;
  sortable?: boolean;
  width?: string;
  align?: 'left' | 'center' | 'right';
  render?: (value: unknown, row: T, index: number) => React.ReactNode;
  className?: string;
}

interface DataTableProps<T extends { id?: string | number }> {
  columns: Column<T>[];
  data: T[];
  sortField?: string;
  sortOrder?: 'asc' | 'desc';
  onSort?: (field: string) => void;
  isLoading?: boolean;
  emptyTitle?: string;
  emptyDescription?: string;
  emptyIcon?: React.ReactNode;
  className?: string;
  rowKey?: keyof T | ((row: T) => string | number);
  onRowClick?: (row: T) => void;
  stickyHeader?: boolean;
}

export function DataTable<T extends { id?: string | number }>({
  columns,
  data,
  sortField,
  sortOrder,
  onSort,
  isLoading = false,
  emptyTitle = 'No data found',
  emptyDescription,
  emptyIcon,
  className = '',
  rowKey = 'id',
  onRowClick,
  stickyHeader = false,
}: DataTableProps<T>) {
  const getRowKey = (row: T, index: number): string | number => {
    if (typeof rowKey === 'function') {
      return rowKey(row);
    }
    return (row[rowKey] as string | number) ?? index;
  };

  const alignmentClasses = {
    left: 'text-left',
    center: 'text-center',
    right: 'text-right',
  };

  if (isLoading) {
    return <TableSkeleton columns={columns.length} rows={5} />;
  }

  return (
    <div className={`table-container ${className}`}>
      <table className="table">
        <thead className={stickyHeader ? 'sticky top-0 z-10' : ''}>
          <tr>
            {columns.map((column) => (
              <th
                key={column.key}
                onClick={() => column.sortable && onSort?.(column.key)}
                className={`
                  ${alignmentClasses[column.align || 'left']}
                  ${column.sortable ? 'cursor-pointer hover:bg-gray-100 select-none' : ''}
                  ${column.width ? `w-[${column.width}]` : ''}
                  ${column.className || ''}
                `}
              >
                <div className={`flex items-center gap-2 ${column.align === 'right' ? 'justify-end' : column.align === 'center' ? 'justify-center' : ''}`}>
                  {column.header}
                  {column.sortable && (
                    <SortIndicator
                      active={sortField === column.key}
                      direction={sortField === column.key ? sortOrder : undefined}
                    />
                  )}
                </div>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.length === 0 ? (
            <tr>
              <td colSpan={columns.length} className="px-6 py-12">
                <EmptyState
                  icon={emptyIcon}
                  title={emptyTitle}
                  description={emptyDescription}
                />
              </td>
            </tr>
          ) : (
            data.map((row, rowIndex) => (
              <tr
                key={getRowKey(row, rowIndex)}
                onClick={() => onRowClick?.(row)}
                className={onRowClick ? 'cursor-pointer' : ''}
              >
                {columns.map((column) => {
                  const value = (row as Record<string, unknown>)[column.key];
                  return (
                    <td
                      key={column.key}
                      className={`
                        ${alignmentClasses[column.align || 'left']}
                        ${column.className || ''}
                      `}
                    >
                      {column.render ? column.render(value, row, rowIndex) : (value as React.ReactNode)}
                    </td>
                  );
                })}
              </tr>
            ))
          )}
        </tbody>
      </table>
    </div>
  );
}

/* ==========================================================================
   Sort Indicator Component
   ========================================================================== */

interface SortIndicatorProps {
  active: boolean;
  direction?: 'asc' | 'desc';
}

function SortIndicator({ active, direction }: SortIndicatorProps) {
  if (!active) {
    return <ChevronsUpDown size={14} className="text-gray-400" />;
  }
  
  return direction === 'asc' 
    ? <ChevronUp size={14} className="text-blue-600" />
    : <ChevronDown size={14} className="text-blue-600" />;
}

/* ==========================================================================
   Table Skeleton Component
   ========================================================================== */

interface TableSkeletonProps {
  columns: number;
  rows: number;
}

export function TableSkeleton({ columns, rows }: TableSkeletonProps) {
  return (
    <div className="table-container">
      <table className="table">
        <thead>
          <tr>
            {Array.from({ length: columns }).map((_, i) => (
              <th key={i}>
                <div className="skeleton h-4 w-24" />
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {Array.from({ length: rows }).map((_, rowIndex) => (
            <tr key={rowIndex}>
              {Array.from({ length: columns }).map((_, colIndex) => (
                <td key={colIndex}>
                  <div className="skeleton h-4 w-full max-w-[120px]" />
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

/* ==========================================================================
   Status Cell Component
   ========================================================================== */

interface StatusCellProps {
  status: string;
  variant?: 'badge' | 'dot';
}

const statusVariants: Record<string, { badge: string; dotColor: string }> = {
  success: { badge: 'badge-success', dotColor: 'bg-green-500' },
  completed: { badge: 'badge-success', dotColor: 'bg-green-500' },
  active: { badge: 'badge-success', dotColor: 'bg-green-500' },
  approved: { badge: 'badge-success', dotColor: 'bg-green-500' },
  repaid: { badge: 'badge-success', dotColor: 'bg-green-500' },
  pending: { badge: 'badge-warning', dotColor: 'bg-yellow-500' },
  processing: { badge: 'badge-warning', dotColor: 'bg-yellow-500' },
  failed: { badge: 'badge-danger', dotColor: 'bg-red-500' },
  cancelled: { badge: 'badge-danger', dotColor: 'bg-red-500' },
  defaulted: { badge: 'badge-danger', dotColor: 'bg-red-500' },
  suspended: { badge: 'badge-danger', dotColor: 'bg-red-500' },
};

export function StatusCell({ status, variant = 'badge' }: StatusCellProps) {
  const normalizedStatus = status.toLowerCase();
  const styles = statusVariants[normalizedStatus] || { badge: 'badge', dotColor: 'bg-gray-500' };

  if (variant === 'dot') {
    return (
      <>
        <span className={`w-2 h-2 rounded-full ${styles.dotColor} inline-block`} />
        <span className="text-sm capitalize ml-2 inline">{status}</span>
      </>
    );
  }

  return (
    <span className={`badge ${styles.badge}`}>
      {status}
    </span>
  );
}

/* ==========================================================================
   Currency Cell Component
   ========================================================================== */

interface CurrencyCellProps {
  amount: number;
  currency?: string;
  colored?: boolean;
  className?: string;
}

export function CurrencyCell({ amount, currency = '₦' }: CurrencyCellProps) {
  if (amount === null || amount === undefined) {
    return <>-</>;
  }
  const formattedAmount = `${currency}${amount.toLocaleString()}`;
  return <>{formattedAmount}</>;
}

/* ==========================================================================
   Date Cell Component
   ========================================================================== */

interface DateCellProps {
  date: string | Date;
  format?: 'full' | 'short' | 'relative';
  className?: string;
}

export function DateCell({ date, format = 'full' }: DateCellProps) {
  if (!date) {
    return <>-</>;
  }
  const dateObj = new Date(date);
  
  let formatted: string;
  
  switch (format) {
    case 'short':
      formatted = dateObj.toLocaleDateString('en-NG', { month: 'short', day: 'numeric' });
      break;
    case 'relative':
      formatted = getRelativeTime(dateObj);
      break;
    default:
      formatted = dateObj.toLocaleString('en-NG', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      });
  }
  
  return <>{formatted}</>;
}

function getRelativeTime(date: Date): string {
  const now = new Date();
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000);
  
  if (diffInSeconds < 60) return 'Just now';
  if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}m ago`;
  if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}h ago`;
  if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}d ago`;
  
  return date.toLocaleDateString('en-NG', { month: 'short', day: 'numeric' });
}
