import { Test, TestingModule } from '@nestjs/testing';
import { CircuitBreakerService, CircuitState } from './circuit-breaker.service';

describe('CircuitBreakerService', () => {
    let service: CircuitBreakerService;

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [CircuitBreakerService],
        }).compile();

        service = module.get<CircuitBreakerService>(CircuitBreakerService);
    });

    afterEach(() => {
        service.reset('test-service');
    });

    describe('getState', () => {
        it('should return CLOSED for new services', () => {
            const state = service.getState('new-service');
            expect(state).toBe(CircuitState.CLOSED);
        });
    });

    describe('isAvailable', () => {
        it('should return true for CLOSED circuit', () => {
            expect(service.isAvailable('test-service')).toBe(true);
        });

        it('should return false for OPEN circuit', () => {
            // Force circuit to OPEN
            for (let i = 0; i < 5; i++) {
                service.recordFailure('test-service');
            }
            expect(service.isAvailable('test-service')).toBe(false);
        });

        it('should return true for HALF_OPEN circuit', () => {
            service.setConfig('test-service', { timeout: 1 }); // 1ms timeout

            // Force OPEN
            for (let i = 0; i < 5; i++) {
                service.recordFailure('test-service');
            }
            expect(service.getState('test-service')).toBe(CircuitState.OPEN);

            // Wait for timeout to transition to HALF_OPEN
            return new Promise(resolve => setTimeout(resolve, 10)).then(() => {
                expect(service.isAvailable('test-service')).toBe(true);
                expect(service.getState('test-service')).toBe(CircuitState.HALF_OPEN);
            });
        });
    });

    describe('recordSuccess', () => {
        it('should reset failures on success in CLOSED state', () => {
            service.recordFailure('test-service');
            service.recordSuccess('test-service');

            const status = service.getStatus('test-service');
            expect(status.failures).toBe(0);
        });

        it('should close circuit after successes in HALF_OPEN state', async () => {
            service.setConfig('test-service', { timeout: 1, successThreshold: 2 });

            // Force OPEN
            for (let i = 0; i < 5; i++) {
                service.recordFailure('test-service');
            }

            // Wait for HALF_OPEN
            await new Promise(resolve => setTimeout(resolve, 10));
            service.getState('test-service'); // Trigger transition check

            // Record successes
            service.recordSuccess('test-service');
            service.recordSuccess('test-service');

            expect(service.getState('test-service')).toBe(CircuitState.CLOSED);
        });
    });

    describe('recordFailure', () => {
        it('should open circuit after threshold failures', () => {
            for (let i = 0; i < 5; i++) {
                service.recordFailure('test-service');
            }

            expect(service.getState('test-service')).toBe(CircuitState.OPEN);
        });

        it('should reopen circuit on failure in HALF_OPEN state', async () => {
            service.setConfig('test-service', { timeout: 1 });

            // Force OPEN
            for (let i = 0; i < 5; i++) {
                service.recordFailure('test-service');
            }

            // Wait for HALF_OPEN
            await new Promise(resolve => setTimeout(resolve, 10));
            service.getState('test-service'); // Trigger transition check

            // Record failure in HALF_OPEN
            service.recordFailure('test-service');

            expect(service.getState('test-service')).toBe(CircuitState.OPEN);
        });
    });

    describe('execute', () => {
        it('should execute operation when circuit is CLOSED', async () => {
            const result = await service.execute(
                'test-service',
                () => Promise.resolve('success'),
            );
            expect(result).toBe('success');
        });

        it('should use fallback when circuit is OPEN', async () => {
            // Force OPEN
            for (let i = 0; i < 5; i++) {
                service.recordFailure('test-service');
            }

            const result = await service.execute(
                'test-service',
                () => Promise.resolve('main'),
                () => 'fallback',
            );
            expect(result).toBe('fallback');
        });

        it('should record failure and use fallback on error', async () => {
            const result = await service.execute(
                'test-service',
                () => Promise.reject(new Error('test error')),
                () => 'fallback',
            );
            expect(result).toBe('fallback');

            const status = service.getStatus('test-service');
            expect(status.failures).toBe(1);
        });
    });

    describe('reset', () => {
        it('should reset circuit to initial state', () => {
            // Force OPEN
            for (let i = 0; i < 5; i++) {
                service.recordFailure('test-service');
            }
            expect(service.getState('test-service')).toBe(CircuitState.OPEN);

            service.reset('test-service');
            expect(service.getState('test-service')).toBe(CircuitState.CLOSED);
        });
    });

    describe('getAllStatus', () => {
        it('should return status for all circuits', () => {
            service.recordFailure('service1');
            service.recordSuccess('service2');

            const allStatus = service.getAllStatus();
            expect(allStatus['service1']).toBeDefined();
            expect(allStatus['service2']).toBeDefined();
        });
    });
});
