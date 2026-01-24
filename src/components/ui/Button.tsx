import React from 'react';
import { Loader2 } from 'lucide-react';

/* ==========================================================================
   Button Component
   ========================================================================== */

interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: 'primary' | 'secondary' | 'danger' | 'success' | 'ghost' | 'outline';
  size?: 'xs' | 'sm' | 'md' | 'lg';
  loading?: boolean;
  icon?: React.ReactNode;
  iconPosition?: 'left' | 'right';
  fullWidth?: boolean;
}

const variantStyles = {
  primary: 'bg-[var(--color-primary)] text-white hover:bg-[var(--color-primary-dark)] active:bg-[var(--color-primary-700)] shadow-sm',
  secondary: 'bg-gray-100 text-gray-900 hover:bg-gray-200 active:bg-gray-300',
  danger: 'bg-[var(--color-danger)] text-white hover:bg-[var(--color-danger-dark)] active:bg-red-800 shadow-sm',
  success: 'bg-[var(--color-success)] text-white hover:bg-[var(--color-success-dark)] active:bg-green-800 shadow-sm',
  ghost: 'bg-transparent text-gray-600 hover:bg-gray-100 hover:text-gray-900 active:bg-gray-200',
  outline: 'bg-transparent border-2 border-gray-300 text-gray-700 hover:border-gray-400 hover:bg-gray-50',
};

const sizeStyles = {
  xs: 'px-2 py-1 text-xs rounded',
  sm: 'px-3 py-1.5 text-sm rounded-md',
  md: 'px-4 py-2 text-sm rounded-lg',
  lg: 'px-6 py-3 text-base rounded-lg',
};

export function Button({
  variant = 'primary',
  size = 'md',
  loading = false,
  icon,
  iconPosition = 'left',
  fullWidth = false,
  children,
  disabled,
  className = '',
  ...props
}: ButtonProps) {
  const isDisabled = disabled || loading;
  
  return (
    <button
      disabled={isDisabled}
      className={`
        inline-flex items-center justify-center gap-2 font-medium 
        transition-all duration-150 ease-in-out
        ${variantStyles[variant]}
        ${sizeStyles[size]}
        ${fullWidth ? 'w-full' : ''}
        ${isDisabled ? 'opacity-50 cursor-not-allowed' : ''}
        ${className}
      `}
      {...props}
    >
      {loading && <Loader2 className="w-4 h-4 animate-spin" />}
      {icon && !loading && iconPosition === 'left' && icon}
      {children}
      {icon && !loading && iconPosition === 'right' && icon}
    </button>
  );
}

/* ==========================================================================
   Icon Button Component
   ========================================================================== */

interface IconButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  icon: React.ReactNode;
  variant?: 'primary' | 'secondary' | 'danger' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  'aria-label': string;
}

const iconButtonSizes = {
  sm: 'w-8 h-8',
  md: 'w-10 h-10',
  lg: 'w-12 h-12',
};

export function IconButton({
  icon,
  variant = 'ghost',
  size = 'md',
  className = '',
  ...props
}: IconButtonProps) {
  return (
    <button
      className={`
        inline-flex items-center justify-center rounded-lg
        transition-all duration-150 ease-in-out
        ${variantStyles[variant]}
        ${iconButtonSizes[size]}
        ${className}
      `}
      {...props}
    >
      {icon}
    </button>
  );
}

/* ==========================================================================
   Badge Component
   ========================================================================== */

interface BadgeProps {
  variant?: 'default' | 'success' | 'warning' | 'danger' | 'info' | 'purple';
  size?: 'sm' | 'md';
  dot?: boolean;
  children: React.ReactNode;
  className?: string;
  color?: string; // Custom color override
  style?: React.CSSProperties; // Custom styles
}

const badgeVariants = {
  default: 'bg-gray-100 text-gray-700 border-gray-200',
  success: 'bg-green-50 text-green-700 border-green-200',
  warning: 'bg-yellow-50 text-yellow-700 border-yellow-200',
  danger: 'bg-red-50 text-red-700 border-red-200',
  info: 'bg-blue-50 text-blue-700 border-blue-200',
  purple: 'bg-purple-50 text-purple-700 border-purple-200',
};

const badgeSizes = {
  sm: 'px-2 py-0.5 text-xs',
  md: 'px-3 py-1 text-xs',
};

