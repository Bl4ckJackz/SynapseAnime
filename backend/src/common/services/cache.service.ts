import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

interface CacheEntry<T> {
    data: T;
    expiry: number;
    etag?: string;
}

@Injectable()
export class CacheService {
    private readonly logger = new Logger(CacheService.name);
    private readonly cache = new Map<string, CacheEntry<unknown>>();

    // Default TTLs in seconds
    private readonly defaultTTLs: Record<string, number> = {
        jikan: 86400,      // 24 hours
        mangahook: 3600,   // 1 hour
        mangadex: 21600,   // 6 hours
        default: 3600,     // 1 hour
    };

    constructor(private readonly configService: ConfigService) {
        // Override with environment config if available
        const jikanTTL = this.configService.get<number>('JIKAN_CACHE_TTL');
        const mangahookTTL = this.configService.get<number>('MANGAHOOK_CACHE_TTL');
        const mangadexTTL = this.configService.get<number>('MANGADEX_CACHE_TTL');

        if (jikanTTL) this.defaultTTLs.jikan = jikanTTL;
        if (mangahookTTL) this.defaultTTLs.mangahook = mangahookTTL;
        if (mangadexTTL) this.defaultTTLs.mangadex = mangadexTTL;

        // Clean expired entries every 5 minutes
        setInterval(() => this.cleanExpired(), 300000);
    }

    get<T>(key: string): T | null {
        const entry = this.cache.get(key) as CacheEntry<T> | undefined;

        if (!entry) {
            return null;
        }

        if (Date.now() > entry.expiry) {
            this.cache.delete(key);
            return null;
        }

        this.logger.debug(`Cache hit for key: ${key}`);
        return entry.data;
    }

    set<T>(key: string, data: T, apiName?: string, etag?: string): void {
        const ttl = apiName ? (this.defaultTTLs[apiName] || this.defaultTTLs.default) : this.defaultTTLs.default;
        const expiry = Date.now() + ttl * 1000;

        this.cache.set(key, { data, expiry, etag });
        this.logger.debug(`Cached key: ${key} with TTL: ${ttl}s`);
    }

    getWithEtag<T>(key: string): { data: T | null; etag?: string } {
        const entry = this.cache.get(key) as CacheEntry<T> | undefined;

        if (!entry) {
            return { data: null };
        }

        if (Date.now() > entry.expiry) {
            // Return stale data with etag for revalidation
            return { data: entry.data, etag: entry.etag };
        }

        return { data: entry.data, etag: entry.etag };
    }

    updateExpiry(key: string, apiName?: string): void {
        const entry = this.cache.get(key);
        if (entry) {
            const ttl = apiName ? (this.defaultTTLs[apiName] || this.defaultTTLs.default) : this.defaultTTLs.default;
            entry.expiry = Date.now() + ttl * 1000;
        }
    }

    delete(key: string): void {
        this.cache.delete(key);
    }

    clear(prefix?: string): void {
        if (prefix) {
            for (const key of this.cache.keys()) {
                if (key.startsWith(prefix)) {
                    this.cache.delete(key);
                }
            }
        } else {
            this.cache.clear();
        }
    }

    private cleanExpired(): void {
        const now = Date.now();
        let cleaned = 0;

        for (const [key, entry] of this.cache.entries()) {
            if (now > entry.expiry) {
                this.cache.delete(key);
                cleaned++;
            }
        }

        if (cleaned > 0) {
            this.logger.debug(`Cleaned ${cleaned} expired cache entries`);
        }
    }

    getStats(): { size: number; keys: string[] } {
        return {
            size: this.cache.size,
            keys: Array.from(this.cache.keys()),
        };
    }
}
