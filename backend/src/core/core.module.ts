import { Module, Global } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';

/**
 * CoreModule provides shared dependencies across all feature modules.
 * This module is marked as @Global so its exports are available everywhere.
 */
@Global()
@Module({
  imports: [
    HttpModule.register({
      timeout: 30000,
      maxRedirects: 5,
    }),
    ConfigModule,
  ],
  exports: [HttpModule, ConfigModule],
})
export class CoreModule {}
