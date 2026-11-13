import type { Metadata } from 'next'
import { SignInForm } from '@/components/auth/sign-in-form'

export const metadata: Metadata = {
  title: 'Sign in | Road Safety Mission',
  robots: { index: false, follow: false },
}

export default function SignInPage() {
  return (
    <main className="flex min-h-svh items-center justify-center bg-background px-4 py-12 text-foreground">
      <div className="w-full max-w-md">
        <SignInForm />
      </div>
    </main>
  )
}
