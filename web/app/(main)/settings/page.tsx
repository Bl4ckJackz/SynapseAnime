"use client";

import { useState, useEffect } from "react";
import { useAuth } from "@/contexts/AuthContext";
import { userService } from "@/services/user.service";
import { notificationService } from "@/services/notification.service";
import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { useToast } from "@/components/ui/Toast";
import type { NotificationSettings } from "@/types/user";

export default function SettingsPage() {
  const { user, refreshProfile } = useAuth();
  const { toast } = useToast();
  const [nickname, setNickname] = useState(user?.nickname || "");
  const [notifSettings, setNotifSettings] =
    useState<NotificationSettings | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    notificationService.getSettings().then(setNotifSettings).catch(() => {});
  }, []);

  async function handleSaveProfile(e: React.FormEvent) {
    e.preventDefault();
    setSaving(true);
    try {
      await userService.updateProfile({ nickname: nickname || undefined });
      await refreshProfile();
      toast("Profile updated!", "success");
    } catch {
      toast("Failed to update profile", "error");
    } finally {
      setSaving(false);
    }
  }

  async function handleToggleNotifications() {
    if (!notifSettings) return;
    try {
      const updated = await notificationService.updateSettings({
        globalEnabled: !notifSettings.globalEnabled,
      });
      setNotifSettings(updated);
      toast(
        updated.globalEnabled
          ? "Notifications enabled"
          : "Notifications disabled",
        "info",
      );
    } catch {
      toast("Failed to update notifications", "error");
    }
  }

  async function handleSavePreferences() {
    try {
      await userService.updatePreferences({
        preferredLanguages:
          user?.preference?.preferredLanguages || [],
        preferredGenres: user?.preference?.preferredGenres || [],
      });
      toast("Preferences saved!", "success");
    } catch {
      toast("Failed to save preferences", "error");
    }
  }

  return (
    <div className="mx-auto max-w-2xl p-6">
      <h1 className="mb-6 text-2xl font-bold text-[var(--color-text)]">
        Settings
      </h1>

      {/* Profile */}
      <section className="mb-8 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6">
        <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
          Profile
        </h2>
        <form onSubmit={handleSaveProfile} className="space-y-4">
          <Input
            id="email"
            label="Email"
            value={user?.email || ""}
            disabled
          />
          <Input
            id="nickname"
            label="Nickname"
            value={nickname}
            onChange={(e) => setNickname(e.target.value)}
            placeholder="Your nickname"
          />
          <Button type="submit" loading={saving}>
            Save Profile
          </Button>
        </form>
      </section>

      {/* Notifications */}
      <section className="mb-8 rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6">
        <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
          Notifications
        </h2>
        <div className="flex items-center justify-between">
          <div>
            <p className="text-sm font-medium text-[var(--color-text)]">
              Push Notifications
            </p>
            <p className="text-xs text-[var(--color-text-muted)]">
              Receive notifications for new episodes and updates
            </p>
          </div>
          <button
            onClick={handleToggleNotifications}
            className={`relative h-6 w-11 rounded-full transition-colors ${
              notifSettings?.globalEnabled
                ? "bg-[var(--color-primary)]"
                : "bg-[var(--color-border)]"
            }`}
          >
            <span
              className={`absolute top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${
                notifSettings?.globalEnabled
                  ? "translate-x-5"
                  : "translate-x-0.5"
              }`}
            />
          </button>
        </div>
      </section>

      {/* Preferences */}
      <section className="rounded-lg border border-[var(--color-border)] bg-[var(--color-surface)] p-6">
        <h2 className="mb-4 text-lg font-semibold text-[var(--color-text)]">
          Preferences
        </h2>
        <p className="mb-4 text-sm text-[var(--color-text-muted)]">
          Languages: {user?.preference?.preferredLanguages?.join(", ") || "Not set"}
        </p>
        <p className="mb-4 text-sm text-[var(--color-text-muted)]">
          Genres: {user?.preference?.preferredGenres?.join(", ") || "Not set"}
        </p>
        <Button variant="secondary" onClick={handleSavePreferences}>
          Save Preferences
        </Button>
      </section>
    </div>
  );
}
