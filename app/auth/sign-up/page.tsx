import type { Metadata } from 'next'
import { SignUpForm } from '@/components/auth/sign-up-form'

export const metadata: Metadata = {
  title: 'Create an account | Road Safety Mission',
  robots: { index: false, follow: false },
}

export default function SignUpPage() {
  return (
    <main className="flex min-h-svh items-center justify-center bg-background px-4 py-12 text-foreground">
      <div className="w-full max-w-md">
        <SignUpForm />
      </div>
    </main>
  )
}
