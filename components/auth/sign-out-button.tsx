'use client'

import { useState } from 'react'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export function SignOutButton() {
  const router = useRouter()
  const [isSigningOut, setIsSigningOut] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')

  async function handleSignOut() {
    setErrorMessage('')
    setIsSigningOut(true)

    try {
      const { error } = await createClient().auth.signOut()
      if (error) {
        setErrorMessage('We could not sign you out. Please try again.')
        return
      }
      router.replace('/auth/login')
      router.refresh()
    } catch {
      setErrorMessage('We could not connect to the account service. Please try again.')
    } finally {
      setIsSigningOut(false)
    }
  }

  return (
    <div>
      <button
        className="inline-flex h-10 items-center justify-center rounded-lg border border-input px-4 text-sm font-semibold transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-60"
        disabled={isSigningOut}
        onClick={handleSignOut}
        type="button"
      >
        {isSigningOut ? 'Signing out…' : 'Sign out'}
      </button>
      {errorMessage ? <p className="mt-3 text-sm text-destructive" role="alert">{errorMessage}</p> : null}
    </div>
  )
}
