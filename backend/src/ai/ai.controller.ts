import { Controller, Post, Body, UseGuards, Req, Logger, Get } from '@nestjs/common';
import { AiService } from './ai.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { User } from '../entities/user.entity';
import { RecommendDto } from './dto/recommend.dto';
import { ChatDto } from './dto/chat.dto';

@Controller('ai')
export class AiController {
  constructor(private readonly aiService: AiService) { }

  @Post('recommend')
  @UseGuards(JwtAuthGuard)
  async recommend(@CurrentUser() user: User, @Body() dto: RecommendDto) {
    return this.aiService.recommend(user.id, dto);
  }

  @Get('test')
  async test() {
    Logger.log('Received test request', 'AiController');
    return this.aiService.chat('test_user', [{ role: 'user', content: 'In 10 words, explain why skies are blue.' }]);
  }

  @Post('chat')
  @UseGuards(JwtAuthGuard)
  async chat(@CurrentUser() user: User, @Body() dto: ChatDto) {
    Logger.log(`Received chat request from user ${user.id}`, 'AiController');
    Logger.log(`DTO: ${JSON.stringify(dto)}`, 'AiController');
    try {
      const response = await this.aiService.chat(user.id, dto.messages);
      Logger.log(`Chat response generated successfully`, 'AiController');
      return response;
    } catch (error) {
      Logger.error(`Error in chat controller: ${error.message}`, error.stack, 'AiController');
      throw error;
    }
  }
}
