import type { Metadata } from 'next'
import Link from 'next/link'

export const metadata: Metadata = {
  title: 'Account link unavailable | Road Safety Mission',
  robots: { index: false, follow: false },
}

export default function AuthErrorPage() {
  return (
    <main className="flex min-h-svh items-center justify-center bg-background px-4 py-12 text-foreground">
      <section className="w-full max-w-md rounded-2xl border border-border bg-card p-6 text-card-foreground shadow-xl sm:p-8">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">Road Safety Mission</p>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight">That account link could not be used</h1>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">
          The link may have expired or already been used. Request a new confirmation email, then try again.
        </p>
        <Link className="mt-6 inline-flex h-10 items-center rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground" href="/auth/sign-up">
          Return to sign up
        </Link>
      </section>
    </main>
  )
}
