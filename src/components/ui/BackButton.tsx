import { ArrowLeft } from 'lucide-react';
import { useRouter } from 'next/navigation';

interface BackButtonProps {
  label?: string;
  className?: string;
}

export function BackButton({ label = 'Back', className = '' }: BackButtonProps) {
  const router = useRouter();

  return (
    <button
      onClick={() => router.back()}
      className={`
        flex items-center gap-2 px-4 py-2 rounded-lg
        text-[var(--text-secondary)] hover:text-[var(--text-primary)]
        bg-[var(--bg-tertiary)] hover:bg-[var(--border-light)]
        transition-all duration-200
        ${className}
      `}
      aria-label={label}
    >
      <ArrowLeft size={18} />
      <span>{label}</span>
    </button>
  );
}
