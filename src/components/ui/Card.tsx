import React from 'react';
import { theme, type StatCardColor, formatCurrency } from '@/lib/theme';

/* ==========================================================================
   Card Component
   ========================================================================== */

interface CardProps {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
  padding?: 'none' | 'sm' | 'md' | 'lg';
  noPadding?: boolean;
}

const paddingStyles = {
  none: '',
  sm: 'p-4',
  md: 'p-6',
  lg: 'p-8',
};

export function Card({ 
  children, 
  className = '', 
  hover = false,
  padding = 'none',
  noPadding = false,
}: CardProps) {
  const actualPadding = noPadding ? 'none' : padding;
  
  return (
    <div
      className={`
        card
        ${paddingStyles[actualPadding]}
        ${hover ? 'card-hover cursor-pointer' : ''}
        ${className}
      `}
    >
      {children}
    </div>
  );
}

/* ==========================================================================
   Card Header Component
   ========================================================================== */

interface CardHeaderProps {
  title?: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
  children?: React.ReactNode;
}

export function CardHeader({ title, description, action, className = '', children }: CardHeaderProps) {
  return (
    <div className={`flex items-center justify-between p-6 border-b border-gray-100 ${className}`}>
      <div>
        {title ? (
          <>
            <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
            {description && <p className="text-sm text-gray-500 mt-1">{description}</p>}
          </>
        ) : (
          children
        )}
      </div>
      {action && <div>{action}</div>}
    </div>
  );
}

/* ==========================================================================
   Card Content Component
   ========================================================================== */

interface CardContentProps {
  children: React.ReactNode;
  className?: string;
}

export function CardContent({ children, className = '' }: CardContentProps) {
  return <div className={`p-6 ${className}`}>{children}</div>;
}

/* ==========================================================================
   Stat Card Component
   ========================================================================== */

interface StatCardProps {
  label: string;
  value: string | number;
  icon?: React.ReactNode;
  color?: StatCardColor;
  trend?: { value: number; label?: string };
  prefix?: string;
  suffix?: string;
  className?: string;
  isCurrency?: boolean;
}

export function StatCard({ 
  label, 
  value, 
  icon, 
  color = 'blue', 
  trend,
  prefix = '',
  suffix = '',
  className = '',
  isCurrency = true,
}: StatCardProps) {
  const colors = theme.statCard[color];
  
  // Format value based on type and isCurrency flag
  let displayValue: string;
  if (typeof value === 'number') {
    if (isCurrency) {
      displayValue = formatCurrency(value);
    } else {
      displayValue = `${prefix}${value.toLocaleString()}${suffix}`;
    }
  } else {
    displayValue = `${prefix}${value}${suffix}`;
  }

  return (
    <Card 
      className={`${colors.bg} ${colors.border} border ${className}`} 
      hover
      padding="md"
    >
      <div className="flex items-start justify-between">
        <div className="space-y-2">
          <p className={`text-sm font-medium ${colors.text} opacity-80`}>
            {label}
          </p>
          <p className="text-2xl font-bold text-gray-900">
            {displayValue}
          </p>
          {trend && (
            <div className="flex items-center gap-1">
              <span 
                className={`text-xs font-medium flex items-center gap-0.5 ${
                  trend.value >= 0 ? 'text-green-600' : 'text-red-600'
                }`}
              >
                {trend.value >= 0 ? '↑' : '↓'} {Math.abs(trend.value)}%
              </span>
              {trend.label && (
                <span className="text-xs text-gray-500">{trend.label}</span>
              )}
            </div>
          )}
        </div>
        {icon && (
          <div className={`${colors.icon} opacity-40`}>
            {icon}
          </div>
        )}
      </div>
    </Card>
  );
}

/* ==========================================================================
   Metric Card Component (Simpler variant)
   ========================================================================== */

interface MetricCardProps {
  label: string;
  value: string | number;
  color?: 'blue' | 'green' | 'yellow' | 'purple' | 'red' | 'indigo';
  className?: string;
}

const metricColors = {
  blue: 'border-l-blue-500 bg-white',
  green: 'border-l-green-500 bg-white',
  yellow: 'border-l-yellow-500 bg-white',
  purple: 'border-l-purple-500 bg-white',
  red: 'border-l-red-500 bg-white',
  indigo: 'border-l-indigo-500 bg-white',
};

export function MetricCard({ label, value, color = 'blue', className = '' }: MetricCardProps) {
  return (
    <div className={`rounded-lg shadow-sm p-4 border-l-4 ${metricColors[color]} ${className}`}>
      <p className="text-sm text-gray-600 font-medium">{label}</p>
      <p className="text-2xl font-bold text-gray-900 mt-1">
        {typeof value === 'number' ? value.toLocaleString() : value}
      </p>
    </div>
  );
}

/* ==========================================================================
   Empty State Component
   ========================================================================== */

interface EmptyStateProps {
  icon?: React.ReactNode;
  title: string;
  description?: string;
  action?: React.ReactNode;
  className?: string;
}

export function EmptyState({ icon, title, description, action, className = '' }: EmptyStateProps) {
  return (
    <div className={`text-center py-12 ${className}`}>
      {icon && <div className="text-gray-300 mb-4 flex justify-center">{icon}</div>}
      <h3 className="text-lg font-medium text-gray-900">{title}</h3>
      {description && <p className="text-gray-500 mt-1">{description}</p>}
      {action && <div className="mt-4">{action}</div>}
    </div>
  );
}
