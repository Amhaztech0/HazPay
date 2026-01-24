import React from 'react';
import { AlertCircle, CheckCircle, XCircle, Info, X } from 'lucide-react';

/* ==========================================================================
   Alert Component
   ========================================================================== */

interface AlertProps {
  variant?: 'success' | 'danger' | 'warning' | 'info';
  title?: string;
  children: React.ReactNode;
  dismissible?: boolean;
  onDismiss?: () => void;
  className?: string;
  icon?: React.ReactNode;
}

const alertVariants = {
  success: {
    container: 'alert-success',
    icon: <CheckCircle size={20} />,
  },
  danger: {
    container: 'alert-danger',
    icon: <XCircle size={20} />,
  },
  warning: {
    container: 'alert-warning',
    icon: <AlertCircle size={20} />,
  },
  info: {
    container: 'alert-info',
    icon: <Info size={20} />,
  },
};

export function Alert({ 
  variant = 'info', 
  title,
  children, 
  dismissible = false,
  onDismiss,
  className = '',
  icon,
}: AlertProps) {
  const styles = alertVariants[variant];
  
  return (
    <div className={`alert ${styles.container} ${className}`} role="alert">
      <div className="shrink-0">
        {icon || styles.icon}
      </div>
      <div className="flex-1">
        {title && <p className="font-medium mb-1">{title}</p>}
        <div className="text-sm">{children}</div>
      </div>
      {dismissible && onDismiss && (
        <button
          onClick={onDismiss}
          className="shrink-0 p-1 rounded hover:bg-black/5 transition-colors"
          aria-label="Dismiss"
        >
          <X size={16} />
        </button>
      )}
    </div>
  );
}

/* ==========================================================================
   Toast Component (for notifications)
   ========================================================================== */

interface ToastProps {
  variant?: 'success' | 'danger' | 'warning' | 'info';
  message: string;
  onClose?: () => void;
  duration?: number;
}

export function Toast({ variant = 'info', message, onClose, duration = 5000 }: ToastProps) {
  React.useEffect(() => {
    if (duration && onClose) {
      const timer = setTimeout(onClose, duration);
      return () => clearTimeout(timer);
    }
  }, [duration, onClose]);

  const styles = alertVariants[variant];

  return (
    <div className={`alert ${styles.container} shadow-lg max-w-md animate-slide-in`}>
      <div className="shrink-0">{styles.icon}</div>
      <p className="flex-1 text-sm">{message}</p>
      {onClose && (
        <button
          onClick={onClose}
          className="shrink-0 p-1 rounded hover:bg-black/5 transition-colors"
          aria-label="Close"
        >
          <X size={16} />
        </button>
      )}
    </div>
  );
}

/* ==========================================================================
   Info Box Component (for tips and hints)
   ========================================================================== */

interface InfoBoxProps {
  variant?: 'info' | 'tip' | 'warning' | 'note';
  title?: string;
  children: React.ReactNode;
  className?: string;
}

const infoBoxStyles = {
  info: 'bg-blue-50 border-blue-200 text-blue-900',
  tip: 'bg-green-50 border-green-200 text-green-900',
  warning: 'bg-yellow-50 border-yellow-200 text-yellow-900',
  note: 'bg-gray-50 border-gray-200 text-gray-900',
};

const infoBoxIcons = {
  info: '💡',
  tip: '✨',
  warning: '⚠️',
  note: '📝',
};

export function InfoBox({ variant = 'info', title, children, className = '' }: InfoBoxProps) {
  return (
    <div className={`rounded-lg border p-4 ${infoBoxStyles[variant]} ${className}`}>
      <div className="flex items-start gap-3">
        <span className="text-lg">{infoBoxIcons[variant]}</span>
        <div className="text-sm">
          {title && <p className="font-medium mb-1">{title}</p>}
          <div>{children}</div>
        </div>
      </div>
    </div>
  );
}

/* ==========================================================================
   Confirmation Dialog Component
   ========================================================================== */

interface ConfirmDialogProps {
  isOpen: boolean;
  onClose: () => void;
  onConfirm: () => void;
  title: string;
  message: string;
  confirmLabel?: string;
  cancelLabel?: string;
  variant?: 'danger' | 'warning' | 'info';
  loading?: boolean;
}

export function ConfirmDialog({
  isOpen,
  onClose,
  onConfirm,
  title,
  message,
  confirmLabel = 'Confirm',
  cancelLabel = 'Cancel',
  variant = 'danger',
  loading = false,
}: ConfirmDialogProps) {
  if (!isOpen) return null;

  const confirmButtonStyles = {
    danger: 'bg-red-600 hover:bg-red-700 text-white',
    warning: 'bg-yellow-600 hover:bg-yellow-700 text-white',
    info: 'bg-blue-600 hover:bg-blue-700 text-white',
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      {/* Backdrop */}
      <div 
        className="absolute inset-0 bg-black/50 backdrop-blur-sm"
        onClick={onClose}
      />
      
      {/* Dialog */}
      <div className="relative bg-white rounded-xl shadow-xl max-w-md w-full mx-4 p-6 animate-scale-in">
        <h3 className="text-lg font-semibold text-gray-900 mb-2">{title}</h3>
        <p className="text-gray-600 mb-6">{message}</p>
        
        <div className="flex justify-end gap-3">
          <button
            onClick={onClose}
            disabled={loading}
            className="px-4 py-2 text-sm font-medium text-gray-700 bg-gray-100 rounded-lg hover:bg-gray-200 transition-colors disabled:opacity-50"
          >
            {cancelLabel}
          </button>
          <button
            onClick={onConfirm}
            disabled={loading}
            className={`px-4 py-2 text-sm font-medium rounded-lg transition-colors disabled:opacity-50 ${confirmButtonStyles[variant]}`}
          >
            {loading ? 'Loading...' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
