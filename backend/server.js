const { NestFactory } = require('@nestjs/core');
const { AppModule } = require('./dist/app.module.js');

async function bootstrap() {
  try {
    const app = await NestFactory.create(AppModule);
    await app.listen(3000);
    console.log('Server running on http://localhost:3000');
  } catch (error) {
    console.error('Error starting server:', error);
  }
}
bootstrap();