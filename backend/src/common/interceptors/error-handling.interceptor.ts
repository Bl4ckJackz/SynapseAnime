import {
    Injectable,
    NestInterceptor,
    ExecutionContext,
    CallHandler,
    Logger,
    HttpException,
    HttpStatus,
} from '@nestjs/common';
import { Observable, throwError } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';

export interface ApiError {
    statusCode: number;
    message: string;
    error: string;
    timestamp: string;
    path: string;
    apiSource?: string;
}

@Injectable()
export class ErrorHandlingInterceptor implements NestInterceptor {
    private readonly logger = new Logger(ErrorHandlingInterceptor.name);

    intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
        const request = context.switchToHttp().getRequest();
        const { method, url } = request;
        const startTime = Date.now();

        return next.handle().pipe(
            tap(() => {
                const responseTime = Date.now() - startTime;
                this.logger.log(`${method} ${url} - ${responseTime}ms`);
            }),
            catchError((error) => {
                const responseTime = Date.now() - startTime;

                let statusCode = HttpStatus.INTERNAL_SERVER_ERROR;
                let message = 'Internal server error';
                let errorName = 'InternalServerError';
                let apiSource: string | undefined;

                if (error instanceof HttpException) {
                    statusCode = error.getStatus();
                    const response = error.getResponse();
                    if (typeof response === 'string') {
                        message = response;
                    } else if (typeof response === 'object' && response !== null) {
                        message = (response as Record<string, unknown>).message as string || message;
                        errorName = (response as Record<string, unknown>).error as string || errorName;
                    }
                } else if (error.response) {
                    // Axios error from external API
                    statusCode = error.response.status || statusCode;
                    message = error.response.data?.message || error.message || message;
                    apiSource = error.config?.baseURL || 'external';

                    // Map external API errors to appropriate responses
                    switch (statusCode) {
                        case 304:
                            // Not Modified - this is actually success
                            return throwError(() => new HttpException('Not Modified', HttpStatus.NOT_MODIFIED));
                        case 400:
                            errorName = 'BadRequest';
                            break;
                        case 404:
                            errorName = 'NotFound';
                            break;
                        case 405:
                            errorName = 'MethodNotAllowed';
                            break;
                        case 429:
                            errorName = 'TooManyRequests';
                            message = 'Rate limit exceeded. Please try again later.';
                            break;
                        case 500:
                        case 502:
                        case 503:
                            errorName = 'ServiceUnavailable';
                            message = 'External service is temporarily unavailable';
                            break;
                    }
                } else {
                    message = error.message || message;
                }

                const apiError: ApiError = {
                    statusCode,
                    message,
                    error: errorName,
                    timestamp: new Date().toISOString(),
                    path: url,
                    apiSource,
                };

                this.logger.error(
                    `${method} ${url} - ${statusCode} - ${responseTime}ms`,
                    error.stack,
                );

                return throwError(() => new HttpException(apiError, statusCode));
            }),
        );
    }
}
