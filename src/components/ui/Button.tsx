import React from 'react';

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'success' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  loading?: boolean;
  icon?: React.ReactNode;
}

const variantStyles = {
  primary: 'bg-blue-600 text-white hover:bg-blue-700 active:bg-blue-800',
  secondary: 'bg-gray-200 text-gray-900 hover:bg-gray-300 active:bg-gray-400',
  danger: 'bg-red-600 text-white hover:bg-red-700 active:bg-red-800',
  success: 'bg-green-600 text-white hover:bg-green-700 active:bg-green-800',
  ghost: 'bg-transparent text-gray-700 hover:bg-gray-100 active:bg-gray-200',
};

const sizeStyles = {
  sm: 'px-3 py-1.5 text-sm rounded-lg',
  md: 'px-4 py-2 text-sm rounded-lg',
  lg: 'px-6 py-3 text-base rounded-lg',
};

export function Button({
  variant = 'primary',
  size = 'md',
  loading = false,
  icon,
  children,
  disabled,
  className = '',
  ...props
}: ButtonProps) {
  return (
    <button
      disabled={disabled || loading}
      className={`
        inline-flex items-center gap-2 font-medium transition-all duration-200
        ${variantStyles[variant]}
        ${sizeStyles[size]}
        disabled:opacity-50 disabled:cursor-not-allowed
        ${className}
      `}
      {...props}
    >
      {loading && <div className="w-4 h-4 border-2 border-current border-t-transparent rounded-full animate-spin" />}
      {icon && !loading && icon}
      {children}
    </button>
  );
}

interface BadgeProps {
  color?: 'blue' | 'green' | 'red' | 'amber' | 'purple';
  children: React.ReactNode;
  className?: string;
}

const badgeColors = {
  blue: 'bg-blue-100 text-blue-700',
  green: 'bg-green-100 text-green-700',
  red: 'bg-red-100 text-red-700',
  amber: 'bg-amber-100 text-amber-700',
  purple: 'bg-purple-100 text-purple-700',
};

export function Badge({ color = 'blue', children, className = '' }: BadgeProps) {
  return <span className={`px-3 py-1 rounded-full text-xs font-medium ${badgeColors[color]} ${className}`}>{children}</span>;
}

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
}

export function Input({ label, error, className = '', ...props }: InputProps) {
  return (
    <div className="flex flex-col gap-1.5">
      {label && <label className="text-sm font-medium text-gray-700">{label}</label>}
      <input
        className={`
          px-4 py-2 rounded-lg border border-gray-300
          focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100
          transition-colors duration-200
          ${error ? 'border-red-500 focus:ring-red-100' : ''}
          ${className}
        `}
        {...props}
      />
      {error && <span className="text-xs text-red-600">{error}</span>}
    </div>
  );
}

interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  options: Array<{ value: string | number; label: string }>;
}

export function Select({ label, options, className = '', ...props }: SelectProps) {
  return (
    <div className="flex flex-col gap-1.5">
      {label && <label className="text-sm font-medium text-gray-700">{label}</label>}
      <select
        className={`
          px-4 py-2 rounded-lg border border-gray-300
          focus:outline-none focus:border-blue-500 focus:ring-2 focus:ring-blue-100
          transition-colors duration-200
          bg-white
          ${className}
        `}
        {...props}
      >
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  );
}
