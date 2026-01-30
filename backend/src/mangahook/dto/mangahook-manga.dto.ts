// Manga Hook API Response DTOs
// Based on https://github.com/kiraaziz/mangahook-api

export interface MangaHookMangaItem {
  id: string;
  image: string;
  title: string;
  chapter: string;
  view: string;
  description: string;
}

export interface MangaHookMetaType {
  id: string;
  type: string;
}

export interface MangaHookMetaData {
  totalStories: number;
  totalPages: number;
  type: MangaHookMetaType[];
  state: MangaHookMetaType[];
  category: MangaHookMetaType[];
}

export interface MangaHookListResponse {
  mangaList: MangaHookMangaItem[];
  metaData: MangaHookMetaData;
}

export interface MangaHookChapterItem {
  id: string;
  path: string;
  name: string;
  view: string;
  createdAt: string;
}

export interface MangaHookMangaDetail {
  id: string;
  title: string;
  description: string;
  headerForImage: Record<string, string>;
  image: string;
  author: string;
  status: string;
  genres: MangaHookMetaType[];
  chapterList: MangaHookChapterItem[];
  view: string;
  updated: string;
}

export interface MangaHookChapterImages {
  chapterTitle: string;
  images: string[];
}

// Transformed DTOs for frontend consumption
export interface MangaHookMangaDto {
  id: string;
  title: string;
  description: string;
  imageUrl: string;
  latestChapter: string;
  views: string;
}

export interface MangaHookMangaListDto {
  data: MangaHookMangaDto[];
  pagination: {
    totalItems: number;
    totalPages: number;
    currentPage: number;
  };
  filters: {
    types: Array<{ id: string; label: string }>;
    states: Array<{ id: string; label: string }>;
    categories: Array<{ id: string; label: string }>;
  };
}

export interface MangaHookMangaDetailDto {
  id: string;
  title: string;
  description: string;
  imageUrl: string;
  author: string;
  status: string;
  genres: string[];
  views: string;
  updatedAt: string;
  chapters: Array<{
    id: string;
    path: string;
    name: string;
    views: string;
    createdAt: string;
  }>;
}

export interface MangaHookChapterDto {
  title: string;
  pages: string[];
}

// Transform functions
export function transformMangaHookList(
  response: MangaHookListResponse,
  page: number,
): MangaHookMangaListDto {
  return {
    data: response.mangaList.map((manga) => ({
      id: manga.id,
      title: manga.title,
      description: manga.description,
      imageUrl: manga.image,
      latestChapter: manga.chapter,
      views: manga.view,
    })),
    pagination: {
      totalItems: response.metaData.totalStories,
      totalPages: response.metaData.totalPages,
      currentPage: page,
    },
    filters: {
      types: response.metaData.type.map((t) => ({ id: t.id, label: t.type })),
      states: response.metaData.state.map((s) => ({ id: s.id, label: s.type })),
      categories: response.metaData.category.map((c) => ({
        id: c.id,
        label: c.type,
      })),
    },
  };
}

export function transformMangaHookDetail(
  manga: MangaHookMangaDetail,
): MangaHookMangaDetailDto {
  return {
    id: manga.id,
    title: manga.title,
    description: manga.description,
    imageUrl: manga.image,
    author: manga.author,
    status: manga.status,
    genres: manga.genres.map((g) => g.type),
    views: manga.view,
    updatedAt: manga.updated,
    chapters: manga.chapterList.map((ch) => ({
      id: ch.id,
      path: ch.path,
      name: ch.name,
      views: ch.view,
      createdAt: ch.createdAt,
    })),
  };
}

export function transformMangaHookChapter(
  chapter: MangaHookChapterImages,
): MangaHookChapterDto {
  return {
    title: chapter.chapterTitle,
    pages: chapter.images,
  };
}
