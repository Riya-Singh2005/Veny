import { expect, test } from '@playwright/test'

// Requires the local Supabase stack (`supabase start`) and .env.local pointing at it.
test('home page shows the hero, live categories and verified services', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { level: 1, name: /Verified pros for every room/ })).toBeVisible()
  const list = page.getByTestId('category-list')
  await expect(list.getByRole('listitem')).toHaveCount(6)
  await expect(list).toContainText('Electrician')
  await expect(page.getByRole('heading', { name: 'Newly verified services' })).toBeVisible()
  // Only the verified vendor's active services are public (PD-02).
  await expect(page.getByRole('link', { name: /Fan and light installation/ }).first()).toBeVisible()
  await expect(page.getByText('Haircut at home')).toHaveCount(0)
})

test('hero search sends the chosen category to the services page', async ({ page }) => {
  await page.goto('/')
  await page.getByLabel('Service').selectOption('plumber')
  await page.getByRole('button', { name: 'Find a pro' }).click()
  await expect(page).toHaveURL(/\/services\?when=today&category=plumber/)
})

test('slot picker supports keyboard selection', async ({ page }) => {
  await page.goto('/design')
  const group = page.getByRole('radiogroup')
  await group.getByRole('radio', { name: '10:30' }).click()
  await expect(group.getByRole('radio', { name: '10:30' })).toHaveAttribute('aria-checked', 'true')
  await page.keyboard.press('ArrowRight')
  await expect(group.getByRole('radio', { name: '11:00' })).toHaveAttribute('aria-checked', 'true')
  // 11:30 is taken, so ArrowRight skips to 14:00.
  await page.keyboard.press('ArrowRight')
  await expect(group.getByRole('radio', { name: '14:00' })).toHaveAttribute('aria-checked', 'true')
})

test('unknown routes show the not-found page', async ({ page }) => {
  await page.goto('/this-route-does-not-exist')
  await expect(page.getByRole('heading', { name: 'Page not found' })).toBeVisible()
})
