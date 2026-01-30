import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { AiService } from './ai.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import { User } from '../entities/user.entity';
import { RecommendDto } from './dto/recommend.dto';

@Controller('ai')
@UseGuards(JwtAuthGuard)
export class AiController {
  constructor(private readonly aiService: AiService) {}

  @Post('recommend')
  async recommend(@CurrentUser() user: User, @Body() dto: RecommendDto) {
    return this.aiService.recommend(user.id, dto);
  }
}
