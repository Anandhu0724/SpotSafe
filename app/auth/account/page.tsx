import type { Metadata } from 'next'
import Link from 'next/link'
import { redirect } from 'next/navigation'
import { SignOutButton } from '@/components/auth/sign-out-button'
import { createClient } from '@/lib/supabase/server'

export const metadata: Metadata = {
  title: 'Your account | Road Safety Mission',
  robots: { index: false, follow: false },
}

export default async function AccountPage() {
  const supabase = await createClient()
  const { data, error } = await supabase.auth.getUser()

  if (error || !data.user) redirect('/auth/login')

  return (
    <main className="flex min-h-svh items-center justify-center bg-background px-4 py-12 text-foreground">
      <section className="w-full max-w-md rounded-2xl border border-border bg-card p-6 text-card-foreground shadow-xl sm:p-8">
        <p className="text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">Road Safety Mission</p>
        <h1 className="mt-3 text-3xl font-semibold tracking-tight">Your account</h1>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">You are signed in with a verified account.</p>
        <div className="mt-7 rounded-xl border border-border bg-muted p-4">
          <p className="text-xs font-medium uppercase tracking-wide text-muted-foreground">Signed in as</p>
          <p className="mt-1 break-all text-sm font-semibold">{data.user.email}</p>
        </div>
        <div className="mt-6">
          <SignOutButton />
        </div>
        <Link className="mt-6 inline-flex text-sm font-semibold underline underline-offset-4" href="/index.html">
          Return to Road Safety Mission
        </Link>
      </section>
    </main>
  )
}
