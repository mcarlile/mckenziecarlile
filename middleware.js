import { rewrite } from '@vercel/functions';

// Only runs on the root path — the shop subdomain is a single-page listing.
export const config = {
  matcher: '/',
};

export default function middleware(request) {
  const host = request.headers.get('host') || '';

  if (host === 'shop.mckenziecarlile.com') {
    return rewrite(new URL('/shop', request.url));
  }
}
