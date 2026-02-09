import {
  Controller,
  Get,
  Post,
  Put,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
  Request,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { CommentsService } from './comments.service';
import { CreateCommentDto, UpdateCommentDto } from './dto/comment.dto';

@Controller('comments')
export class CommentsController {
  constructor(private readonly commentsService: CommentsService) {}

  // Create a new comment (requires auth)
  @Post()
  @UseGuards(JwtAuthGuard)
  async create(@Request() req: any, @Body() dto: CreateCommentDto) {
    return this.commentsService.create(req.user.id, dto);
  }

  // Get comments for an anime (public)
  @Get('anime/:animeId')
  async getForAnime(
    @Param('animeId') animeId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.commentsService.findForAnime(
      animeId,
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
    );
  }

  // Get comments for a manga (public)
  @Get('manga/:mangaId')
  async getForManga(
    @Param('mangaId') mangaId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.commentsService.findForManga(
      mangaId,
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
    );
  }

  // Get comments for an episode (public)
  @Get('episode/:episodeId')
  async getForEpisode(
    @Param('episodeId') episodeId: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.commentsService.findForEpisode(
      episodeId,
      page ? parseInt(page, 10) : 1,
      limit ? parseInt(limit, 10) : 20,
    );
  }

  // Get average rating for anime/manga (public)
  @Get(':target/:targetId/rating')
  async getAverageRating(
    @Param('target') target: 'anime' | 'manga',
    @Param('targetId') targetId: string,
  ) {
    return this.commentsService.getAverageRating(target, targetId);
  }

  // Get single comment (public)
  @Get(':id')
  async findOne(@Param('id') id: string) {
    return this.commentsService.findOne(id);
  }

  // Update comment (requires auth, owner only)
  @Put(':id')
  @UseGuards(JwtAuthGuard)
  async update(
    @Request() req: any,
    @Param('id') id: string,
    @Body() dto: UpdateCommentDto,
  ) {
    return this.commentsService.update(req.user.id, id, dto);
  }

  // Delete comment (requires auth, owner only)
  @Delete(':id')
  @UseGuards(JwtAuthGuard)
  async remove(@Request() req: any, @Param('id') id: string) {
    await this.commentsService.remove(req.user.id, id);
    return { message: 'Comment deleted' };
  }
}
