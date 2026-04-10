"use client";

import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useAuth } from "@/contexts/AuthContext";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { useToast } from "@/components/ui/Toast";

export default function RegisterPage() {
  const router = useRouter();
  const { register } = useAuth();
  const { toast } = useToast();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [nickname, setNickname] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      await register(email, password, nickname || undefined);
      toast("Account created!", "success");
      router.push("/home");
    } catch (err: unknown) {
      const message =
        err && typeof err === "object" && "message" in err
          ? String(err.message)
          : "Registration failed";
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="rounded-xl border border-[var(--color-border)] bg-[var(--color-surface)] p-6">
      <h1 className="mb-1 text-2xl font-bold text-[var(--color-text)]">
        Create an account
      </h1>
      <p className="mb-6 text-sm text-[var(--color-text-muted)]">
        Join SynapseAnime and start streaming
      </p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <Input
          id="nickname"
          label="Nickname"
          placeholder="Your nickname (optional)"
          value={nickname}
          onChange={(e) => setNickname(e.target.value)}
        />
        <Input
          id="email"
          label="Email"
          type="email"
          placeholder="you@example.com"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          required
        />
        <Input
          id="password"
          label="Password"
          type="password"
          placeholder="Min 10 chars, upper+lower+digit"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          required
          minLength={10}
        />

        {error && (
          <p className="text-sm text-[var(--color-danger)]">{error}</p>
        )}

        <Button type="submit" loading={loading} className="w-full">
          Create Account
        </Button>
      </form>

      <p className="mt-4 text-center text-sm text-[var(--color-text-muted)]">
        Already have an account?{" "}
        <Link
          href="/login"
          className="text-[var(--color-primary)] hover:underline"
        >
          Sign in
        </Link>
      </p>
    </div>
  );
}
