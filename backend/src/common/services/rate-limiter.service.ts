import { Injectable, Logger } from '@nestjs/common';

interface RateLimitConfig {
  requestsPerSecond: number;
  requestsPerMinute: number;
}

interface TokenBucket {
  tokens: number;
  lastRefill: number;
  minuteTokens: number;
  minuteLastRefill: number;
}

@Injectable()
export class RateLimiterService {
  private readonly logger = new Logger(RateLimiterService.name);
  private readonly buckets = new Map<string, TokenBucket>();

  private readonly configs: Record<string, RateLimitConfig> = {
    jikan: { requestsPerSecond: 2, requestsPerMinute: 50 },
    mangahook: { requestsPerSecond: 10, requestsPerMinute: 300 },
    mangadex: { requestsPerSecond: 5, requestsPerMinute: 100 },
  };

  async acquireToken(apiName: string): Promise<void> {
    const config = this.configs[apiName] || {
      requestsPerSecond: 5,
      requestsPerMinute: 100,
    };
    let bucket = this.buckets.get(apiName);

    if (!bucket) {
      bucket = {
        tokens: config.requestsPerSecond,
        lastRefill: Date.now(),
        minuteTokens: config.requestsPerMinute,
        minuteLastRefill: Date.now(),
      };
      this.buckets.set(apiName, bucket);
    }

    // Refill per-second tokens
    const now = Date.now();
    const secondsElapsed = (now - bucket.lastRefill) / 1000;
    bucket.tokens = Math.min(
      config.requestsPerSecond,
      bucket.tokens + secondsElapsed * config.requestsPerSecond,
    );
    bucket.lastRefill = now;

    // Refill per-minute tokens
    const minutesElapsed = (now - bucket.minuteLastRefill) / 60000;
    if (minutesElapsed >= 1) {
      bucket.minuteTokens = config.requestsPerMinute;
      bucket.minuteLastRefill = now;
    }

    // Wait if no tokens available
    while (bucket.tokens < 1 || bucket.minuteTokens < 1) {
      const waitTime =
        bucket.tokens < 1
          ? Math.ceil(((1 - bucket.tokens) * 1000) / config.requestsPerSecond)
          : Math.ceil(
              ((1 - bucket.minuteTokens) * 60000) / config.requestsPerMinute,
            );

      this.logger.warn(
        `Rate limit reached for ${apiName}, waiting ${waitTime}ms`,
      );
      await this.sleep(Math.min(waitTime, 1000));

      // Refill after waiting
      const afterWait = Date.now();
      const elapsed = (afterWait - bucket.lastRefill) / 1000;
      bucket.tokens = Math.min(
        config.requestsPerSecond,
        bucket.tokens + elapsed * config.requestsPerSecond,
      );
      bucket.lastRefill = afterWait;
    }

    // Consume tokens
    bucket.tokens -= 1;
    bucket.minuteTokens -= 1;
  }

  private sleep(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  setConfig(apiName: string, config: RateLimitConfig): void {
    this.configs[apiName] = config;
  }

  getStats(
    apiName: string,
  ): { tokensRemaining: number; minuteTokensRemaining: number } | null {
    const bucket = this.buckets.get(apiName);
    if (!bucket) return null;
    return {
      tokensRemaining: Math.floor(bucket.tokens),
      minuteTokensRemaining: Math.floor(bucket.minuteTokens),
    };
  }
}
