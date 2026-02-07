# Backend Authentication Reference (Next.js)

## Table of Contents

- [Auth.js Setup](#authjs-setup)
- [Refresh Token Function](#refresh-token-function)
- [Bearer Token Helper](#bearer-token-helper)
- [Route Protection Middleware](#route-protection-middleware)
- [API Route Pattern](#api-route-pattern)

## Auth.js Setup

File: `auth.ts`

```typescript
import NextAuth from "next-auth";

export const { handlers, signIn, signOut, auth } = NextAuth({
  providers: [
    {
      id: "{provider-id}",
      name: "{Provider Name}",
      type: "oidc",
      issuer: process.env.AUTH_ISSUER,
      clientId: process.env.AUTH_CLIENT_ID,
      clientSecret: process.env.AUTH_CLIENT_SECRET,
      client: {
        token_endpoint_auth_method: "client_secret_post",
      },
    },
  ],
  callbacks: {
    async jwt({ token, account, profile }) {
      if (account) {
        token.accessToken = account.access_token;
        token.refreshToken = account.refresh_token;
        token.expiresAt = account.expires_at;
        token.userId = profile?.sub;
      }

      // Refresh expired tokens
      if (token.expiresAt && Date.now() >= token.expiresAt * 1000) {
        return await refreshAccessToken(token);
      }

      return token;
    },

    async session({ session, token }) {
      session.accessToken = token.accessToken;
      session.user.id = token.userId;
      session.error = token.error;
      return session;
    },
  },
});
```

## Refresh Token Function

```typescript
async function refreshAccessToken(token) {
  const response = await fetch(`${process.env.AUTH_ISSUER}/api/oauth/token`, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "refresh_token",
      refresh_token: token.refreshToken,
      client_id: process.env.AUTH_CLIENT_ID!,
      client_secret: process.env.AUTH_CLIENT_SECRET!,
    }),
  });

  const tokens = await response.json();

  if (!response.ok) {
    return { ...token, error: "RefreshAccessTokenError" };
  }

  return {
    ...token,
    accessToken: tokens.access_token,
    refreshToken: tokens.refresh_token ?? token.refreshToken,
    expiresAt: Math.floor(Date.now() / 1000) + tokens.expires_in,
  };
}
```

## Bearer Token Helper

File: `lib/auth-helper.ts`

```typescript
import { auth } from "@/auth";
import { NextRequest } from "next/server";

export function getBearerToken(request: NextRequest): string | null {
  const authHeader = request.headers.get("authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return null;
  }
  return authHeader.substring(7);
}

export async function verifyBearerToken(token: string) {
  const response = await fetch(
    `${process.env.AUTH_ISSUER}/api/oauth/userinfo`,
    {
      headers: { Authorization: `Bearer ${token}` },
    }
  );

  if (!response.ok) {
    return null;
  }

  const userinfo = await response.json();
  return {
    user: {
      id: userinfo.sub,
      email: userinfo.email,
      name: userinfo.name,
      image: userinfo.picture,
    },
    accessToken: token,
  };
}

export async function getSession(request?: NextRequest) {
  // Try Bearer token first (for mobile/API clients)
  if (request) {
    const token = getBearerToken(request);
    if (token) {
      return await verifyBearerToken(token);
    }
  }

  // Fall back to session cookie (for web)
  return await auth();
}
```

## Route Protection Middleware

File: `proxy.ts`

```typescript
import { auth } from "@/auth";
import { NextResponse } from "next/server";

const publicPaths = [
  "/login",
  "/api/auth",
  "/preview",
  "/api/v1",      // API routes handle their own auth (Bearer token)
  "/api/openapi",
  "/.well-known",
];

export default auth((req) => {
  const { pathname } = req.nextUrl;

  if (publicPaths.some((path) => pathname.startsWith(path))) {
    return NextResponse.next();
  }

  if (!req.auth) {
    return NextResponse.redirect(new URL("/login", req.url));
  }

  return NextResponse.next();
});
```

## API Route Pattern

File: `app/api/v1/items/route.ts`

```typescript
import { NextRequest, NextResponse } from "next/server";
import { getSession } from "@/lib/auth-helper";
import { db } from "@/lib/db";
import { items } from "@/lib/db/schema";

export async function GET(request: NextRequest) {
  const session = await getSession(request);

  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const allItems = await db.select().from(items);
  return NextResponse.json(allItems);
}

export async function POST(request: NextRequest) {
  const session = await getSession(request);

  if (!session) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await request.json();
  const newItem = await db.insert(items).values({
    ...body,
    createdBy: session.user.id,
  });

  return NextResponse.json(newItem, { status: 201 });
}
```
