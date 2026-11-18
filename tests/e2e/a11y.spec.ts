import AxeBuilder from '@axe-core/playwright'
import { expect, test } from '@playwright/test'

// WCAG 2.2 AA scan of every M2 screen. Requires the local Supabase stack.
const screens = ['/', '/design', '/design/service', '/design/vendor', '/services']

for (const path of screens) {
  test(`no WCAG AA violations on ${path}`, async ({ page }) => {
    await page.goto(path)
    await page.waitForLoadState('networkidle')
    const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa']).analyze()
    expect(results.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(', ')}`)).toEqual([])
  })
}

test('light theme on the design system page passes WCAG AA', async ({ page }) => {
  await page.goto('/design')
  await page.getByRole('button', { name: 'Light' }).click()
  const results = await new AxeBuilder({ page }).withTags(['wcag2a', 'wcag2aa']).analyze()
  expect(results.violations.map((v) => `${v.id}: ${v.nodes.map((n) => n.target.join(' ')).join(', ')}`)).toEqual([])
})
