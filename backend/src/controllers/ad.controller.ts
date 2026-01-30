import { Controller, Get, Post, Put, Delete, Param, Body, Req, UseGuards } from '@nestjs/common';
import type { Request } from 'express';
import { AdService } from '../services/ad.service';
import { AdInsertionService } from '../services/ad-insertion.service';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';

@Controller('ads')
export class AdController {
  constructor(
    private adService: AdService,
    private adInsertionService: AdInsertionService,
  ) {}

  @UseGuards(JwtAuthGuard)
  @Get('config')
  async getAdConfig(@Req() req: Request) {
    const userId = req.user?.['sub']; // Assuming JWT payload has user ID as 'sub'
    const userTier = req.user?.['subscriptionTier'] || 'free';

    return await this.adService.getAdConfiguration(userTier);
  }

  @UseGuards(JwtAuthGuard)
  @Get('for-user/:contentType')
  async getAdForUser(
    @Req() req: Request,
    @Param('contentType') contentType: 'video' | 'manga',
    @Body() context?: any
  ) {
    const userId = req.user?.['sub'];

    if (!userId) {
      return { showAd: false };
    }

    // Check if user should see an ad
    const shouldShowAd = await this.adInsertionService.shouldShowAd(
      { id: userId, subscriptionTier: req.user?.['subscriptionTier'] || 'free' } as any,
      contentType,
      context
    );

    if (!shouldShowAd) {
      return { showAd: false };
    }

    const ad = await this.adService.getRandomAdForUser(userId, 'video', 'free_users');

    return {
      showAd: !!ad,
      ad: ad,
      skipAllowed: true,
      skipAfter: 5 // seconds
    };
  }

  @UseGuards(JwtAuthGuard)
  @Post('track-impression')
  async trackAdImpression(
    @Req() req: Request,
    @Body() body: { adId: string; sessionId: string; durationWatched?: number }
  ) {
    const userId = req.user?.['sub'];

    if (!userId) {
      return { success: false, error: 'User not authenticated' };
    }

    await this.adService.trackAdImpression(
      body.adId,
      userId,
      body.sessionId,
      body.durationWatched
    );

    return { success: true };
  }

  @UseGuards(JwtAuthGuard)
  @Post('track-click/:impressionId')
  async trackAdClick(
    @Param('impressionId') impressionId: string
  ) {
    await this.adService.trackAdClick(impressionId);
    return { success: true };
  }

  @UseGuards(JwtAuthGuard)
  @Get('performance/:adId')
  async getAdPerformance(@Param('adId') adId: string) {
    return await this.adService.getAdPerformance(adId);
  }

  // Admin endpoints for managing ads
  @UseGuards(JwtAuthGuard)
  @Post('create')
  async createAd(
    @Body() adData: {
      title: string;
      content: string;
      advertiser: string;
      adType: string;
      targetAudience: 'all' | 'free_users' | 'premium_users';
      targetingCriteria?: any;
      startDate?: Date;
      endDate?: Date;
    }
  ) {
    const ad = await this.adService.createAd(
      adData.title,
      adData.content,
      adData.advertiser,
      adData.adType,
      adData.targetAudience,
      adData.targetingCriteria,
      adData.startDate,
      adData.endDate
    );
    
    return ad;
  }
}