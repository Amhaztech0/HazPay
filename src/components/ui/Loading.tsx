import React from 'react';

/* ==========================================================================
   Loading Spinner Component
   ========================================================================== */

interface SpinnerProps {
  size?: 'sm' | 'md' | 'lg';
  className?: string;
}

const spinnerSizes = {
  sm: 'w-4 h-4 border-2',
  md: 'w-6 h-6 border-2',
  lg: 'w-8 h-8 border-3',
};

export function Spinner({ size = 'md', className = '' }: SpinnerProps) {
  return (
    <div 
      className={`
        ${spinnerSizes[size]} 
        border-gray-300 border-t-blue-600 
        rounded-full animate-spin
        ${className}
      `}
      role="status"
      aria-label="Loading"
    />
  );
}

/* ==========================================================================
   Full Page Loading Component
   ========================================================================== */

interface PageLoadingProps {
  message?: string;
}

export function PageLoading({ message = 'Loading...' }: PageLoadingProps) {
  return (
    <div className="flex flex-col items-center justify-center min-h-[400px] gap-4">
      <Spinner size="lg" />
      <p className="text-gray-500 text-sm font-medium">{message}</p>
    </div>
  );
}

/* ==========================================================================
   Loading Overlay Component
   ========================================================================== */

interface LoadingOverlayProps {
  isLoading: boolean;
  children: React.ReactNode;
  message?: string;
}

export function LoadingOverlay({ isLoading, children, message }: LoadingOverlayProps) {
  return (
    <div className="relative">
      {children}
      {isLoading && (
        <div className="absolute inset-0 bg-white/80 backdrop-blur-sm flex items-center justify-center z-10 rounded-lg">
          <div className="flex flex-col items-center gap-3">
            <Spinner size="lg" />
            {message && <p className="text-gray-500 text-sm">{message}</p>}
          </div>
        </div>
      )}
    </div>
  );
}

/* ==========================================================================
   Skeleton Components
   ========================================================================== */

interface SkeletonProps {
  className?: string;
}

export function Skeleton({ className = '' }: SkeletonProps) {
  return <div className={`skeleton ${className}`} />;
}

interface SkeletonTextProps {
  lines?: number;
  className?: string;
}

export function SkeletonText({ lines = 3, className = '' }: SkeletonTextProps) {
  return (
    <div className={`space-y-2 ${className}`}>
      {Array.from({ length: lines }).map((_, i) => (
        <Skeleton 
          key={i} 
          className={`h-4 ${i === lines - 1 ? 'w-3/4' : 'w-full'}`} 
        />
      ))}
    </div>
  );
}

interface SkeletonCardProps {
  className?: string;
}

export function SkeletonCard({ className = '' }: SkeletonCardProps) {
  return (
    <div className={`card p-6 space-y-4 ${className}`}>
      <Skeleton className="h-4 w-1/3" />
      <Skeleton className="h-8 w-1/2" />
      <Skeleton className="h-4 w-1/4" />
    </div>
  );
}

/* ==========================================================================
   Stats Loading Skeleton
   ========================================================================== */

export function StatsGridSkeleton({ count = 4 }: { count?: number }) {
  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
      {Array.from({ length: count }).map((_, i) => (
        <SkeletonCard key={i} />
      ))}
    </div>
  );
}

/* ==========================================================================
   Chart Loading Skeleton
   ========================================================================== */

// Pre-defined heights for chart bars (deterministic)
const chartBarHeights = ['h-1/2', 'h-3/4', 'h-2/3', 'h-full', 'h-1/3', 'h-4/5', 'h-2/5'];

interface ChartSkeletonProps {
  className?: string;
  height?: string;
}

export function ChartSkeleton({ className = '', height }: ChartSkeletonProps) {
  return (
    <div className={`card p-6 ${className}`} style={height ? { height } : undefined}>
      <Skeleton className="h-5 w-48 mb-6" />
      <div className="h-[200px] flex items-end justify-between gap-4 px-4">
        {chartBarHeights.map((h, i) => (
          <div key={i} className={`flex-1 ${h}`}>
            <Skeleton className="w-full h-full" />
          </div>
        ))}
      </div>
    </div>
  );
}
