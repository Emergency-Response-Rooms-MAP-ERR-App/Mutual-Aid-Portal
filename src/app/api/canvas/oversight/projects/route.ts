import { NextResponse } from 'next/server'
import { requireCanvasSession } from '@/lib/canvas/session'
import {
  isCoordinatorOrg,
  listOversightCatalogForCoordinator,
} from '@/lib/canvas/disclosure'

/**
 * Legacy path — returns empty projects list and points clients to /catalog.
 * Kept so old clients fail soft.
 */
export async function GET() {
  const session = await requireCanvasSession()
  if (session instanceof NextResponse) return session

  const { canvas, supabase } = session

  if (canvas.is_fallback) {
    return NextResponse.json({
      projects: [],
      processors: [],
      canvas_is_fallback: true,
      disclosure_unavailable: true,
      deprecated: true,
      use: '/api/canvas/oversight/catalog',
    })
  }

  if (!isCoordinatorOrg(canvas.organization)) {
    return NextResponse.json(
      { error: 'Forbidden — coordinator organization required', code: 'NOT_COORDINATOR' },
      { status: 403 }
    )
  }

  const { processors, unavailable } = await listOversightCatalogForCoordinator(
    supabase,
    canvas.organization.id
  )

  return NextResponse.json({
    projects: [],
    processors,
    canvas_is_fallback: false,
    disclosure_unavailable: unavailable,
    deprecated: true,
    use: '/api/canvas/oversight/catalog',
  })
}
