// src/types/streaming.types.ts
export interface StreamingSource {
  type: 'external' | 'internal' | 'direct_link';
  provider?: string; // e.g., 'gogoanime', 'internal-cdn'
  url: string;
  quality: '1080p' | '720p' | '480p' | '360p';
  language: 'sub' | 'dub';
  priority: number; // for fallback ordering
}