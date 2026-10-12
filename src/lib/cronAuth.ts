import { NextResponse } from 'next/server'

/**
 * Vercel Cron sends `Authorization: Bearer ${CRON_SECRET}` when CRON_SECRET is set.
 * Enforced in production only so local/dev sync triggers still work without the secret.
 */
export function requireCronSecret(request: Request): NextResponse | null {
  if (process.env.NODE_ENV !== 'production') return null

  const cronSecret = process.env.CRON_SECRET
  if (!cronSecret) {
    console.error('[cronAuth] CRON_SECRET is not set; Vercel Cron cannot authenticate')
    return NextResponse.json({ error: 'CRON_SECRET not configured' }, { status: 500 })
  }

  const authHeader = request.headers.get('authorization') || ''
  if (authHeader !== `Bearer ${cronSecret}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  return null
}
