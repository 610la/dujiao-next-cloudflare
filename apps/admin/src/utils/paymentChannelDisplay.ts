type PaymentChannelConfig = Record<string, unknown> | null | undefined

const readConfigString = (config: PaymentChannelConfig, key: string) => {
  const value = config?.[key]
  return typeof value === 'string' || typeof value === 'number' ? String(value).trim() : ''
}

export const resolveOkpayConfiguredCoin = (config: PaymentChannelConfig) => {
  return readConfigString(config, 'coin').toUpperCase()
}

export const resolveOkpayChannelTypeFromConfig = (config: PaymentChannelConfig) => {
  switch (resolveOkpayConfiguredCoin(config).toLowerCase()) {
    case 'usdt':
      return 'usdt'
    case 'trx':
      return 'trx'
    default:
      return ''
  }
}
