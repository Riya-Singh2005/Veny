import type { Enums } from '@/lib/supabase/client'

/** Sample data for design previews only. Never shown as live records. */
export const previewService = {
  title: 'Fan and light installation',
  category: 'Electrician',
  vendor: 'Ravi Kumar Electricals',
  area: 'Indiranagar, Bengaluru',
  pricePaise: 49900,
  durationMinutes: 60,
  rating: 4.8,
  reviewCount: 37,
  description:
    'Ceiling fan, light fixture and switchboard installation. Ravi brings his own tools, tests every circuit before leaving, and clears up after the job.',
  included: ['Fitting of one ceiling fan or light fixture', 'Switchboard check and safe wiring', 'Testing in your presence', 'Old fixture taken down on request'],
  reviews: [
    { name: 'Neha Iyer', date: '9 Nov 2026', rating: 5, body: 'Arrived on time, fitted two fans in under an hour and explained the new regulator.' },
    { name: 'Kabir Malhotra', date: '28 Oct 2026', rating: 4, body: 'Neat work. Had to come back for a loose cover plate, which he fixed the same evening.' },
  ],
}

export const previewSlots = [
  { start: '2026-11-19T04:30:00Z', label: '10:00', available: false },
  { start: '2026-11-19T05:00:00Z', label: '10:30', available: true },
  { start: '2026-11-19T05:30:00Z', label: '11:00', available: true },
  { start: '2026-11-19T06:00:00Z', label: '11:30', available: false },
  { start: '2026-11-19T08:30:00Z', label: '14:00', available: true },
  { start: '2026-11-19T09:00:00Z', label: '14:30', available: true },
  { start: '2026-11-19T10:30:00Z', label: '16:00', available: true },
  { start: '2026-11-19T11:00:00Z', label: '16:30', available: true },
]

export const previewDays = ['2026-11-19', '2026-11-20', '2026-11-21', '2026-11-22', '2026-11-23']

type Status = Enums<'booking_status'>

export const previewRequests = [
  { ref: 'VN-2394', customer: 'Aarav Shah', service: 'Fan and light installation', when: 'Thu 19 Nov, 10:30', area: 'HAL 2nd Stage', pricePaise: 49900 },
  { ref: 'VN-2396', customer: 'Priya Nair', service: 'Home wiring repair', when: 'Fri 20 Nov, 14:00', area: 'Domlur', pricePaise: 79900 },
]

export const previewDay: { time: string; customer: string; service: string; area: string; status: Status }[] = [
  { time: '09:30', customer: 'Rohan Gupta', service: 'Home wiring repair', area: 'Indiranagar', status: 'completed' },
  { time: '12:00', customer: 'Meera Joshi', service: 'Fan and light installation', area: 'Jeevan Bima Nagar', status: 'in_progress' },
  { time: '15:00', customer: 'Sana Qureshi', service: 'Fan and light installation', area: 'Ulsoor', status: 'confirmed' },
  { time: '17:30', customer: 'Vikram Rao', service: 'Home wiring repair', area: 'Old Airport Road', status: 'confirmed' },
]
