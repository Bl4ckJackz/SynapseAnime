"use client";

import { cn } from "@/lib/utils";
import {
  useEffect,
  useState,
  useCallback,
  createContext,
  useContext,
} from "react";

interface ToastItem {
  id: string;
  message: string;
  type: "success" | "error" | "info";
}

interface ToastContextType {
  toast: (message: string, type?: ToastItem["type"]) => void;
}

const ToastContext = createContext<ToastContextType>({ toast: () => {} });

export function useToast() {
  return useContext(ToastContext);
}

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const toast = useCallback(
    (message: string, type: ToastItem["type"] = "info") => {
      const id = crypto.randomUUID();
      setToasts((prev) => [...prev, { id, message, type }]);
    },
    [],
  );

  return (
    <ToastContext.Provider value={{ toast }}>
      {children}
      <div className="fixed bottom-4 right-4 z-50 flex flex-col gap-2">
        {toasts.map((t) => (
          <ToastMessage
            key={t.id}
            item={t}
            onDismiss={(id) =>
              setToasts((prev) => prev.filter((x) => x.id !== id))
            }
          />
        ))}
      </div>
    </ToastContext.Provider>
  );
}

function ToastMessage({
  item,
  onDismiss,
}: {
  item: ToastItem;
  onDismiss: (id: string) => void;
}) {
  useEffect(() => {
    const timer = setTimeout(() => onDismiss(item.id), 4000);
    return () => clearTimeout(timer);
  }, [item.id, onDismiss]);

  const colors = {
    success: "border-[var(--color-success)] bg-[var(--color-success)]/10",
    error: "border-[var(--color-danger)] bg-[var(--color-danger)]/10",
    info: "border-[var(--color-primary)] bg-[var(--color-primary)]/10",
  };

  return (
    <div
      className={cn(
        "rounded-lg border px-4 py-3 text-sm text-[var(--color-text)] shadow-lg transition-all",
        colors[item.type],
      )}
    >
      {item.message}
    </div>
  );
}
