'use client';

import { AdminProtection } from '@/components/AdminProtection';
import { AdminManagement } from '@/components/AdminManagement';

export default function AdminSettingsPage() {
  return (
    <AdminProtection>
      <div className="p-6">
        <AdminManagement />
      </div>
    </AdminProtection>
  );
}
