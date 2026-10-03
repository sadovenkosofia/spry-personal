import type { AuthProviderProps } from "react-oidc-context";

const origin = window.location.origin;

export const cognitoDomain = import.meta.env.VITE_COGNITO_DOMAIN as string;
export const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID as string;

export const oidcConfig: AuthProviderProps = {
  authority: `https://cognito-idp.us-east-1.amazonaws.com/${import.meta.env.VITE_COGNITO_USER_POOL_ID as string}`,
  client_id: clientId,
  redirect_uri: `${origin}/auth/callback`,
  scope: "openid email profile",
  response_type: "code",
  // after the code exchange, remove ?code=...&state=... from the URL
  onSigninCallback: () => {
    window.history.replaceState({}, document.title, "/");
  },
};
