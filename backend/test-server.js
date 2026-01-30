const { NestFactory } = require('@nestjs/core');
const { AppModule } = require('./dist/src/app.module.js'); // Adjust path as needed

async function bootstrap() {
  try {
    console.log('Starting application...');
    const app = await NestFactory.create(AppModule);
    
    // Enable CORS for development
    app.enableCors({
      origin: '*',
      methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
      credentials: true,
    });

    await app.listen(3000);
    console.log('Application is running on port 3000');
  } catch (error) {
    console.error('Error starting application:', error);
  }
}

bootstrap();