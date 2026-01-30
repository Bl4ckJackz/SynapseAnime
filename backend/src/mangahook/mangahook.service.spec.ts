import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { MangaHookService } from './mangahook.service';
import { CacheService } from '../common/services/cache.service';
import { CircuitBreakerService } from '../common/services/circuit-breaker.service';
import axios from 'axios';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('MangaHookService', () => {
  let service: MangaHookService;
  let cacheService: jest.Mocked<CacheService>;
  let circuitBreaker: jest.Mocked<CircuitBreakerService>;

  const mockAxiosInstance = {
    get: jest.fn(),
  };

  beforeEach(async () => {
    mockedAxios.create.mockReturnValue(mockAxiosInstance as any);

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        MangaHookService,
        {
          provide: ConfigService,
          useValue: {
            get: jest
              .fn()
              .mockReturnValue('https://mangahook-api.vercel.app/api'),
          },
        },
        {
          provide: CacheService,
          useValue: {
            get: jest.fn(),
            set: jest.fn(),
          },
        },
        {
          provide: CircuitBreakerService,
          useValue: {
            execute: jest
              .fn()
              .mockImplementation((name, operation, fallback) => {
                try {
                  return operation();
                } catch (e) {
                  if (fallback) return fallback();
                  throw e;
                }
              }),
          },
        },
      ],
    }).compile();

    service = module.get<MangaHookService>(MangaHookService);
    cacheService = module.get(CacheService);
    circuitBreaker = module.get(CircuitBreakerService);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('getMangaList', () => {
    it('should return cached data', async () => {
      const mockCached = {
        data: [],
        pagination: { totalItems: 0, totalPages: 0, currentPage: 1 },
      };
      cacheService.get.mockReturnValue(mockCached);

      const result = await service.getMangaList({});

      expect(cacheService.get).toHaveBeenCalled();
      expect(mockAxiosInstance.get).not.toHaveBeenCalled();
      expect(result).toEqual(mockCached);
    });

    it('should fetch from API if not cached', async () => {
      cacheService.get.mockReturnValue(null);
      const mockResponse = {
        data: {
          mangaList: [
            {
              id: 'id1',
              image: 'img',
              title: 'Title',
              chapter: 'ch1',
              view: '100',
              description: 'desc',
            },
          ],
          metaData: {
            totalStories: 1,
            totalPages: 1,
            type: [],
            state: [],
            category: [],
          },
        },
      };
      mockAxiosInstance.get.mockResolvedValue(mockResponse);

      const result = await service.getMangaList({});

      expect(mockAxiosInstance.get).toHaveBeenCalledWith(
        expect.stringContaining('/mangaList'),
      );
      expect(result.data).toHaveLength(1);
      expect(result.data[0].title).toBe('Title');
      expect(cacheService.set).toHaveBeenCalled();
    });
  });

  describe('executeRequest', () => {
    it('should use fallback on failure', async () => {
      cacheService.get.mockReturnValue(null);
      mockAxiosInstance.get.mockRejectedValue(new Error('Network error'));

      // Adjust the mock implementation to simulate CircuitBreaker behavior for test
      // In real code, circuit breaker catches error and calls fallback
      // But here we are mocking execute, so we need to ensure it behaves as expected
      circuitBreaker.execute.mockImplementation(async (name, op, fallback) => {
        try {
          return await op();
        } catch (e) {
          if (fallback) return fallback();
          throw e;
        }
      });

      // The real service throws HttpException in fallback or propagates error
      // Let's verify that expected exception is thrown
      await expect(service.getMangaList({})).rejects.toThrow();
    });

    it('should handle API errors gracefully', async () => {
      cacheService.get.mockReturnValue(null);
      const axiosError = {
        response: { status: 404, statusText: 'Not Found' },
        isAxiosError: true,
        message: 'Request failed',
      };
      mockAxiosInstance.get.mockRejectedValue(axiosError);

      await expect(service.getMangaList({})).rejects.toThrow(
        'Manga Hook API error',
      );
    });
  });

  describe('checkHealth', () => {
    it('should return true when API is consistent', async () => {
      mockAxiosInstance.get.mockResolvedValue({ status: 200 });
      const healthy = await service.checkHealth();
      expect(healthy).toBe(true);
    });

    it('should return false when API fails', async () => {
      mockAxiosInstance.get.mockRejectedValue(new Error('Down'));
      const healthy = await service.checkHealth();
      expect(healthy).toBe(false);
    });
  });
});
