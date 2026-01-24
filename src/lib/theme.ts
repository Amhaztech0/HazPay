/**
 * Theme Configuration
 * Centralized color and style constants for JavaScript/TypeScript usage
 */

export const theme = {
  colors: {
    // Single value colors for easy access
    primary: '#3b82f6',
    primaryDark: '#2563eb',
    success: '#10b981',
    warning: '#f59e0b',
    danger: '#ef4444',
    accent: '#8b5cf6',
    
    // Extended color palettes
    blue: {
      50: '#eff6ff',
      100: '#dbeafe',
      200: '#bfdbfe',
      300: '#93c5fd',
      400: '#60a5fa',
      500: '#3b82f6',
      600: '#2563eb',
      700: '#1d4ed8',
      800: '#1e40af',
      900: '#1e3a8a',
    },
    green: {
      50: '#ecfdf5',
      100: '#d1fae5',
      200: '#a7f3d0',
      500: '#10b981',
      600: '#059669',
      700: '#047857',
    },
    yellow: {
      50: '#fffbeb',
      100: '#fef3c7',
      200: '#fde68a',
      500: '#f59e0b',
      600: '#d97706',
      700: '#b45309',
    },
    red: {
      50: '#fef2f2',
      100: '#fee2e2',
      200: '#fecaca',
      500: '#ef4444',
      600: '#dc2626',
      700: '#b91c1c',
    },
    gray: {
      50: '#f8fafc',
      100: '#f1f5f9',
      200: '#e2e8f0',
      300: '#cbd5e1',
      400: '#94a3b8',
      500: '#64748b',
      600: '#475569',
      700: '#334155',
      800: '#1e293b',
      900: '#0f172a',
    },
  },
  
  // Status colors for badges and indicators
  status: {
    success: { bg: 'bg-green-50', border: 'border-green-200', text: 'text-green-700', badge: 'bg-green-100 text-green-800' },
    pending: { bg: 'bg-yellow-50', border: 'border-yellow-200', text: 'text-yellow-700', badge: 'bg-yellow-100 text-yellow-800' },
    failed: { bg: 'bg-red-50', border: 'border-red-200', text: 'text-red-700', badge: 'bg-red-100 text-red-800' },
    info: { bg: 'bg-blue-50', border: 'border-blue-200', text: 'text-blue-700', badge: 'bg-blue-100 text-blue-800' },
  },
  
  // Stat card color variants
  statCard: {
    blue: { bg: 'bg-blue-50', border: 'border-blue-200', text: 'text-blue-600', icon: 'text-blue-300' },
    green: { bg: 'bg-green-50', border: 'border-green-200', text: 'text-green-600', icon: 'text-green-300' },
    purple: { bg: 'bg-purple-50', border: 'border-purple-200', text: 'text-purple-600', icon: 'text-purple-300' },
    amber: { bg: 'bg-amber-50', border: 'border-amber-200', text: 'text-amber-600', icon: 'text-amber-300' },
    red: { bg: 'bg-red-50', border: 'border-red-200', text: 'text-red-600', icon: 'text-red-300' },
    indigo: { bg: 'bg-indigo-50', border: 'border-indigo-200', text: 'text-indigo-600', icon: 'text-indigo-300' },
  },
  
  // Chart colors
  chart: {
    primary: '#3b82f6',
    success: '#10b981',
    warning: '#f59e0b',
    danger: '#ef4444',
    purple: '#8b5cf6',
    cyan: '#06b6d4',
  },
  
  // Network brand colors
  network: {
    MTN: { bg: 'bg-yellow-100', text: 'text-yellow-800', color: '#fcd34d' },
    AIRTEL: { bg: 'bg-red-100', text: 'text-red-800', color: '#ef4444' },
    GLO: { bg: 'bg-green-100', text: 'text-green-800', color: '#10b981' },
    '9MOBILE': { bg: 'bg-teal-100', text: 'text-teal-800', color: '#14b8a6' },
  },
} as const;

// Type exports for TypeScript
export type ThemeColor = keyof typeof theme.colors;
export type StatusType = keyof typeof theme.status;
export type StatCardColor = keyof typeof theme.statCard;
export type NetworkType = keyof typeof theme.network;

// Utility function to get status styles
export const getStatusStyles = (status: string) => {
  const normalizedStatus = status.toLowerCase();
  return theme.status[normalizedStatus as StatusType] || theme.status.info;
};

// Utility function to get network styles
export const getNetworkStyles = (network: string) => {
  const normalizedNetwork = network.toUpperCase();
  return theme.network[normalizedNetwork as NetworkType] || { bg: 'bg-gray-100', text: 'text-gray-800', color: '#6b7280' };
};

// Format currency
export const formatCurrency = (amount: number, currency = '₦'): string => {
  return `${currency}${amount.toLocaleString()}`;
};

// Format date
export const formatDate = (date: string | Date, options?: Intl.DateTimeFormatOptions): string => {
  const defaultOptions: Intl.DateTimeFormatOptions = {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  };
  return new Date(date).toLocaleDateString('en-NG', options || defaultOptions);
};

// Format short date
export const formatShortDate = (date: string | Date): string => {
  return new Date(date).toLocaleDateString('en-NG', {
    month: 'short',
    day: 'numeric',
  });
};

export default theme;
