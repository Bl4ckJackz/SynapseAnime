import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, LessThanOrEqual, MoreThanOrEqual } from 'typeorm';
import { Ad, AdImpression } from '../entities/ad.entity';
import { User } from '../entities/user.entity';
import { v4 as uuidv4 } from 'uuid';

export interface AdConfig {
  maxAdsPerHour: number;
  adFrequency: 'every_episode' | 'every_2_episodes' | 'every_3_episodes';
  adTypes: string[];
  skipAllowed: boolean;
  skipAfter: number; // seconds
}

@Injectable()
export class AdService {
  constructor(
    @InjectRepository(Ad)
    private adRepository: Repository<Ad>,
    @InjectRepository(AdImpression)
    private adImpressionRepository: Repository<AdImpression>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
  ) {}

  async getAdConfiguration(userTier: string): Promise<AdConfig> {
    if (userTier === 'premium') {
      return {
        maxAdsPerHour: 0,
        adFrequency: 'every_episode',
        adTypes: [],
        skipAllowed: true,
        skipAfter: 0,
      };
    }

    // Free tier ad configuration
    return {
      maxAdsPerHour: 10,
      adFrequency: 'every_2_episodes',
      adTypes: ['video', 'banner'],
      skipAllowed: true,
      skipAfter: 5,
    };
  }

  async getEligibleAds(
    userId: string,
    adType: string,
    targetAudience: 'all' | 'free_users' | 'premium_users' = 'all',
  ): Promise<Ad[]> {
    const user = await this.userRepository.findOne({ where: { id: userId } });

    // If user is premium, don't show ads unless specifically for premium users
    if (
      user?.subscriptionTier === 'premium' &&
      targetAudience !== 'premium_users'
    ) {
      return [];
    }

    // If user is free but ads are for premium users only, don't show
    if (
      user?.subscriptionTier === 'free' &&
      targetAudience === 'premium_users'
    ) {
      return [];
    }

    const now = new Date();
    const eligibleAds = await this.adRepository.find({
      where: {
        adType: adType as any, // Type assertion to bypass strict typing
        targetAudience: targetAudience === 'all' ? undefined : targetAudience,
        isActive: true,
        startDate: LessThanOrEqual(now),
        endDate: MoreThanOrEqual(now),
      },
      order: {
        impressions: 'ASC', // Show least shown ads first
      },
    });

    return eligibleAds;
  }

  async trackAdImpression(
    adId: string,
    userId: string,
    sessionId: string,
    durationWatched?: number,
  ): Promise<void> {
    const impression = new AdImpression();
    impression.adId = adId;
    impression.userId = userId;
    impression.sessionId = sessionId;
    impression.durationWatched = durationWatched;
    impression.wasClicked = false; // Will be updated separately if clicked

    await this.adImpressionRepository.save(impression);

    // Update ad statistics
    const ad = await this.adRepository.findOne({ where: { id: adId } });
    if (ad) {
      ad.impressions += 1;
      await this.adRepository.save(ad);
    }
  }

  async trackAdClick(impressionId: string): Promise<void> {
    const impression = await this.adImpressionRepository.findOne({
      where: { id: impressionId },
    });
    if (impression) {
      impression.wasClicked = true;
      await this.adImpressionRepository.save(impression);

      // Update ad statistics
      const ad = await this.adRepository.findOne({
        where: { id: impression.adId },
      });
      if (ad) {
        ad.clicks += 1;
        ad.ctr = (ad.clicks / ad.impressions) * 100;
        await this.adRepository.save(ad);
      }
    }
  }

  async createAd(
    title: string,
    content: string,
    advertiser: string,
    adType: string,
    targetAudience: 'all' | 'free_users' | 'premium_users',
    targetingCriteria?: any,
    startDate?: Date,
    endDate?: Date,
  ): Promise<Ad> {
    const ad = new Ad();
    ad.title = title;
    ad.content = content;
    ad.advertiser = advertiser;
    ad.adType = adType as 'video' | 'banner' | 'native' | 'interstitial';
    ad.targetAudience = targetAudience;
    ad.targetingCriteria = targetingCriteria;
    ad.startDate = startDate || new Date();
    ad.endDate = endDate || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000); // Default 30 days
    ad.isActive = true;

    return await this.adRepository.save(ad);
  }

  async getAdPerformance(adId: string): Promise<{
    impressions: number;
    clicks: number;
    ctr: number;
    avgDurationWatched?: number;
  }> {
    const impressions = await this.adImpressionRepository.find({
      where: { adId },
    });

    const totalImpressions = impressions.length;
    const totalClicks = impressions.filter((i) => i.wasClicked).length;
    const ctr =
      totalImpressions > 0 ? (totalClicks / totalImpressions) * 100 : 0;

    // Calculate average duration watched for video ads
    const avgDurationWatched =
      impressions.length > 0
        ? impressions.reduce(
            (sum, imp) => sum + (imp.durationWatched || 0),
            0,
          ) / impressions.length
        : undefined;

    return {
      impressions: totalImpressions,
      clicks: totalClicks,
      ctr,
      avgDurationWatched,
    };
  }

  async getRandomAdForUser(
    userId: string,
    adType: 'video' | 'banner' | 'native' | 'interstitial',
    targetAudience: 'all' | 'free_users' | 'premium_users' = 'all',
  ): Promise<Ad | null> {
    const eligibleAds = await this.getEligibleAds(
      userId,
      adType,
      targetAudience,
    );

    if (eligibleAds.length === 0) {
      return null;
    }

    // Select a random ad from eligible ads
    const randomIndex = Math.floor(Math.random() * eligibleAds.length);
    return eligibleAds[randomIndex];
  }
}