const dotColors = {
  default: 'bg-gray-500',
  success: 'bg-green-500',
  warning: 'bg-yellow-500',
  danger: 'bg-red-500',
  info: 'bg-blue-500',
  purple: 'bg-purple-500',
};

export function Badge({ 
  variant = 'default', 
  size = 'md',
  dot = false,
  children, 
  className = '',
  style,
}: BadgeProps) {
  return (
    <span 
      className={`
        inline-flex items-center gap-1.5 font-medium rounded-full border
        ${style ? '' : badgeVariants[variant]}
        ${badgeSizes[size]}
        ${className}
      `}
      style={style}
    >
      {dot && <span className={`w-1.5 h-1.5 rounded-full ${dotColors[variant]}`} />}
      {children}
    </span>
  );
}

/* ==========================================================================
   Input Component
   ========================================================================== */

interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  hint?: string;
  leftIcon?: React.ReactNode;
  rightIcon?: React.ReactNode;
}

export function Input({ 
  label, 
  error, 
  hint,
  leftIcon,
  rightIcon,
  className = '', 
  id,
  ...props 
}: InputProps) {
  const inputId = id || label?.toLowerCase().replace(/\s+/g, '-');
  
  return (
    <div className="flex flex-col gap-1.5">
      {label && (
        <label htmlFor={inputId} className="text-sm font-medium text-gray-700">
          {label}
        </label>
      )}
      <div className="relative">
        {leftIcon && (
          <div className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400">
            {leftIcon}
          </div>
        )}
        <input
          id={inputId}
          className={`
            w-full px-4 py-2 rounded-lg border border-gray-300 bg-white
            text-gray-900 placeholder:text-gray-400
            focus:outline-none focus:border-[var(--color-primary)] focus:ring-2 focus:ring-blue-100
            transition-all duration-150
            ${leftIcon ? 'pl-10' : ''}
            ${rightIcon ? 'pr-10' : ''}
            ${error ? 'border-red-500 focus:border-red-500 focus:ring-red-100' : ''}
            disabled:bg-gray-50 disabled:text-gray-500 disabled:cursor-not-allowed
            ${className}
          `}
          {...props}
        />
        {rightIcon && (
          <div className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400">
            {rightIcon}
          </div>
        )}
      </div>
      {hint && !error && <span className="text-xs text-gray-500">{hint}</span>}
      {error && <span className="text-xs text-red-600">{error}</span>}
    </div>
  );
}

/* ==========================================================================
   Select Component
   ========================================================================== */

interface SelectProps extends React.SelectHTMLAttributes<HTMLSelectElement> {
  label?: string;
  error?: string;
  options?: Array<{ value: string | number; label: string }>;
  children?: React.ReactNode;
}

export function Select({ label, error, options, children, className = '', id, ...props }: SelectProps) {
  const selectId = id || label?.toLowerCase().replace(/\s+/g, '-');
  
  return (
    <div className="flex flex-col gap-1.5">
      {label && (
        <label htmlFor={selectId} className="text-sm font-medium text-gray-700">
          {label}
        </label>
      )}
      <select
        id={selectId}
        className={`
          px-4 py-2 rounded-lg border border-gray-300 bg-white
          text-gray-900 cursor-pointer
          focus:outline-none focus:border-[var(--color-primary)] focus:ring-2 focus:ring-blue-100
          transition-all duration-150
          disabled:bg-gray-50 disabled:cursor-not-allowed
          ${error ? 'border-red-500 focus:border-red-500 focus:ring-red-100' : ''}
          ${className}
        `}
        {...props}
      >
        {children || options?.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
      {error && <span className="text-xs text-red-600">{error}</span>}
    </div>
  );
}

/* ==========================================================================
   Search Input Component
   ========================================================================== */

interface SearchInputProps extends Omit<InputProps, 'leftIcon'> {
  onClear?: () => void;
}

export function SearchInput({ onClear, value, ...props }: SearchInputProps) {
  return (
    <Input
      leftIcon={
        <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
      }
      rightIcon={
        value && onClear ? (
          <button 
            onClick={onClear}
            className="hover:text-gray-600 transition-colors"
            type="button"
            aria-label="Clear search"
          >
            <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        ) : undefined
      }
      value={value}
      {...props}
    />
  );
}
