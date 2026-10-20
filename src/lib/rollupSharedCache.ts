import { getSupabaseAdmin } from '@/lib/supabaseAdmin'

/** Cache duration in milliseconds (3 minutes) — must match overview rollup route. */
export const ROLLUP_CACHE_DURATION_MS = 3 * 60 * 1000

export async function readSharedRollupCache(cacheKey: string): Promise<any | null> {
  try {
    const admin = getSupabaseAdmin()
    const { data, error } = await admin
      .from('rollup_cache')
      .select('payload, updated_at')
      .eq('cache_key', cacheKey)
      .maybeSingle()

    if (error) {
      console.error('[rollup] shared cache read failed:', error.message)
      return null
    }
    if (!data?.payload || !data.updated_at) return null

    const ageMs = Date.now() - new Date(data.updated_at).getTime()
    if (ageMs > ROLLUP_CACHE_DURATION_MS || ageMs < 0) return null

    return data.payload
  } catch (e) {
    console.error('[rollup] shared cache read error:', e)
    return null
  }
}

export async function writeSharedRollupCache(cacheKey: string, payload: unknown): Promise<void> {
  try {
    const admin = getSupabaseAdmin()
    const { error } = await admin.from('rollup_cache').upsert(
      {
        cache_key: cacheKey,
        payload,
        updated_at: new Date().toISOString(),
      },
      { onConflict: 'cache_key' }
    )
    if (error) {
      console.error('[rollup] shared cache write failed:', error.message)
      return
    }
    console.log('[rollup] Data cached successfully (shared)')
  } catch (e) {
    console.error('[rollup] shared cache write error:', e)
  }
}
