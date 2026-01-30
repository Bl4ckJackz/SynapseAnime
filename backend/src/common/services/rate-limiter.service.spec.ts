import { Test, TestingModule } from '@nestjs/testing';
import { RateLimiterService } from './rate-limiter.service';

describe('RateLimiterService', () => {
  let service: RateLimiterService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [RateLimiterService],
    }).compile();

    service = module.get<RateLimiterService>(RateLimiterService);
  });

  describe('acquireToken', () => {
    it('should acquire token successfully for valid API', async () => {
      const startTime = Date.now();
      await service.acquireToken('jikan');
      const duration = Date.now() - startTime;

      // Should be nearly instant for first request
      expect(duration).toBeLessThan(100);
    });

    it('should configure custom rate limits', () => {
      service.setConfig('test-api', {
        requestsPerSecond: 1,
        requestsPerMinute: 10,
      });

      const stats = service.getStats('test-api');
      expect(stats).toBeNull(); // No requests yet
    });

    it('should track token consumption', async () => {
      await service.acquireToken('jikan');
      const stats = service.getStats('jikan');

      expect(stats).not.toBeNull();
      expect(stats!.tokensRemaining).toBeLessThan(3); // Less than max
    });

    it('should handle unknown API with default config', async () => {
      await service.acquireToken('unknown-api');
      const stats = service.getStats('unknown-api');

      expect(stats).not.toBeNull();
    });
  });

  describe('getStats', () => {
    it('should return null for unused API', () => {
      const stats = service.getStats('unused-api');
      expect(stats).toBeNull();
    });
  });
});
