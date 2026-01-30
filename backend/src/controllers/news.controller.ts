import { Controller, Get, Post, Put, Delete, Param, Query, Body, UseGuards } from '@nestjs/common';
import { NewsService } from '../services/news.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('news')
export class NewsController {
  constructor(private newsService: NewsService) {}

  @Get()
  async getAllNews(
    @Query('sources') sources?: string,
    @Query('category') category?: string,
    @Query('limit') limit?: string,
    @Query('search') search?: string
  ) {
    const sourcesArray = sources ? sources.split(',') : ['myanimelist', 'custom'];
    const limitNum = limit ? parseInt(limit, 10) : 10;

    if (search) {
      return await this.newsService.getNewsBySearch(search, limitNum);
    }

    if (category) {
      return await this.newsService.getNewsByCategory(category, limitNum);
    }

    return await this.newsService.fetchLatestNews(sourcesArray);
  }

  @Get('recent')
  async getRecentNews(@Query('limit') limit?: string) {
    const limitNum = limit ? parseInt(limit, 10) : 10;
    return await this.newsService.getRecentNews(limitNum);
  }

  @Get('trending')
  async getTrendingNews(@Query('limit') limit?: string) {
    const limitNum = limit ? parseInt(limit, 10) : 5;
    return await this.newsService.getTrendingNews(limitNum);
  }

  @Get(':id')
  async getNewsById(@Param('id') id: string) {
    return await this.newsService.getNewsById(id);
  }

  @UseGuards(JwtAuthGuard)
  @Post()
  async createNews(@Body() newsData: any) {
    return await this.newsService.createNews(newsData);
  }

  @UseGuards(JwtAuthGuard)
  @Put(':id')
  async updateNews(@Param('id') id: string, @Body() newsData: any) {
    return await this.newsService.updateNews(id, newsData);
  }

  @UseGuards(JwtAuthGuard)
  @Delete(':id')
  async deleteNews(@Param('id') id: string) {
    return await this.newsService.deleteNews(id);
  }

  @Get('category/:category')
  async getNewsByCategory(
    @Param('category') category: string,
    @Query('limit') limit?: string
  ) {
    const limitNum = limit ? parseInt(limit, 10) : 10;
    return await this.newsService.getNewsByCategory(category, limitNum);
  }

  @Get('search/:query')
  async searchNews(
    @Param('query') query: string,
    @Query('limit') limit?: string
  ) {
    const limitNum = limit ? parseInt(limit, 10) : 10;
    return await this.newsService.getNewsBySearch(query, limitNum);
  }

  @Get('tags/:tags')
  async getNewsByTags(
    @Param('tags') tags: string,
    @Query('limit') limit?: string
  ) {
    const tagsArray = tags.split(',');
    const limitNum = limit ? parseInt(limit, 10) : 10;
    return await this.newsService.getNewsByTags(tagsArray, limitNum);
  }
}