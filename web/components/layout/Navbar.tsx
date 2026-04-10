"use client";

import Link from "next/link";
import { UserMenu } from "./UserMenu";
import { useAuth } from "@/contexts/AuthContext";

export function Navbar() {
  const { isAuthenticated } = useAuth();

  return (
    <header className="sticky top-0 z-40 flex h-14 items-center justify-between border-b border-[var(--color-border)] bg-[var(--color-bg)]/80 px-4 backdrop-blur-md lg:px-6">
      <Link href="/home" className="flex items-center gap-2">
        <span className="text-lg font-bold text-[var(--color-primary)]">
          SynapseAnime
        </span>
      </Link>

      <div className="flex items-center gap-3">
        {isAuthenticated ? (
          <UserMenu />
        ) : (
          <Link
            href="/login"
            className="rounded-lg bg-[var(--color-primary)] px-4 py-1.5 text-sm font-medium text-white hover:bg-[var(--color-primary-hover)] transition-colors"
          >
            Login
          </Link>
        )}
      </div>
    </header>
  );
}
