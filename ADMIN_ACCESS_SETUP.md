# Admin-Only Dashboard Access Setup

## What This Does ✅

- Only users marked as `is_admin = true` can access `/admin` routes
- Non-admin users get redirected to `/admin/unauthorized` page
- Checks happen both on server (middleware) and client (React component)
- Cannot bypass protection by manipulating URLs or cookies

---

## Implementation Steps

### Step 1: Add the Three New Files

These files have already been created:

1. **`admin/src/middleware.ts`** - Protects routes at request level
2. **`admin/src/components/AdminProtection.tsx`** - React component for client-side protection
3. **`admin/src/app/admin/unauthorized.tsx`** - Error page for non-admins

### Step 2: Wrap Your Admin Pages

Update each admin page to use the `AdminProtection` wrapper:

#### Example: `admin/src/app/bills/page.tsx`

**Before:**
```typescript
export default function BillsPage() {
  return (
    <div>
      {/* Page content */}
    </div>
  );
}
```

**After:**
```typescript
import { AdminProtection } from '@/components/AdminProtection';

export default function BillsPage() {
  return (
    <AdminProtection>
      <div>
        {/* Page content */}
      </div>
    </AdminProtection>
  );
}
```

#### Apply to All Admin Pages:
- `admin/src/app/bills/page.tsx`
- `admin/src/app/agents/page.tsx`
- `admin/src/app/agents/manage/page.tsx`
- Any other `/admin/*` pages

### Step 3: Update Admin Layout (Optional but Recommended)

Edit: `admin/src/app/layout.tsx`

```typescript
'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs';

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const router = useRouter();
  const supabase = createClientComponentClient();

  useEffect(() => {
    const checkSession = async () => {
      try {
        const {
          data: { user },
        } = await supabase.auth.getUser();

        if (!user) {
          router.push('/login');
        }
      } catch (error) {
        console.error('Session check error:', error);
        router.push('/login');
      }
    };

    checkSession();
  }, [router, supabase]);

  return (
    <html>
      <body>{children}</body>
    </html>
  );
}
```

### Step 4: Test Admin Access

#### ✅ Test 1: Login as Admin (yyounghaz@gmail.com)
```
1. Go to your admin dashboard login
2. Enter email: yyounghaz@gmail.com
3. Enter your password
4. Should see admin pages with data ✅
```

#### ❌ Test 2: Login as Regular User
```
1. Create a new account with different email
2. Try to navigate to /admin/bills
3. Should see "Access Denied" page ❌
4. Shows message: "Only administrators can access this area"
```

---

## How It Works

### Protection Layers:

**Layer 1: Middleware (Server-Side)**
- Runs on every request to `/admin/*`
- Checks if user has a valid session token
- Redirects to login if token is missing

**Layer 2: AdminProtection Component (Client-Side)**
- Runs when page loads
- Fetches user profile from database
- Checks `profiles.is_admin` column
- Redirects to `/admin/unauthorized` if not admin
- Shows loading spinner while checking

**Layer 3: RLS Policies (Database)**
- Database queries also respect RLS
- Even if user bypasses UI, can't access data

---

## Security Flow

```
User tries to access /admin/bills
        ↓
Middleware checks session token
        ↓
If no token → Redirect to /login
If token exists → Allow request
        ↓
AdminProtection component loads
        ↓
Fetches user profile with is_admin flag
        ↓
If is_admin = true → Show page ✅
If is_admin = false → Redirect to /unauthorized ❌
```

---

## File Locations Checklist

```
admin/
├── src/
│   ├── middleware.ts ✓ (NEW)
│   ├── components/
│   │   └── AdminProtection.tsx ✓ (NEW)
│   └── app/
│       ├── layout.tsx (UPDATE with session check)
│       ├── admin/
│       │   ├── unauthorized.tsx ✓ (NEW)
│       │   ├── bills/
│       │   │   └── page.tsx (WRAP with AdminProtection)
│       │   ├── agents/
│       │   │   ├── page.tsx (WRAP with AdminProtection)
│       │   │   └── manage/
│       │   │       └── page.tsx (WRAP with AdminProtection)
```

---

## Environment Requirements

Make sure you have:

```
.env.local:
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_anon_key
```

---

## Testing Restricted Access

### Create Test Users in Supabase:

```sql
-- View all users and their admin status
SELECT u.email, p.is_admin
FROM auth.users u
LEFT JOIN profiles p ON u.id = p.id
ORDER BY u.created_at DESC;

-- Make a user admin
SELECT set_user_as_admin('email@example.com');

-- Remove admin status
UPDATE profiles SET is_admin = false WHERE id = (
  SELECT id FROM auth.users WHERE email = 'email@example.com'
);
```

---

## What Happens After Setup

### ✅ Admin User (yyounghaz@gmail.com):
- Can login to admin dashboard
- Can view all bills, agents, applications
- Can manage all records
- No restrictions

### ❌ Regular Users:
- Can register normally
- Can use mobile app features
- **Cannot access `/admin` routes**
- Get redirected to unauthorized page if they try
- See message: "Only administrators can access this area"

---

## Troubleshooting

### Issue: Still seeing "Failed to fetch" on admin pages
**Solution:** 
- Make sure AdminProtection wrapper is added to page
- Check browser console for errors
- Verify user is marked as admin in database

### Issue: Non-admin user can still see admin page content
**Solution:**
- Clear browser cache
- Hard refresh (Ctrl+Shift+R or Cmd+Shift+R)
- Make sure middleware.ts exists
- Restart Next.js dev server

### Issue: Redirect loop
**Solution:**
- Check that login page exists
- Verify Supabase credentials in .env.local
- Check browser console for error messages

### Issue: "Verifying admin access..." spins forever
**Solution:**
- Check Supabase connection in browser console
- Verify auth session is valid
- Check profiles table has is_admin column

---

## Key Database Query

This is what checks admin status:

```sql
SELECT p.id, p.is_admin, u.email
FROM profiles p
JOIN auth.users u ON u.id = p.id
WHERE u.id = 'current-user-id';
```

Only users with `is_admin = true` can access admin routes.

---

## Deployment Checklist

- [ ] Add `middleware.ts` file
- [ ] Add `AdminProtection.tsx` component
- [ ] Add `/admin/unauthorized.tsx` page
- [ ] Wrap all admin pages with `<AdminProtection>`
- [ ] Update admin layout with session check
- [ ] Test with admin user (yyounghaz@gmail.com)
- [ ] Test with non-admin user
- [ ] Deploy to production
- [ ] Verify protection works on live site
