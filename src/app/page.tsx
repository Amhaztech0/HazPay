import { redirect } from "next/navigation";

export default function Page() {
  // Redirect root to the admin dashboard. Protected layout will redirect to /login if not authenticated.
  redirect("/dashboard");
}
// Root redirect has been implemented server-side to send visitors to the dashboard.
