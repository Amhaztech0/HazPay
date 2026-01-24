import React from 'react';
import { ArrowLeft, RefreshCw, Download } from 'lucide-react';
import { Button } from './Button';

/* ==========================================================================
   Page Header Component
   ========================================================================== */

interface PageHeaderProps {
  title: string;
  description?: string;
  backHref?: string;
  onBack?: () => void;
  actions?: React.ReactNode;
  children?: React.ReactNode;
}

export function PageHeader({ 
  title, 
  description, 
  backHref, 
  onBack,
  actions,
  children 
}: PageHeaderProps) {
  return (
    <div className="space-y-4">
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div className="flex items-center gap-4">
          {(backHref || onBack) && (
            <Button
              variant="ghost"
              size="sm"
              onClick={onBack || (() => window.history.back())}
              icon={<ArrowLeft size={18} />}
              aria-label="Go back"
            />
          )}
          <div>
            <h1 className="text-2xl sm:text-3xl font-bold text-gray-900">{title}</h1>
            {description && (
              <p className="text-gray-500 mt-1 text-sm sm:text-base">{description}</p>
            )}
          </div>
        </div>
        {actions && (
          <div className="flex items-center gap-3 flex-wrap">
            {actions}
          </div>
        )}
      </div>
      {children}
    </div>
  );
}

/* ==========================================================================
   Page Actions (Common action buttons)
   ========================================================================== */

interface RefreshButtonProps {
  onClick: () => void;
  loading?: boolean;
  isLoading?: boolean; // Alias for loading
  lastUpdated?: Date | null;
}

export function RefreshButton({ onClick, loading, isLoading, lastUpdated }: RefreshButtonProps) {
  const isSpinning = loading || isLoading;
  
  return (
    <div className="flex items-center gap-2">
      {lastUpdated && (
        <span className="text-xs text-gray-500 hidden sm:inline">
          Updated {lastUpdated.toLocaleTimeString()}
        </span>
      )}
      <Button
        variant="ghost"
        size="sm"
        onClick={onClick}
        loading={isSpinning}
        icon={<RefreshCw size={16} className={isSpinning ? 'animate-spin' : ''} />}
        aria-label="Refresh data"
      >
        Refresh
      </Button>
    </div>
  );
}

interface ExportButtonProps {
  onClick: () => void;
  loading?: boolean;
  label?: string;
}

export function ExportButton({ onClick, loading, label = 'Export CSV' }: ExportButtonProps) {
  return (
    <Button
      variant="primary"
      size="sm"
      onClick={onClick}
      loading={loading}
      icon={<Download size={16} />}
    >
      {label}
    </Button>
  );
}

/* ==========================================================================
   Filter Bar Component
   ========================================================================== */

interface FilterBarProps {
  children: React.ReactNode;
  className?: string;
}

export function FilterBar({ children, className = '' }: FilterBarProps) {
  return (
    <div className={`card p-4 ${className}`}>
      <div className="flex flex-col md:flex-row md:items-center gap-4">
        {children}
      </div>
    </div>
  );
}

/* ==========================================================================
   Results Count Component
   ========================================================================== */

interface ResultsCountProps {
  count: number;
  label?: string;
}

export function ResultsCount({ count, label = 'result' }: ResultsCountProps) {
  return (
    <div className="flex items-center justify-center px-4 py-2 bg-gray-50 rounded-lg">
      <span className="text-sm text-gray-600 font-medium">
        {count.toLocaleString()} {label}{count !== 1 ? 's' : ''}
      </span>
    </div>
  );
}

/* ==========================================================================
   Page Section Component
   ========================================================================== */

interface PageSectionProps {
  title?: string;
  description?: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
}

export function PageSection({ title, description, action, children, className = '' }: PageSectionProps) {
  return (
    <section className={`space-y-4 ${className}`}>
      {(title || action) && (
        <div className="flex items-center justify-between">
          <div>
            {title && <h2 className="text-xl font-semibold text-gray-900">{title}</h2>}
            {description && <p className="text-sm text-gray-500 mt-0.5">{description}</p>}
          </div>
          {action}
        </div>
      )}
      {children}
    </section>
  );
}
