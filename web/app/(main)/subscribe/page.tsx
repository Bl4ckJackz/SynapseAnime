"use client";

import { useState } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { subscriptionService } from "@/services/subscription.service";
import { Button } from "@/components/ui/Button";
import { useToast } from "@/components/ui/Toast";

const PLANS = [
  {
    name: "Free",
    price: "$0",
    features: [
      "Watch anime with ads",
      "Limited manga reading",
      "Basic search",
    ],
  },
  {
    name: "Premium",
    price: "$4.99/mo",
    features: [
      "Ad-free streaming",
      "Unlimited manga reading",
      "Download episodes",
      "AI recommendations",
      "Priority support",
    ],
    recommended: true,
  },
];

export default function SubscribePage() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [loading, setLoading] = useState(false);

  const currentTier = user?.subscriptionTier || "free";

  async function handleSubscribe() {
    setLoading(true);
    try {
      const session = await subscriptionService.createCheckoutSession();
      window.location.href = session.url;
    } catch {
      toast("Failed to start checkout. Subscription endpoints may not be available yet.", "error");
    } finally {
      setLoading(false);
    }
  }

  async function handleCancel() {
    try {
      await subscriptionService.cancelSubscription();
      toast("Subscription cancelled", "info");
    } catch {
      toast("Failed to cancel subscription", "error");
    }
  }

  return (
    <div className="mx-auto max-w-3xl p-6">
      <h1 className="mb-2 text-2xl font-bold text-[var(--color-text)]">
        Subscription Plans
      </h1>
      <p className="mb-8 text-sm text-[var(--color-text-muted)]">
        Current plan:{" "}
        <span className="font-medium text-[var(--color-primary)]">
          {currentTier.charAt(0).toUpperCase() + currentTier.slice(1)}
        </span>
      </p>

      <div className="grid gap-6 md:grid-cols-2">
        {PLANS.map((plan) => {
          const isCurrentPlan =
            plan.name.toLowerCase() === currentTier;
          return (
            <div
              key={plan.name}
              className={`rounded-xl border p-6 ${
                plan.recommended
                  ? "border-[var(--color-primary)] bg-[var(--color-primary)]/5"
                  : "border-[var(--color-border)] bg-[var(--color-surface)]"
              }`}
            >
              {plan.recommended && (
                <span className="mb-3 inline-block rounded-full bg-[var(--color-primary)] px-3 py-0.5 text-xs font-medium text-white">
                  Recommended
                </span>
              )}
              <h2 className="text-xl font-bold text-[var(--color-text)]">
                {plan.name}
              </h2>
              <p className="mb-4 text-3xl font-bold text-[var(--color-text)]">
                {plan.price}
              </p>
              <ul className="mb-6 space-y-2">
                {plan.features.map((f) => (
                  <li
                    key={f}
                    className="flex items-center gap-2 text-sm text-[var(--color-text-muted)]"
                  >
                    <svg
                      className="h-4 w-4 text-[var(--color-success)]"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke="currentColor"
                      strokeWidth={2}
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        d="M5 13l4 4L19 7"
                      />
                    </svg>
                    {f}
                  </li>
                ))}
              </ul>
              {isCurrentPlan ? (
                <Button variant="secondary" disabled className="w-full">
                  Current Plan
                </Button>
              ) : plan.recommended ? (
                <Button
                  onClick={handleSubscribe}
                  loading={loading}
                  className="w-full"
                >
                  Upgrade
                </Button>
              ) : currentTier === "premium" ? (
                <Button
                  variant="danger"
                  onClick={handleCancel}
                  className="w-full"
                >
                  Downgrade
                </Button>
              ) : null}
            </div>
          );
        })}
      </div>
    </div>
  );
}
