import { apiClient } from "./api-client";
import type { Comment, RatingInfo } from "@/types/comment";

export type CommentTarget = "anime" | "manga" | "episode";

class CommentService {
  getComments(
    target: CommentTarget,
    targetId: string,
    page: number = 1,
    limit: number = 20,
  ): Promise<Comment[]> {
    return apiClient.get<Comment[]>(`/comments/${target}/${targetId}`, {
      page,
      limit,
    });
  }

  getRating(target: CommentTarget, targetId: string): Promise<RatingInfo> {
    return apiClient.get<RatingInfo>(
      `/comments/${target}/${targetId}/rating`,
    );
  }

  createComment(data: {
    text: string;
    rating?: number;
    animeId?: string;
    mangaId?: string;
    episodeId?: string;
    parentId?: string;
  }): Promise<Comment> {
    return apiClient.post<Comment>("/comments", data);
  }

  updateComment(
    id: string,
    data: { text?: string; rating?: number },
  ): Promise<Comment> {
    return apiClient.put<Comment>(`/comments/${id}`, data);
  }

  deleteComment(id: string): Promise<void> {
    return apiClient.delete<void>(`/comments/${id}`);
  }
}

export const commentService = new CommentService();
