const formatters = new Map<string, Intl.NumberFormat>()

/** Formats integer minor units (paise) as a localized currency string, e.g. 49900 -> "₹499". */
export function formatPrice(minorUnits: number, currency = 'INR', locale = 'en-IN'): string {
  const key = `${locale}:${currency}`
  let f = formatters.get(key)
  if (!f) {
    f = new Intl.NumberFormat(locale, { style: 'currency', currency, minimumFractionDigits: 0, maximumFractionDigits: 2 })
    formatters.set(key, f)
  }
  return f.format(minorUnits / 100)
}
