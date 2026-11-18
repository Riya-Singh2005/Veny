import { isRouteErrorResponse, Link, useRouteError } from 'react-router'

export function RouteError() {
  const error = useRouteError()
  const notFound = isRouteErrorResponse(error) && error.status === 404
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col items-center justify-center gap-4 px-6 text-center">
      <h1 className="text-2xl font-semibold">{notFound ? 'Page not found' : 'Something went wrong'}</h1>
      <p className="text-muted-foreground">
        {notFound ? 'The page you are looking for does not exist.' : 'Please try again in a moment.'}
      </p>
      <Link to="/" className="font-medium underline underline-offset-4">
        Go to home
      </Link>
    </main>
  )
}
