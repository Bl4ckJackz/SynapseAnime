"use client";

import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  type ReactNode,
} from "react";
import type { AnimeSource } from "@/types/anime";
import { animeService } from "@/services/anime.service";

interface SourceContextType {
  activeSource: AnimeSource | null;
  sources: AnimeSource[];
  loading: boolean;
  switchSource: (id: string) => Promise<void>;
}

const SourceContext = createContext<SourceContextType>({
  activeSource: null,
  sources: [],
  loading: true,
  switchSource: async () => {},
});

export function SourceProvider({ children }: { children: ReactNode }) {
  const [sources, setSources] = useState<AnimeSource[]>([]);
  const [activeSource, setActiveSource] = useState<AnimeSource | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    animeService
      .getSources()
      .then((data) => {
        setSources(data);
        const active = data.find((s) => s.isActive) ?? data[0] ?? null;
        setActiveSource(active);
      })
      .catch(() => {
        // Sources may not be available yet
      })
      .finally(() => setLoading(false));
  }, []);

  const switchSource = useCallback(
    async (id: string) => {
      await animeService.setActiveSource(id);
      const updated = sources.map((s) => ({
        ...s,
        isActive: s.id === id,
      }));
      setSources(updated);
      setActiveSource(updated.find((s) => s.id === id) ?? null);
    },
    [sources],
  );

  return (
    <SourceContext.Provider
      value={{ activeSource, sources, loading, switchSource }}
    >
      {children}
    </SourceContext.Provider>
  );
}

export function useSource() {
  return useContext(SourceContext);
}
