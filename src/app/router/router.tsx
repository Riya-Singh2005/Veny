import { createBrowserRouter } from 'react-router'
import { PublicLayout } from '@/app/layouts/PublicLayout'
import { RootLayout } from '@/app/layouts/RootLayout'
import { HomePage } from '@/features/home/HomePage'
import { PlannedPage } from './PlannedPage'
import { RouteError } from './RouteError'

export const router = createBrowserRouter([
  {
    element: <RootLayout />,
    errorElement: <RouteError />,
    children: [
      {
        element: <PublicLayout />,
        children: [
          { index: true, element: <HomePage /> },
          { path: 'services', element: <PlannedPage title="Service search" milestone="M4" /> },
          { path: 'services/:slug', element: <PlannedPage title="Service detail" milestone="M4" /> },
          { path: 'login', element: <PlannedPage title="Log in" milestone="M3" /> },
          { path: 'signup', element: <PlannedPage title="Sign up" milestone="M3" /> },
          {
            path: 'design',
            lazy: async () => ({ Component: (await import('@/features/design-preview/DesignSystemPage')).DesignSystemPage }),
          },
          {
            path: 'design/service',
            lazy: async () => ({ Component: (await import('@/features/design-preview/ServicePreviewPage')).ServicePreviewPage }),
          },
        ],
      },
      {
        path: 'design/vendor/*',
        lazy: async () => ({ Component: (await import('@/features/design-preview/VendorPreviewPage')).VendorPreviewPage }),
      },
    ],
  },
])
