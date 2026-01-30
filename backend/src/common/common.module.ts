import { Module, Global } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { RateLimiterService } from './services/rate-limiter.service';
import { CacheService } from './services/cache.service';
import { CircuitBreakerService } from './services/circuit-breaker.service';

@Global()
@Module({
  imports: [ConfigModule],
  providers: [RateLimiterService, CacheService, CircuitBreakerService],
  exports: [RateLimiterService, CacheService, CircuitBreakerService],
})
export class CommonModule {}
