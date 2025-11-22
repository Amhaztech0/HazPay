'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { LayoutDashboard, Wallet, Settings, LogOut, TrendingUp, Users, FileText } from 'lucide-react';
import { supabase } from '@/lib/supabase';
import { useAuthStore } from '@/store/auth';

export function Sidebar() {
  const pathname = usePathname();
  const router = useRouter();
  const { logout } = useAuthStore();

  const menuItems = [
    { href: '/dashboard', label: 'Dashboard', icon: LayoutDashboard },
    { href: '/transactions', label: 'Transactions', icon: TrendingUp },
    { href: '/pricing', label: 'Pricing', icon: Settings },
    { href: '/wallets', label: 'Wallets', icon: Wallet },
    { href: '/users', label: 'Users', icon: Users },
    { href: '/reports', label: 'Reports', icon: FileText },
  ];

  const handleLogout = async () => {
    await supabase.auth.signOut();
    logout();
    router.push('/login');
  };

  return (
    <div className="w-64 bg-gradient-to-b from-slate-900 via-slate-800 to-slate-900 text-white min-h-screen flex flex-col shadow-lg border-r border-slate-700">
      {/* Logo */}
      <div className="p-6 border-b border-slate-700 bg-gradient-to-r from-blue-600/10 to-purple-600/10">
        <div className="flex items-center gap-2">
          <div className="w-8 h-8 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg flex items-center justify-center">
            <span className="text-white font-bold text-sm">HP</span>
          </div>
          <div>
            <h1 className="text-xl font-bold">HazPay</h1>
            <p className="text-xs text-slate-400">Admin</p>
          </div>
        </div>
      </div>

      {/* Navigation */}
      <nav className="flex-1 p-4 space-y-1.5">
        <p className="text-xs font-semibold text-slate-500 uppercase tracking-wider px-4 mb-4">Menu</p>
        {menuItems.map(({ href, label, icon: Icon }) => {
          const isActive = pathname === href;
          return (
            <Link
              key={href}
              href={href}
              className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-all duration-200 ${
                isActive
                  ? 'bg-gradient-to-r from-blue-600 to-blue-700 text-white shadow-lg scale-105 translate-x-1'
                  : 'text-slate-300 hover:bg-slate-700/50 hover:text-white'
              }`}
            >
              <Icon size={20} className="shrink-0" />
              <span className="font-medium">{label}</span>
              {isActive && <div className="ml-auto w-2 h-2 rounded-full bg-blue-300" />}
            </Link>
          );
        })}
      </nav>

      {/* Logout */}
      <div className="p-4 border-t border-slate-700 bg-gradient-to-r from-slate-800 to-slate-900">
        <button
          onClick={handleLogout}
          className="flex items-center gap-3 w-full px-4 py-3 rounded-lg text-slate-300 hover:text-white hover:bg-red-600/20 transition-all duration-200 group"
        >
          <LogOut size={20} className="group-hover:text-red-400 transition-colors" />
          <span className="font-medium group-hover:text-red-400 transition-colors">Logout</span>
        </button>
      </div>
    </div>
  );
}
