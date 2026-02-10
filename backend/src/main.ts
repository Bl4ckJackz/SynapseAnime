import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';

async function bootstrap() {
  console.log('Current directory (__dirname):', __dirname);
  console.log('Glob pattern:', __dirname + '/**/*.entity{.ts,.js}');
  const app = await NestFactory.create(AppModule);

  // Enable CORS for development
  app.enableCors({
    origin: '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true }));

  app.use((req, res, next) => {
    console.log(`[Incoming Request] ${req.method} ${req.url}`);
    if (req.body && Object.keys(req.body).length > 0) {
      console.log(`[Request Body]`, JSON.stringify(req.body, null, 2));
    }
    next();
  });

  const port = process.env.PORT || 3005;
  await app.listen(port, '0.0.0.0');
  console.log(`Application running on port ${port}`);
}
bootstrap();
