import { AppError, toAppError, unwrap } from './errors'

describe('toAppError', () => {
  it('keeps user-facing RPC messages with their hint', () => {
    const e = toAppError({ code: 'P0001', message: 'You cannot book your own service', hint: 'own_service' })
    expect(e.code).toBe('RULE')
    expect(e.message).toBe('You cannot book your own service')
    expect(e.hint).toBe('own_service')
  })

  it('maps invalid transitions', () => {
    expect(toAppError({ code: 'P0001', message: 'x', hint: 'invalid_transition' }).code).toBe('INVALID_TRANSITION')
  })

  it('maps slot conflicts (exclusion violation) to CONFLICT', () => {
    const e = toAppError({ code: '23P01', message: 'This time slot was just taken.', hint: 'slot_taken' })
    expect(e.code).toBe('CONFLICT')
    expect(e.message).toContain('slot')
  })

  it('hides raw database messages that are not meant for users', () => {
    const e = toAppError({ code: '23505', message: 'duplicate key value violates unique constraint "x"' })
    expect(e.code).toBe('CONFLICT')
    expect(e.message).not.toContain('constraint')
  })

  it('maps RLS and permission errors to FORBIDDEN', () => {
    expect(toAppError({ code: '42501', message: 'permission denied for table profiles' }).code).toBe('FORBIDDEN')
  })

  it('maps network failures', () => {
    expect(toAppError(new TypeError('Failed to fetch')).code).toBe('NETWORK')
  })

  it('passes AppError through', () => {
    const original = new AppError('NOT_FOUND', 'gone')
    expect(toAppError(original)).toBe(original)
  })
})

describe('unwrap', () => {
  it('returns data when there is no error', () => {
    expect(unwrap({ data: [1, 2], error: null })).toEqual([1, 2])
  })

  it('throws an AppError on error', () => {
    expect(() =>
      unwrap({ data: null, error: { code: 'P0002', message: 'Booking not found', hint: 'not_found' } }),
    ).toThrow('Booking not found')
  })
})
