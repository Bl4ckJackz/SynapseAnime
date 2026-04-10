"use client";

import { useState, useRef, useEffect } from "react";
import Link from "next/link";
import { useAuth } from "@/contexts/AuthContext";

export function UserMenu() {
  const { user, logout } = useAuth();
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <div ref={ref} className="relative">
      <button
        onClick={() => setOpen(!open)}
        className="flex h-8 w-8 items-center justify-center rounded-full bg-[var(--color-primary)] text-sm font-medium text-white hover:bg-[var(--color-primary-hover)] transition-colors"
      >
        {user?.nickname?.[0]?.toUpperCase() || user?.email?.[0]?.toUpperCase() || "U"}
      </button>

      {open && (
        <div className="absolute right-0 top-full mt-2 w-48 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] py-1 shadow-lg">
          <div className="border-b border-[var(--color-border)] px-3 py-2">
            <p className="text-sm font-medium text-[var(--color-text)]">
              {user?.nickname || "User"}
            </p>
            <p className="text-xs text-[var(--color-text-muted)]">
              {user?.email}
            </p>
          </div>
          <Link
            href="/profile"
            onClick={() => setOpen(false)}
            className="block px-3 py-2 text-sm text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text)]"
          >
            Profile
          </Link>
          <Link
            href="/settings"
            onClick={() => setOpen(false)}
            className="block px-3 py-2 text-sm text-[var(--color-text-muted)] hover:bg-[var(--color-surface-hover)] hover:text-[var(--color-text)]"
          >
            Settings
          </Link>
          <button
            onClick={() => {
              logout();
              setOpen(false);
            }}
            className="block w-full px-3 py-2 text-left text-sm text-[var(--color-danger)] hover:bg-[var(--color-surface-hover)]"
          >
            Logout
          </button>
        </div>
      )}
    </div>
  );
}
