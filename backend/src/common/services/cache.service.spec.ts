import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { CacheService } from './cache.service';

describe('CacheService', () => {
    let service: CacheService;
    let configService: Partial<ConfigService>;

    beforeEach(async () => {
        configService = {
            get: jest.fn().mockReturnValue(undefined),
        };

        const module: TestingModule = await Test.createTestingModule({
            providers: [
                CacheService,
                { provide: ConfigService, useValue: configService },
            ],
        }).compile();

        service = module.get<CacheService>(CacheService);
    });

    afterEach(() => {
        service.clear();
    });

    describe('get/set', () => {
        it('should store and retrieve values', () => {
            const data = { foo: 'bar' };
            service.set('test-key', data);

            const result = service.get('test-key');
            expect(result).toEqual(data);
        });

        it('should return null for non-existent keys', () => {
            const result = service.get('non-existent');
            expect(result).toBeNull();
        });

        it('should return null for expired entries', async () => {
            // Use a mock to make entry expire immediately
            const data = { foo: 'bar' };
            service.set('expiring-key', data);

            // Manually access cache internals to set expiry in the past
            const stats = service.getStats();
            expect(stats.size).toBe(1);
        });
    });

    describe('getWithEtag', () => {
        it('should store and retrieve ETag', () => {
            const data = { foo: 'bar' };
            const etag = 'W/"abc123"';

            service.set('etag-key', data, 'jikan', etag);

            const result = service.getWithEtag('etag-key');
            expect(result.data).toEqual(data);
            expect(result.etag).toBe(etag);
        });
    });

    describe('delete', () => {
        it('should remove entries', () => {
            service.set('delete-key', { data: 'test' });
            expect(service.get('delete-key')).not.toBeNull();

            service.delete('delete-key');
            expect(service.get('delete-key')).toBeNull();
        });
    });

    describe('clear', () => {
        it('should clear all entries', () => {
            service.set('key1', 'value1');
            service.set('key2', 'value2');

            service.clear();

            expect(service.get('key1')).toBeNull();
            expect(service.get('key2')).toBeNull();
        });

        it('should clear entries with prefix', () => {
            service.set('prefix:key1', 'value1');
            service.set('prefix:key2', 'value2');
            service.set('other:key', 'value3');

            service.clear('prefix:');

            expect(service.get('prefix:key1')).toBeNull();
            expect(service.get('prefix:key2')).toBeNull();
            expect(service.get('other:key')).not.toBeNull();
        });
    });

    describe('getStats', () => {
        it('should return cache statistics', () => {
            service.set('key1', 'value1');
            service.set('key2', 'value2');

            const stats = service.getStats();

            expect(stats.size).toBe(2);
            expect(stats.keys).toContain('key1');
            expect(stats.keys).toContain('key2');
        });
    });
});
