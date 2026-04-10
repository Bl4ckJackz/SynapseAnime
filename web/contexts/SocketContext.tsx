"use client";

import {
  createContext,
  useContext,
  useEffect,
  useState,
  useCallback,
  type ReactNode,
} from "react";
import { io, type Socket } from "socket.io-client";
import { useAuth } from "@/contexts/AuthContext";
import type { Download } from "@/types/download";

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:3005";

interface SocketContextType {
  downloadSocket: Socket | null;
  activeDownloads: Download[];
  isConnected: boolean;
}

const SocketContext = createContext<SocketContextType>({
  downloadSocket: null,
  activeDownloads: [],
  isConnected: false,
});

export function useSocket() {
  return useContext(SocketContext);
}

export function SocketProvider({ children }: { children: ReactNode }) {
  const { token, isAuthenticated } = useAuth();
  const [downloadSocket, setDownloadSocket] = useState<Socket | null>(null);
  const [activeDownloads, setActiveDownloads] = useState<Download[]>([]);
  const [isConnected, setIsConnected] = useState(false);

  useEffect(() => {
    if (!isAuthenticated || !token) {
      downloadSocket?.disconnect();
      setDownloadSocket(null);
      setIsConnected(false);
      return;
    }

    const socket = io(`${API_BASE_URL}/downloads`, {
      auth: { token },
      transports: ["websocket", "polling"],
    });

    socket.on("connect", () => setIsConnected(true));
    socket.on("disconnect", () => setIsConnected(false));

    socket.on("download_progress", (download: Download) => {
      setActiveDownloads((prev) => {
        const idx = prev.findIndex((d) => d.id === download.id);
        if (idx >= 0) {
          const next = [...prev];
          next[idx] = download;
          return next;
        }
        return [...prev, download];
      });
    });

    setDownloadSocket(socket);

    return () => {
      socket.disconnect();
    };
  }, [isAuthenticated, token]);

  return (
    <SocketContext.Provider
      value={{ downloadSocket, activeDownloads, isConnected }}
    >
      {children}
    </SocketContext.Provider>
  );
}
