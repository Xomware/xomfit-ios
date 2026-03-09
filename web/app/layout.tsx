import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'XomFit — Track Your Gains',
  description: 'The fitness tracker for serious lifters. Log workouts, track PRs, and crush your goals with XomFit.',
  keywords: ['fitness', 'workout tracker', 'gym', 'strength training', 'personal records'],
  openGraph: {
    title: 'XomFit — Track Your Gains',
    description: 'The fitness tracker for serious lifters.',
    type: 'website',
  },
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en" className="dark">
      <body className="bg-black text-white antialiased min-h-screen">
        {children}
      </body>
    </html>
  )
}
