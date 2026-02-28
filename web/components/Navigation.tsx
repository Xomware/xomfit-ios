'use client'

import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { useState } from 'react'

interface NavigationProps {
  user?: { email?: string; user_metadata?: { full_name?: string; avatar_url?: string } } | null
}

export default function Navigation({ user }: NavigationProps) {
  const pathname = usePathname()
  const [menuOpen, setMenuOpen] = useState(false)

  const navLinks = [
    { href: '/dashboard', label: 'Dashboard' },
    { href: '/workouts', label: 'Workouts' },
    { href: '/analytics', label: 'Analytics' },
    { href: '/feed', label: 'Feed' },
  ]

  const isActive = (href: string) => pathname?.startsWith(href)

  return (
    <nav className="fixed top-0 left-0 right-0 z-50 bg-black/95 backdrop-blur border-b border-gray-800">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2">
            <div className="w-8 h-8 bg-green-500 rounded-lg flex items-center justify-center">
              <span className="text-black font-black text-sm">X</span>
            </div>
            <span className="font-black text-white text-xl tracking-tight">XomFit</span>
          </Link>

          {/* Desktop nav */}
          {user && (
            <div className="hidden md:flex items-center gap-1">
              {navLinks.map(link => (
                <Link
                  key={link.href}
                  href={link.href}
                  className={`px-4 py-2 rounded-lg text-sm font-medium transition-colors ${
                    isActive(link.href)
                      ? 'bg-green-500/20 text-green-400'
                      : 'text-gray-400 hover:text-white hover:bg-gray-800'
                  }`}
                >
                  {link.label}
                </Link>
              ))}
            </div>
          )}

          {/* Auth section */}
          <div className="flex items-center gap-3">
            {user ? (
              <div className="flex items-center gap-3">
                {user.user_metadata?.avatar_url ? (
                  <img
                    src={user.user_metadata.avatar_url}
                    alt="Avatar"
                    className="w-8 h-8 rounded-full border border-gray-700"
                  />
                ) : (
                  <div className="w-8 h-8 rounded-full bg-green-500/20 border border-green-500/40 flex items-center justify-center">
                    <span className="text-green-400 text-xs font-bold">
                      {(user.user_metadata?.full_name || user.email || 'U')[0].toUpperCase()}
                    </span>
                  </div>
                )}
                <span className="hidden md:block text-sm text-gray-400">
                  {user.user_metadata?.full_name || user.email}
                </span>
                <form action="/auth/signout" method="POST">
                  <button
                    type="submit"
                    className="text-sm text-gray-500 hover:text-gray-300 transition-colors"
                  >
                    Sign out
                  </button>
                </form>
              </div>
            ) : (
              <div className="flex items-center gap-2">
                <Link
                  href="/login"
                  className="text-sm text-gray-400 hover:text-white transition-colors px-3 py-1.5"
                >
                  Sign in
                </Link>
                <Link
                  href="/login"
                  className="text-sm bg-green-500 hover:bg-green-400 text-black font-bold px-4 py-1.5 rounded-lg transition-colors"
                >
                  Get Started
                </Link>
              </div>
            )}

            {/* Mobile menu button */}
            {user && (
              <button
                className="md:hidden p-2 text-gray-400 hover:text-white"
                onClick={() => setMenuOpen(!menuOpen)}
              >
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  {menuOpen ? (
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                  ) : (
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
                  )}
                </svg>
              </button>
            )}
          </div>
        </div>

        {/* Mobile menu */}
        {user && menuOpen && (
          <div className="md:hidden py-3 border-t border-gray-800">
            {navLinks.map(link => (
              <Link
                key={link.href}
                href={link.href}
                className={`block px-4 py-2.5 text-sm font-medium transition-colors ${
                  isActive(link.href)
                    ? 'text-green-400 bg-green-500/10'
                    : 'text-gray-400 hover:text-white'
                }`}
                onClick={() => setMenuOpen(false)}
              >
                {link.label}
              </Link>
            ))}
          </div>
        )}
      </div>
    </nav>
  )
}
