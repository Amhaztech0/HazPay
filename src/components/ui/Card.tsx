import React from 'react';

interface CardProps {
  children: React.ReactNode;
  className?: string;
  hover?: boolean;
  gradient?: boolean;
}

export function Card({ children, className = '', hover = false, gradient = false }: CardProps) {
  return (
    <div
      className={`
        rounded-xl shadow-md border border-gray-200
        ${gradient ? 'bg-gradient-to-br from-white to-gray-50' : 'bg-white'}
        ${hover ? 'transition-all duration-300 hover:shadow-lg hover:border-gray-300' : ''}
        ${className}
      `}
    >
      {children}
    </div>
  );
}

interface StatCardProps {
  label: string;
  value: string | number;
  icon?: React.ReactNode;
  color?: 'blue' | 'green' | 'purple' | 'amber' | 'red';
  trend?: number;
  className?: string;
}

const colorMap = {
  blue: { bg: 'bg-blue-50', border: 'border-blue-200', text: 'text-blue-600', icon: 'text-blue-300' },
  green: { bg: 'bg-green-50', border: 'border-green-200', text: 'text-green-600', icon: 'text-green-300' },
  purple: { bg: 'bg-purple-50', border: 'border-purple-200', text: 'text-purple-600', icon: 'text-purple-300' },
  amber: { bg: 'bg-amber-50', border: 'border-amber-200', text: 'text-amber-600', icon: 'text-amber-300' },
  red: { bg: 'bg-red-50', border: 'border-red-200', text: 'text-red-600', icon: 'text-red-300' },
};

export function StatCard({ label, value, icon, color = 'blue', trend, className = '' }: StatCardProps) {
  const colors = colorMap[color];
  return (
    <Card className={`${colors.bg} ${colors.border} border p-6 ${className}`} hover>
      <div className="flex items-center justify-between">
        <div>
          <p className={`text-sm font-medium ${colors.text} opacity-75`}>{label}</p>
          <p className="text-3xl font-bold text-gray-900 mt-3">
            {typeof value === 'number' && label.includes('₦') ? `₦${value.toLocaleString()}` : value.toLocaleString()}
          </p>
          {trend !== undefined && (
            <p className={`text-xs mt-2 font-medium ${trend >= 0 ? 'text-green-600' : 'text-red-600'}`}>
              {trend >= 0 ? '↑' : '↓'} {Math.abs(trend)}%
            </p>
          )}
        </div>
        {icon && <div className={`${colors.icon} text-4xl opacity-20`}>{icon as React.ReactNode}</div>}
      </div>
    </Card>
  );
}
