import { dateInTimezone, formatDayLabel, formatDuration, formatSlotTime } from './time'

describe('time utils', () => {
  it('uses the Kolkata calendar date even when UTC is still the previous day', () => {
    // 2026-11-18 20:00 UTC is 2026-11-19 01:30 IST
    expect(dateInTimezone(new Date('2026-11-18T20:00:00Z'))).toBe('2026-11-19')
    expect(dateInTimezone(new Date('2026-11-18T20:00:00Z'), 'Asia/Kolkata', 1)).toBe('2026-11-20')
  })

  it('formats slot times in 24-hour vendor time', () => {
    expect(formatSlotTime('2026-11-18T11:00:00Z')).toBe('16:30')
  })

  it('formats day labels and durations', () => {
    expect(formatDayLabel('2026-11-18')).toMatch(/Wed.*18.*Nov/)
    expect(formatDuration(45)).toBe('45 min')
    expect(formatDuration(60)).toBe('1 h')
    expect(formatDuration(90)).toBe('1 h 30 min')
  })
})
