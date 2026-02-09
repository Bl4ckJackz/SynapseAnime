import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { Comment } from '../entities/comment.entity';
import { CreateCommentDto, UpdateCommentDto } from './dto/comment.dto';

@Injectable()
export class CommentsService {
  constructor(
    @InjectRepository(Comment)
    private commentRepository: Repository<Comment>,
  ) {}

  async create(userId: string, dto: CreateCommentDto): Promise<Comment> {
    const comment = this.commentRepository.create({
      userId,
      text: dto.text,
      rating: dto.rating,
      animeId: dto.animeId,
      mangaId: dto.mangaId,
      episodeId: dto.episodeId,
      parentId: dto.parentId,
    });
    return this.commentRepository.save(comment);
  }

  async findForAnime(
    animeId: string,
    page = 1,
    limit = 20,
  ): Promise<Comment[]> {
    return this.commentRepository.find({
      where: { animeId, parentId: IsNull() },
      relations: ['user', 'replies', 'replies.user'],
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });
  }

  async findForManga(
    mangaId: string,
    page = 1,
    limit = 20,
  ): Promise<Comment[]> {
    return this.commentRepository.find({
      where: { mangaId, parentId: IsNull() },
      relations: ['user', 'replies', 'replies.user'],
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });
  }

  async findForEpisode(
    episodeId: string,
    page = 1,
    limit = 20,
  ): Promise<Comment[]> {
    return this.commentRepository.find({
      where: { episodeId, parentId: IsNull() },
      relations: ['user', 'replies', 'replies.user'],
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });
  }

  async findOne(id: string): Promise<Comment> {
    const comment = await this.commentRepository.findOne({
      where: { id },
      relations: ['user', 'replies', 'replies.user'],
    });
    if (!comment) {
      throw new NotFoundException('Comment not found');
    }
    return comment;
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateCommentDto,
  ): Promise<Comment> {
    const comment = await this.findOne(id);
    if (comment.userId !== userId) {
      throw new ForbiddenException('You can only edit your own comments');
    }

    if (dto.text !== undefined) comment.text = dto.text;
    if (dto.rating !== undefined) comment.rating = dto.rating;

    return this.commentRepository.save(comment);
  }

  async remove(userId: string, id: string): Promise<void> {
    const comment = await this.findOne(id);
    if (comment.userId !== userId) {
      throw new ForbiddenException('You can only delete your own comments');
    }
    await this.commentRepository.remove(comment);
  }

  async getAverageRating(
    target: 'anime' | 'manga',
    targetId: string,
  ): Promise<{ average: number; count: number }> {
    const where =
      target === 'anime' ? { animeId: targetId } : { mangaId: targetId };

    const result = await this.commentRepository
      .createQueryBuilder('comment')
      .select('AVG(comment.rating)', 'average')
      .addSelect('COUNT(comment.rating)', 'count')
      .where(where)
      .andWhere('comment.rating IS NOT NULL')
      .getRawOne();

    return {
      average: parseFloat(result.average) || 0,
      count: parseInt(result.count) || 0,
    };
  }
}
