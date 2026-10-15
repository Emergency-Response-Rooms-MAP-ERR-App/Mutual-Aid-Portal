/**
 * Issue #120: "fill down" for F5 Implemented Activities (sector, start/end dates).
 * Copies the first non-empty value in a column to the other rows.
 */

export type FillDownMode = 'empty' | 'all'

const isEmpty = (v: unknown) => v == null || String(v).trim() === ''

/** Source value plus how many rows each mode would change. */
export function fillDownPreview<T extends Record<string, unknown>>(rows: T[], key: keyof T) {
  const source = rows.find((r) => !isEmpty(r[key]))?.[key]
  if (isEmpty(source)) return { source: null, emptyCount: 0, conflictCount: 0 }
  let emptyCount = 0
  let conflictCount = 0
  for (const r of rows) {
    if (isEmpty(r[key])) emptyCount++
    else if (r[key] !== source) conflictCount++
  }
  return { source, emptyCount, conflictCount }
}

/** Returns a new array with the source value applied to empty rows (or all rows). */
export function fillDown<T extends Record<string, unknown>>(rows: T[], key: keyof T, mode: FillDownMode): T[] {
  const { source } = fillDownPreview(rows, key)
  if (source == null) return rows
  return rows.map((r) => (mode === 'all' || isEmpty(r[key]) ? { ...r, [key]: source } : r))
}
