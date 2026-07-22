import type { Updater } from "@tanstack/vue-table"
import type { ClassValue } from "clsx"
import type { Ref } from "vue"
import { clsx } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

export function valueUpdater<T extends Updater<any>>(updaterOrValue: T, ref: Ref) {
  ref.value
    = typeof updaterOrValue === "function"
      ? updaterOrValue(ref.value)
      : updaterOrValue
}

export function toggleArrayMember<T>(
  arr: Ref<T[]>,
  item: T,
  v: boolean | 'indeterminate',
) {
  if (v === true) {
    if (!arr.value.includes(item)) arr.value.push(item)
  } else {
    const i = arr.value.indexOf(item)
    if (i >= 0) arr.value.splice(i, 1)
  }
}
