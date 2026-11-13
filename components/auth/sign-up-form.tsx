'use client'

import { useState, type FormEvent } from 'react'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

const requestedEmail = 'ananthuk012@gmail.com'

function getSignUpErrorMessage(error: { code?: string; status?: number }) {
  if (error.code === 'weak_password') return 'Choose a stronger password.'
  if (error.code === 'email_address_invalid') return 'Enter a valid email address.'
  if (error.code === 'email_address_not_authorized') {
    return 'This project cannot email that address yet. The project administrator must configure a custom email provider.'
  }
  if (error.code === 'over_email_send_rate_limit' || error.status === 429) {
    return 'Too many confirmation emails were requested. Please wait before trying again.'
  }
  return 'We could not start sign-up. Check your details or try signing in if you already have an account.'
}

export function SignUpForm() {
  const router = useRouter()
  const [email, setEmail] = useState(requestedEmail)
  const [password, setPassword] = useState('')
  const [confirmPassword, setConfirmPassword] = useState('')
  const [errorMessage, setErrorMessage] = useState('')
  const [confirmationSent, setConfirmationSent] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setErrorMessage('')

    if (password !== confirmPassword) {
      setErrorMessage('The passwords do not match.')
      return
    }

    setIsSubmitting(true)

    try {
      const supabase = createClient()
      const { data, error } = await supabase.auth.signUp({
        email: email.trim(),
        password,
        options: {
          emailRedirectTo:
            process.env.NEXT_PUBLIC_DEV_SUPABASE_REDIRECT_URL ??
            `${window.location.origin}/auth/callback`,
        },
      })

      if (error) {
        setErrorMessage(getSignUpErrorMessage(error))
        return
      }

      if (data.session) {
        router.replace('/auth/account')
        router.refresh()
        return
      }

      setConfirmationSent(true)
    } catch {
      setErrorMessage('We could not connect to the account service. Please try again.')
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <section className="rounded-2xl border border-border bg-card p-6 text-card-foreground shadow-xl sm:p-8">
      <p className="text-xs font-semibold uppercase tracking-[0.18em] text-muted-foreground">Road Safety Mission</p>
      <h1 className="mt-3 text-3xl font-semibold tracking-tight">Create your account</h1>
      <p className="mt-2 text-sm leading-6 text-muted-foreground">
        Save your sign-in securely with Supabase. Your email must be verified before the account is ready.
      </p>

      {confirmationSent ? (
        <div className="mt-7 rounded-xl border border-border bg-muted p-4" role="status" aria-live="polite">
          <h2 className="font-semibold">Check your inbox</h2>
          <p className="mt-2 text-sm leading-6 text-muted-foreground">
            If this address can be registered, Supabase will send a confirmation link. Follow it to activate the account, then sign in.
          </p>
          <Link className="mt-4 inline-flex text-sm font-semibold underline underline-offset-4" href="/auth/login">
            Go to sign in
          </Link>
        </div>
      ) : (
        <form className="mt-7 space-y-5" onSubmit={handleSubmit}>
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="signup-email">Email address</label>
            <input
              autoComplete="email"
              className="h-11 w-full rounded-lg border border-input bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
              id="signup-email"
              name="email"
              onChange={(event) => setEmail(event.target.value)}
              required
              type="email"
              value={email}
            />
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="signup-password">Password</label>
            <input
              autoComplete="new-password"
              className="h-11 w-full rounded-lg border border-input bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
              id="signup-password"
              minLength={8}
              name="password"
              onChange={(event) => setPassword(event.target.value)}
              required
              type="password"
              value={password}
            />
            <p className="text-xs text-muted-foreground">Use at least 8 characters.</p>
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium" htmlFor="signup-confirm-password">Confirm password</label>
            <input
              autoComplete="new-password"
              className="h-11 w-full rounded-lg border border-input bg-background px-3 text-sm outline-none focus-visible:ring-2 focus-visible:ring-ring"
              id="signup-confirm-password"
              minLength={8}
              name="confirmPassword"
              onChange={(event) => setConfirmPassword(event.target.value)}
              required
              type="password"
              value={confirmPassword}
            />
          </div>
          {errorMessage ? <p className="text-sm text-destructive" role="alert">{errorMessage}</p> : null}
          <button
            className="inline-flex h-11 w-full items-center justify-center rounded-lg bg-primary px-4 text-sm font-semibold text-primary-foreground transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-60"
            disabled={isSubmitting}
            type="submit"
          >
            {isSubmitting ? 'Creating account…' : 'Create account'}
          </button>
        </form>
      )}

      <p className="mt-6 text-sm text-muted-foreground">
        Already have an account?{' '}
        <Link className="font-semibold text-foreground underline underline-offset-4" href="/auth/login">Sign in</Link>
      </p>
      <Link className="mt-5 inline-flex text-xs text-muted-foreground underline underline-offset-4" href="/index.html">
        Back to Road Safety Mission
      </Link>
    </section>
  )
}
