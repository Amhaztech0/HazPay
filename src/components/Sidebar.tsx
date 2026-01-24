'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { 
  LayoutDashboard, 
  Wallet, 
  Settings, 
  LogOut, 
  TrendingUp, 
  Users, 
  FileText, 
  DollarSign, 
  Receipt,
  ChevronRight,
  UserCheck,
  Share2,
  Percent,
  Award,
  type LucideIcon,
} from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useAuthStore } from '@/store/auth';
import { ThemeToggle } from './ThemeToggle';

interface MenuItem {
  href: string;
  label: string;
  icon: LucideIcon;
  badge?: string;
}

const menuItems: MenuItem[] = [
  { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/transactions', label: 'Transactions', icon: TrendingUp },
  { href: '/bills', label: 'Bill Payments', icon: Receipt },
  { href: '/pricing', label: 'Pricing', icon: Settings },
  { href: '/agents', label: 'Agents', icon: UserCheck },
  { href: '/ambassadors', label: 'Ambassadors', icon: Award },
  { href: '/referrals', label: 'Referrals', icon: Share2 },
  { href: '/cashback', label: 'Cashback', icon: Percent },
  { href: '/wallets', label: 'Wallets', icon: Wallet },
  { href: '/users', label: 'Users', icon: Users },
  { href: '/reports', label: 'Reports', icon: FileText },
];

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { logout } = useAuthStore();

  const handleLogout = async () => {
    await supabase.auth.signOut();
    logout();
    router.push('/login');
  };

  const isActiveRoute = (href: string) => {
    return pathname === href || pathname.startsWith(`${href}/`);
  };

  return (
    <aside 
      className="
        w-64 min-h-screen flex flex-col
        bg-gradient-to-b from-[var(--color-gray-900)] via-[var(--color-gray-800)] to-[var(--color-gray-900)]
        text-white shadow-xl border-r border-[var(--color-gray-700)]
      "
      role="navigation"
      aria-label="Main navigation"
    >
      {/* Logo / Brand */}
      <div className="p-6 border-b border-[var(--color-gray-700)]">
        <Link href="/dashboard" className="flex items-center gap-3 group">
          <div 
            className="
              w-10 h-10 rounded-xl flex items-center justify-center
              bg-gradient-to-br from-[var(--color-primary)] to-[var(--color-accent)]
              shadow-lg group-hover:shadow-xl transition-shadow duration-200
            "
          >
            <span className="text-white font-bold text-lg">HP</span>
          </div>
          <div>
            <h1 className="text-xl font-bold text-white">HazPay</h1>
            <p className="text-xs text-[var(--color-gray-400)]">Admin Dashboard</p>
          </div>
        </Link>
      </div>

      {/* Navigation Menu */}
      <nav className="flex-1 py-6 px-3 space-y-1" aria-label="Sidebar">
        <p className="px-4 mb-4 text-xs font-semibold uppercase tracking-wider text-[var(--color-gray-500)]">
          Menu
        </p>
        
        {menuItems.map(({ href, label, icon: Icon, badge }) => {
          const isActive = isActiveRoute(href);
          
          return (
            <Link
              key={href}
              href={href}
              className={`
                flex items-center gap-3 px-4 py-3 rounded-lg
                transition-all duration-200 ease-in-out group
                ${isActive 
                  ? 'bg-gradient-to-r from-[var(--color-primary)] to-[var(--color-primary-dark)] text-white shadow-lg' 
                  : 'text-[var(--color-gray-300)] hover:bg-[var(--color-gray-700)]/50 hover:text-white'
                }
              `}
              aria-current={isActive ? 'page' : undefined}
            >
              <Icon 
                size={20} 
                className={`shrink-0 transition-transform duration-200 ${isActive ? '' : 'group-hover:scale-110'}`} 
              />
              <span className="font-medium flex-1">{label}</span>
              
              {badge && (
                <span className="px-2 py-0.5 text-xs font-medium bg-[var(--color-danger)] rounded-full">
                  {badge}
                </span>
              )}
              
              {isActive && (
                <ChevronRight size={16} className="text-white/70" />
              )}
            </Link>
          );
        })}
      </nav>

      {/* User Section & Logout */}
      <div className="p-4 border-t border-[var(--color-gray-700)] space-y-2">
        <div className="flex gap-2">
          <ThemeToggle />
          <button
            onClick={handleLogout}
            className="
              flex items-center justify-center gap-2 flex-1 px-4 py-2 rounded-lg
              text-[var(--color-gray-300)] 
              hover:bg-[var(--color-danger)]/10 hover:text-[var(--color-danger-light)]
              transition-all duration-200 group
            "
            aria-label="Logout from dashboard"
          >
            <LogOut 
              size={18} 
              className="shrink-0 transition-transform duration-200 group-hover:-translate-x-0.5" 
            />
            <span className="font-medium">Logout</span>
          </button>
        </div>
      </div>
    </aside>
  );
}
