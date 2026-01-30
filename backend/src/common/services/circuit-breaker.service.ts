import { Injectable, Logger } from '@nestjs/common';

export enum CircuitState {
    CLOSED = 'CLOSED',
    OPEN = 'OPEN',
    HALF_OPEN = 'HALF_OPEN',
}

interface CircuitConfig {
    failureThreshold: number;
    successThreshold: number;
    timeout: number; // ms before trying again
}

interface CircuitStatus {
    state: CircuitState;
    failures: number;
    successes: number;
    lastFailure: number | null;
    nextAttempt: number | null;
}

@Injectable()
export class CircuitBreakerService {
    private readonly logger = new Logger(CircuitBreakerService.name);
    private readonly circuits = new Map<string, CircuitStatus>();

    private readonly defaultConfig: CircuitConfig = {
        failureThreshold: 5,
        successThreshold: 2,
        timeout: 30000, // 30 seconds
    };

    private readonly configs: Record<string, CircuitConfig> = {};

    getState(serviceName: string): CircuitState {
        const circuit = this.getOrCreateCircuit(serviceName);

        // Check if we should transition from OPEN to HALF_OPEN
        if (circuit.state === CircuitState.OPEN && circuit.nextAttempt) {
            if (Date.now() >= circuit.nextAttempt) {
                circuit.state = CircuitState.HALF_OPEN;
                circuit.successes = 0;
                this.logger.log(`Circuit ${serviceName} transitioned to HALF_OPEN`);
            }
        }

        return circuit.state;
    }

    isAvailable(serviceName: string): boolean {
        const state = this.getState(serviceName);
        return state !== CircuitState.OPEN;
    }

    recordSuccess(serviceName: string): void {
        const circuit = this.getOrCreateCircuit(serviceName);
        const config = this.configs[serviceName] || this.defaultConfig;

        if (circuit.state === CircuitState.HALF_OPEN) {
            circuit.successes++;
            if (circuit.successes >= config.successThreshold) {
                circuit.state = CircuitState.CLOSED;
                circuit.failures = 0;
                circuit.successes = 0;
                circuit.nextAttempt = null;
                this.logger.log(`Circuit ${serviceName} CLOSED after successful recovery`);
            }
        } else if (circuit.state === CircuitState.CLOSED) {
            // Reset failures on success
            circuit.failures = 0;
        }
    }

    recordFailure(serviceName: string): void {
        const circuit = this.getOrCreateCircuit(serviceName);
        const config = this.configs[serviceName] || this.defaultConfig;

        circuit.failures++;
        circuit.lastFailure = Date.now();

        if (circuit.state === CircuitState.HALF_OPEN) {
            // Any failure in HALF_OPEN goes back to OPEN
            circuit.state = CircuitState.OPEN;
            circuit.nextAttempt = Date.now() + config.timeout;
            this.logger.warn(`Circuit ${serviceName} reopened after failure in HALF_OPEN`);
        } else if (circuit.state === CircuitState.CLOSED) {
            if (circuit.failures >= config.failureThreshold) {
                circuit.state = CircuitState.OPEN;
                circuit.nextAttempt = Date.now() + config.timeout;
                this.logger.warn(`Circuit ${serviceName} OPENED after ${circuit.failures} failures`);
            }
        }
    }

    async execute<T>(
        serviceName: string,
        operation: () => Promise<T>,
        fallback?: () => T | Promise<T>,
    ): Promise<T> {
        if (!this.isAvailable(serviceName)) {
            this.logger.warn(`Circuit ${serviceName} is OPEN, using fallback`);
            if (fallback) {
                return fallback();
            }
            throw new Error(`Service ${serviceName} is currently unavailable`);
        }

        try {
            const result = await operation();
            this.recordSuccess(serviceName);
            return result;
        } catch (error) {
            this.recordFailure(serviceName);
            if (fallback) {
                this.logger.warn(`Operation failed for ${serviceName}, using fallback`);
                return fallback();
            }
            throw error;
        }
    }

    setConfig(serviceName: string, config: Partial<CircuitConfig>): void {
        this.configs[serviceName] = { ...this.defaultConfig, ...config };
    }

    reset(serviceName: string): void {
        this.circuits.delete(serviceName);
        this.logger.log(`Circuit ${serviceName} reset`);
    }

    getStatus(serviceName: string): CircuitStatus {
        return this.getOrCreateCircuit(serviceName);
    }

    getAllStatus(): Record<string, CircuitStatus> {
        const result: Record<string, CircuitStatus> = {};
        for (const [name, status] of this.circuits.entries()) {
            result[name] = { ...status };
        }
        return result;
    }

    private getOrCreateCircuit(serviceName: string): CircuitStatus {
        let circuit = this.circuits.get(serviceName);
        if (!circuit) {
            circuit = {
                state: CircuitState.CLOSED,
                failures: 0,
                successes: 0,
                lastFailure: null,
                nextAttempt: null,
            };
            this.circuits.set(serviceName, circuit);
        }
        return circuit;
    }
}
