import { expect, test } from '@playwright/test'

// Requires the local Supabase stack (`supabase start`) and .env.local pointing at it.
test('home page loads categories from Supabase as an anonymous user', async ({ page }) => {
  await page.goto('/')
  await expect(page.getByRole('heading', { name: 'Veny' })).toBeVisible()
  const list = page.getByTestId('category-list')
  await expect(list.getByRole('listitem')).toHaveCount(6)
  await expect(list).toContainText('Electrician')
})

test('unknown routes show the not-found page', async ({ page }) => {
  await page.goto('/this-route-does-not-exist')
  await expect(page.getByRole('heading', { name: 'Page not found' })).toBeVisible()
})
