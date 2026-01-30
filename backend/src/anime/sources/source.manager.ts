import { Injectable, NotFoundException } from '@nestjs/common';
import { AnimeSource, AnimeFilters } from './anime-source.interface';
import { DefaultDbSource } from './default-db.source';
import { LocalFileSource } from './local-file.source';
import { JikanSource } from './jikan.source';
import { AnimeUnitySource } from './animeunity.source';
import { HiAnimeSource } from './hianime.source';

@Injectable()
export class SourceManager {
  private sources: Map<string, AnimeSource> = new Map();
  private activeSourceId: string;

  constructor(
    private readonly defaultSource: DefaultDbSource,
    private readonly localSource: LocalFileSource,
    private readonly jikanSource: JikanSource,
    private readonly animeUnitySource: AnimeUnitySource,
    private readonly hiAnimeSource: HiAnimeSource,
  ) {
    this.registerSource(defaultSource);
    this.registerSource(localSource);
    this.registerSource(jikanSource);
    this.registerSource(animeUnitySource);
    this.registerSource(hiAnimeSource);
    this.activeSourceId = jikanSource.id;
  }

  registerSource(source: AnimeSource) {
    this.sources.set(source.id, source);
    console.log(`Registered anime source: ${source.name} (${source.id})`);
  }

  getSources() {
    return Array.from(this.sources.values()).map((s) => ({
      id: s.id,
      name: s.name,
      description: s.description,
      isActive: s.id === this.activeSourceId,
    }));
  }

  getSource(id: string): AnimeSource | undefined {
    return this.sources.get(id);
  }

  setActiveSource(id: string) {
    if (!this.sources.has(id)) {
      throw new NotFoundException(`Source ${id} not found`);
    }
    this.activeSourceId = id;
  }

  getActiveSource(): AnimeSource {
    const source = this.sources.get(this.activeSourceId);
    if (!source) {
      // Fallback to default if active not found (safety net)
      return this.defaultSource;
    }
    return source;
  }
}
