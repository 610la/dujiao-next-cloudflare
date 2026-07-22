type UnwrapPromise<T> = T extends Promise<infer R> ? R : T

export type DebouncedAsyncFn<T extends (...args: any[]) => any> = ((...args: Parameters<T>) => Promise<UnwrapPromise<ReturnType<T>> | undefined>) & {
  cancel: () => void
}

export const debounceAsync = <T extends (...args: any[]) => any>(fn: T, wait = 300): DebouncedAsyncFn<T> => {
  let timer: number | null = null
  let lastArgs: Parameters<T> | null = null
  let pending: Array<{
    resolve: (value: UnwrapPromise<ReturnType<T>> | undefined) => void
    reject: (reason?: any) => void
  }> = []

  const debounced = ((...args: Parameters<T>) => {
    lastArgs = args
    return new Promise<UnwrapPromise<ReturnType<T>> | undefined>((resolve, reject) => {
      pending.push({ resolve, reject })
      if (timer) {
        window.clearTimeout(timer)
      }
      timer = window.setTimeout(async () => {
        const current = pending
        pending = []
        timer = null
        try {
          const result = await fn(...(lastArgs || ([] as unknown as Parameters<T>)))
          current.forEach((item) => item.resolve(result as UnwrapPromise<ReturnType<T>>))
        } catch (err) {
          current.forEach((item) => item.reject(err))
        }
      }, wait)
    })
  }) as DebouncedAsyncFn<T>

  debounced.cancel = () => {
    if (timer) {
      window.clearTimeout(timer)
      timer = null
    }
    if (pending.length > 0) {
      const current = pending
      pending = []
      current.forEach((item) => item.resolve(undefined))
    }
  }

  return debounced
}
