'use client'

import { useState, type FormEvent } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export function SignInForm() {
  const router = useRouter()
  const [email, setEmail] = useState('ananthuk012@gmail.com')
  const [password, setPassword] = useState('')
  const [errorMessage, setErrorMessage] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setErrorMessage('')
    setIsSubmitting(true)

    try {
      const supabase = createClient()
      const { error } = await supabase.auth.signInWithPassword({
        email: email.trim(),
        password,
      })

      if (error) {
        if (error.code === 'email_not_confirmed') {
          setErrorMessage('Confirm your email from the message in your inbox before signing in.')
        } else if (error.status === 429) {
          setErrorMessage('Too many sign-in attempts. Please wait and try again.')
        } else {
          setErrorMessage('Email or password did not match.')
        }
        return
      }

      router.replace('/auth/account')
      router.refresh()
    } catch {
      setErrorMessage('We could not connect to the account service. Please try again.')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <section className="rounded-2xl border border-border bg-card p-6 text-card-foreground shadow-xl sm:p-8">
      <p className="text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">Road Safety Mission</p>
      <h1 className="mt-3 text-3xl font-semibold tracking-tight">Welcome back</h1>
      <p className="mt-2 text-sm leading-6 text-muted-foreground">Sign in with the email and password you chose for your account.</p>
      <form className="mt-7 space-y-5" onSubmit={handleSubmit}>
        <div className="space-y-2">
          <label className="text-sm font-medium" htmlFor="signin-email">Email address</label>
          <input
            autoComplete="email"
            className="h-11 w-full rounded-lg border border-input bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            id="signin-email"
            name="email"
            onChange={(event) => setEmail(event.target.value)}
            required
            type="email"
            value={email}
          />
        </div>
        <div className="space-y-2">
          <label className="text-sm font-medium" htmlFor="signin-password">Password</label>
          <input
            autoComplete="current-password"
            className="h-11 w-full rounded-lg border border-input bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
            id="signin-password"
            name="password"
            onChange={(event) => setPassword(event.target.value)}
            required
            type="password"
            value={password}
          />
        </div>
        {errorMessage ? <p className="text-sm text-destructive" role="alert">{errorMessage}</p> : null}
        <button
          className="inline-flex h-11 w-full items-center justify-center rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
          disabled={isSubmitting}
          type="submit"
        >
          {isSubmitting ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
      <p className="mt-6 text-sm text-muted-foreground">
        New here?{' '}
        <Link className="font-semibold text-foreground underline underline-offset-4" href="/auth/sign-up">Create an account</Link>
      </p>
      <Link className="mt-5 inline-flex text-xs text-muted-foreground underline underline-offset-4" href="/index.html">
        Back to Road Safety Mission
      </Link>
    </section>
  )
}
