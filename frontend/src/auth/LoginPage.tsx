import { useEffect, useRef } from "react";
import { useAuth } from "react-oidc-context";

export default function LoginPage() {
  const auth = useAuth();
  const started = useRef(false);

  useEffect(() => {
    if (auth.isLoading || started.current) return;
    started.current = true;
    if (auth.isAuthenticated) {
      window.location.replace("/");
      return;
    }
    void auth.signinRedirect();
  }, [auth]);

  return <p className="p-6 text-sm text-muted-foreground">Redirecting to sign-in…</p>;
}
