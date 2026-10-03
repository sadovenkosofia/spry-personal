import { useAuth } from "react-oidc-context";

import { clientId, cognitoDomain } from "@/auth/config";
import { Button } from "@/components/ui/button";

export function AuthBar() {
  const auth = useAuth();

  if (auth.isLoading) return null;

  if (!auth.isAuthenticated) {
    return (
      <Button variant="outline" onClick={() => void auth.signinRedirect()}>
        Sign in
      </Button>
    );
  }

  const signOut = async () => {
    await auth.removeUser();
    const logoutUri = encodeURIComponent(`${window.location.origin}/`);
    window.location.href = `${cognitoDomain}/logout?client_id=${clientId}&logout_uri=${logoutUri}`;
  };

  return (
    <div className="flex items-center gap-3">
      <span className="text-sm">{auth.user?.profile.email}</span>
      <Button variant="outline" onClick={() => void signOut()}>
        Sign out
      </Button>
    </div>
  );
}
