import { NextResponse } from 'next/server'
import { getSupabaseRouteClient } from '@/lib/supabaseRouteClient'
import { requirePermission } from '@/lib/requirePermission'

// LCC-DonorShort-StateShort-MMYY-WorkplanSeq (same shape the F3 assign/reassign routes generate)
const SERIAL_PATTERN = /^LCC-([A-Z0-9]+)-([A-Z0-9]+)-((?:0[1-9]|1[0-2])\d{2})-(\d{4})$/

/**
 * Issue #28: post-assignment serial number modification.
 * PATCH /api/projects/[id]/serial
 * Body: { serial: string }
 * Changes the serial (err_projects.grant_id) of a work plan already assigned to a grant
 * via its MOU. Keeps grants_grid_view.activities, workplan_number and the F1 file path in sync.
 */
export async function PATCH(
  request: Request,
  { params }: { params: { id: string } }
) {
  try {
    const perm = await requirePermission('f3_reassign_grant')
    if (perm instanceof NextResponse) return perm

    const supabase = getSupabaseRouteClient()
    const projectId = params.id
    const body = await request.json().catch(() => ({}))
    const newSerial = String(body.serial ?? '').trim().toUpperCase()

    const match = newSerial.match(SERIAL_PATTERN)
    if (!match) {
      return NextResponse.json(
        { error: 'Serial must look like LCC-DONOR-STATE-MMYY-0001' },
        { status: 400 }
      )
    }
    const [, donorShort, stateShort, mmyy, seq] = match
    const workplanNumber = parseInt(seq, 10)
    if (workplanNumber < 1) {
      return NextResponse.json({ error: 'Workplan sequence must be at least 0001' }, { status: 400 })
    }

    const { data: project, error: fetchError } = await supabase
      .from('err_projects')
      .select('id, grant_id, grant_grid_id, file_key, mou_id')
      .eq('id', projectId)
      .single()

    if (fetchError || !project) {
      return NextResponse.json({ error: 'Project not found' }, { status: 404 })
    }

    const oldSerial: string | null = project.grant_id
    if (!project.mou_id || !oldSerial || !oldSerial.startsWith('LCC-')) {
      return NextResponse.json(
        { error: 'Serial can only be changed after the MOU is assigned to a grant' },
        { status: 400 }
      )
    }
    if (oldSerial === newSerial) {
      return NextResponse.json({ success: true, serial: newSerial })
    }

    // err_projects.grant_id has no unique constraint, so enforce uniqueness here
    const { data: duplicates, error: dupError } = await supabase
      .from('err_projects')
      .select('id')
      .eq('grant_id', newSerial)
      .neq('id', projectId)
      .limit(1)

    if (dupError) throw dupError
    if (duplicates && duplicates.length > 0) {
      return NextResponse.json({ error: `Serial ${newSerial} is already used by another work plan` }, { status: 409 })
    }

    // Find the grant row whose activities list holds the old serial
    let grantQuery = supabase
      .from('grants_grid_view')
      .select('id, activities, max_workplan_sequence')
    grantQuery = project.grant_grid_id
      ? grantQuery.eq('id', project.grant_grid_id)
      : grantQuery.ilike('activities', `%${oldSerial}%`)
    const { data: grants, error: grantError } = await grantQuery
    if (grantError) throw grantError
    const grant = (grants || []).find((g: { activities: string | null }) =>
      String(g.activities || '').split(',').map((s: string) => s.trim()).includes(oldSerial)
    ) ?? (project.grant_grid_id ? grants?.[0] : undefined)

    // Move the F1 file so its name keeps matching the serial
    let finalFileKey: string | null = project.file_key
    if (project.file_key && project.file_key.startsWith('f1-forms/')) {
      const ext = project.file_key.split('.').pop() || 'pdf'
      const newFileKey = `f1-forms/${donorShort}/${stateShort}/${mmyy}/${newSerial}.${ext}`
      if (newFileKey !== project.file_key) {
        const { error: moveError } = await supabase.storage
          .from('images')
          .move(project.file_key, newFileKey)
        if (moveError) {
          // Fallback: copy then remove
          const { error: copyErr } = await supabase.storage.from('images').copy(project.file_key, newFileKey)
          if (copyErr) {
            return NextResponse.json({ error: `Failed to move F1 file: ${copyErr.message}` }, { status: 500 })
          }
          await supabase.storage.from('images').remove([project.file_key])
        }
        finalFileKey = newFileKey
      }
    }

    const { data: updated, error: updateError } = await supabase
      .from('err_projects')
      .update({
        grant_id: newSerial,
        workplan_number: workplanNumber,
        file_key: finalFileKey,
      })
      .eq('id', projectId)
      .eq('grant_id', oldSerial)
      .select('id')

    if (updateError || !updated || updated.length === 0) {
      // Put the file back so it still matches the unchanged serial
      if (finalFileKey && finalFileKey !== project.file_key) {
        await supabase.storage.from('images').move(finalFileKey, project.file_key)
      }
      if (updateError) throw updateError
      return NextResponse.json(
        { error: 'The serial was changed by someone else. Reload and try again.' },
        { status: 409 }
      )
    }

    if (grant) {
      const serials = String(grant.activities || '')
        .split(',')
        .map((s: string) => s.trim())
        .filter(Boolean)
      const updatedActivities = serials.includes(oldSerial)
        ? serials.map((s: string) => (s === oldSerial ? newSerial : s))
        : [...serials, newSerial]

      const grantUpdate: Record<string, unknown> = { activities: updatedActivities.join(',') }
      // Keep the auto-generated sequence ahead of manually chosen numbers so future assigns don't collide
      if (workplanNumber > (Number(grant.max_workplan_sequence) || 0)) {
        grantUpdate.max_workplan_sequence = workplanNumber
      }

      const { error: updateGrantError } = await supabase
        .from('grants_grid_view')
        .update(grantUpdate)
        .eq('id', grant.id)

      if (updateGrantError) {
        console.error('Error updating grants_grid_view activities:', updateGrantError)
        // Don't fail the serial change, but log the error
      }
    } else {
      console.warn(`No grant row found holding serial ${oldSerial} for project ${projectId}`)
    }

    console.info('[serial-change]', {
      project_id: projectId,
      old_serial: oldSerial,
      new_serial: newSerial,
      changed_by: perm.user.id,
    })

    return NextResponse.json({ success: true, serial: newSerial, old_serial: oldSerial })
  } catch (error) {
    console.error('PATCH /api/projects/[id]/serial:', error)
    return NextResponse.json({ error: 'Failed to change serial number' }, { status: 500 })
  }
}
