import { NextResponse, type NextRequest } from "next/server";

// Everything but the sign-in page needs the console's session cookie; the pages check the role.
export function proxy(request: NextRequest) {
  if (!request.cookies.get("adm_t")?.value) return NextResponse.redirect(new URL("/login", request.url));
  return NextResponse.next();
}

export const config = { matcher: ["/((?!login|_next/|favicon).*)"] };
