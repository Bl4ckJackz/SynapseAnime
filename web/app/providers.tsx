"use client";

import { AuthProvider } from "@/contexts/AuthContext";
import { ToastProvider } from "@/components/ui/Toast";
import { SourceProvider } from "@/contexts/SourceContext";
import { SocketProvider } from "@/contexts/SocketContext";

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <AuthProvider>
      <ToastProvider>
        <SourceProvider>
          <SocketProvider>{children}</SocketProvider>
        </SourceProvider>
      </ToastProvider>
    </AuthProvider>
  );
}
