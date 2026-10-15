'use client'

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { ArrowDownToLine } from 'lucide-react'
import { Button } from '@/components/ui/button'
import * as PopoverPrimitive from '@radix-ui/react-popover'
import { Popover, PopoverTrigger } from '@/components/ui/popover'
import { fillDown, fillDownPreview, type FillDownMode } from '../lib/fillDown'

type FillDownButtonProps<T extends Record<string, unknown>> = {
  rows: T[]
  field: keyof T
  onApply: (rows: T[]) => void
  /** Display text for the source value (e.g. a sector or date) */
  formatValue?: (value: unknown) => string
}

/** Issue #120: header button that copies the first value in a column to the other rows. */
export function FillDownButton<T extends Record<string, unknown>>({
  rows,
  field,
  onApply,
  formatValue = (v) => String(v),
}: FillDownButtonProps<T>) {
  const { t } = useTranslation(['f4f5'])
  const [open, setOpen] = useState(false)
  const { source, emptyCount, conflictCount } = fillDownPreview(rows, field)
  const disabled = source == null || (emptyCount === 0 && conflictCount === 0)

  const apply = (mode: FillDownMode) => {
    onApply(fillDown(rows, field, mode))
    setOpen(false)
  }

  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="h-5 w-5 p-0 ms-1 align-middle"
          disabled={disabled}
          title={source == null ? t('f5.preview.activities.fill_down.no_value') : t('f5.preview.activities.fill_down.title')}
        >
          <ArrowDownToLine className="h-3.5 w-3.5" />
        </Button>
      </PopoverTrigger>
      {/* Not portaled: this sits inside the F5 modal Dialog, which disables pointer events outside its own DOM. */}
      <PopoverPrimitive.Content
        align="start"
        sideOffset={4}
        collisionPadding={8}
        className="bg-popover text-popover-foreground z-[100] w-64 rounded-md border p-3 text-sm shadow-md outline-none"
      >
        <p className="mb-2 text-xs text-muted-foreground">
          {t('f5.preview.activities.fill_down.copy_value', { value: source == null ? '' : formatValue(source) })}
        </p>
        <div className="flex flex-col gap-1.5">
          <Button type="button" size="sm" disabled={emptyCount === 0} onClick={() => apply('empty')}>
            {t('f5.preview.activities.fill_down.empty_rows', { count: emptyCount })}
          </Button>
          {conflictCount > 0 && (
            <Button type="button" size="sm" variant="outline" onClick={() => apply('all')}>
              {t('f5.preview.activities.fill_down.all_rows', { count: conflictCount })}
            </Button>
          )}
        </div>
      </PopoverPrimitive.Content>
    </Popover>
  )
}
