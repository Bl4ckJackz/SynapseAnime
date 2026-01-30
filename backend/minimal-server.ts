// Minimal server to test basic functionality
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

// Import only basic modules to avoid the relation issues
import { Module } from '@nestjs/common';
import { AppController } from './src/app.controller';
import { AppService } from './src/app.service';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class BasicModule {}

async function bootstrap() {
  try {
    const app = await NestFactory.create(BasicModule);
    app.useGlobalPipes(new ValidationPipe());
    await app.listen(3001);
    console.log('Basic server running on http://localhost:3001');
  } catch (error) {
    console.error('Error starting basic server:', error);
  }
}
bootstrap();