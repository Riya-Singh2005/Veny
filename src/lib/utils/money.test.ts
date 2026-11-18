import { formatPrice } from './money'

describe('formatPrice', () => {
  it('formats paise as rupees', () => {
    expect(formatPrice(49900)).toBe('₹499')
    expect(formatPrice(149950)).toBe('₹1,499.5')
  })

  it('uses Indian digit grouping', () => {
    expect(formatPrice(12345600)).toBe('₹1,23,456')
  })
})
