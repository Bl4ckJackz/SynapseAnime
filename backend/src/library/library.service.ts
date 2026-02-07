import { Injectable, StreamableFile } from '@nestjs/common';
import * as fs from 'fs';
import * as path from 'path';
import { spawn } from 'child_process';
import { Response } from 'express';
import { v4 as uuidv4 } from 'uuid';

export interface LibraryFolder {
    id: string;
    name: string;
    path: string;
    type: 'anime' | 'manga' | 'mixed';
}

interface VideoFile {
    id: string;
    filename: string;
    path: string;
    title: string;
    episode: number;
    size: number;
}

export interface LocalAnime {
    title: string;
    episodes: VideoFile[];
}

@Injectable()
export class LibraryService {
    private folders: LibraryFolder[] = [];
    private videoRegistry: Map<string, string> = new Map();

    constructor() {
        this.loadFolders();
    }

    private loadFolders() {
        const libraryPath = process.env.LIBRARY_PATH || 'D:/Anime';
        this.folders = [
            {
                id: 'default',
                name: 'Anime Library',
                path: libraryPath,
                type: 'anime',
            },
        ];
    }

    getFolders(): LibraryFolder[] {
        return this.folders;
    }

    async getFolderById(folderId: string): Promise<LibraryFolder | undefined> {
        return this.folders.find((f) => f.id === folderId);
    }

    addFolder(
        name: string,
        folderPath: string,
        type: 'anime' | 'manga' | 'mixed' = 'anime',
    ): LibraryFolder {
        const folder: LibraryFolder = {
            id: uuidv4(),
            name,
            path: folderPath,
            type,
        };
        this.folders.push(folder);
        return folder;
    }

    async getFolderContents(folderPath: string): Promise<string[]> {
        try {
            const entries = await fs.promises.readdir(folderPath, {
                withFileTypes: true,
            });
            return entries.filter((e) => e.isDirectory()).map((e) => e.name);
        } catch (error) {
            console.error('Error reading folder:', error);
            return [];
        }
    }

    async scanVideos(folderPath: string): Promise<LocalAnime[]> {
        const groupedEpisodes: Map<string, VideoFile[]> = new Map();

        try {
            await this.scanRecursive(folderPath, groupedEpisodes);
        } catch (error) {
            console.error('Error scanning videos:', error);
        }

        const animes: LocalAnime[] = [];
        groupedEpisodes.forEach((episodes, title) => {
            episodes.sort((a, b) => a.episode - b.episode);
            animes.push({ title, episodes });
        });

        animes.sort((a, b) => a.title.localeCompare(b.title));
        return animes;
    }

    private async scanRecursive(
        dirPath: string,
        groupedEpisodes: Map<string, VideoFile[]>,
    ) {
        const entries = await fs.promises.readdir(dirPath, { withFileTypes: true });

        for (const entry of entries) {
            const fullPath = path.join(dirPath, entry.name);

            if (entry.isDirectory()) {
                await this.scanRecursive(fullPath, groupedEpisodes);
            } else if (entry.isFile()) {
                const ext = path.extname(entry.name).toLowerCase();
                if (['.mp4', '.mkv', '.avi', '.mov', '.webm'].includes(ext)) {
                    const parsed = this.parseFilename(entry.name);
                    const videoId = uuidv4();

                    this.videoRegistry.set(videoId, fullPath);

                    const stat = await fs.promises.stat(fullPath);

                    const video: VideoFile = {
                        id: videoId,
                        filename: entry.name,
                        path: fullPath,
                        title: parsed.title,
                        episode: parsed.episode,
                        size: stat.size,
                    };

                    if (!groupedEpisodes.has(parsed.title)) {
                        groupedEpisodes.set(parsed.title, []);
                    }
                    groupedEpisodes.get(parsed.title)!.push(video);
                }
            }
        }
    }

    private parseFilename(filename: string): { title: string; episode: number } {
        const regex = /(?:\[.*?\]\s*)?([^-]+?)\s*-\s*(\d+)/i;
        const match = regex.exec(filename);

        if (match) {
            return {
                title: match[1].trim(),
                episode: parseInt(match[2], 10),
            };
        }

        return {
            title: path.basename(filename, path.extname(filename)),
            episode: 0,
        };
    }

    async getVideoPath(videoId: string): Promise<string | undefined> {
        return this.videoRegistry.get(videoId);
    }

    async generateHlsPlaylist(videoPath: string, videoId: string): Promise<string> {
        const segmentDuration = 10;
        const estimatedDuration = 1800;

        let playlist = '#EXTM3U\n';
        playlist += '#EXT-X-VERSION:3\n';
        playlist += `#EXT-X-TARGETDURATION:${segmentDuration}\n`;
        playlist += '#EXT-X-MEDIA-SEQUENCE:0\n';

        const numSegments = Math.ceil(estimatedDuration / segmentDuration);
        for (let i = 0; i < numSegments; i++) {
            playlist += `#EXTINF:${segmentDuration},\n`;
            playlist += `segment/${i}.ts\n`;
        }
        playlist += '#EXT-X-ENDLIST\n';

        return playlist;
    }

    async getHlsSegment(
        videoPath: string,
        segmentId: string,
    ): Promise<StreamableFile> {
        const segmentNum = parseInt(segmentId, 10);
        const segmentDuration = 10;
        const startTime = segmentNum * segmentDuration;

        return new Promise((resolve, reject) => {
            const chunks: Buffer[] = [];

            const ffmpeg = spawn('ffmpeg', [
                '-ss',
                startTime.toString(),
                '-i',
                videoPath,
                '-t',
                segmentDuration.toString(),
                '-c:v',
                'libx264',
                '-c:a',
                'aac',
                '-preset',
                'ultrafast',
                '-f',
                'mpegts',
                '-',
            ]);

            ffmpeg.stdout.on('data', (chunk) => {
                chunks.push(chunk);
            });

            ffmpeg.on('close', (code) => {
                if (code === 0) {
                    const buffer = Buffer.concat(chunks);
                    resolve(new StreamableFile(buffer));
                } else {
                    reject(new Error(`FFmpeg exited with code ${code}`));
                }
            });

            ffmpeg.on('error', reject);
        });
    }

    async streamDirect(
        videoPath: string,
        res: Response,
        start?: string,
    ): Promise<StreamableFile> {
        const stat = await fs.promises.stat(videoPath);
        const fileSize = stat.size;
        const startByte = start ? parseInt(start, 10) : 0;

        res.set({
            'Content-Type': 'video/mp4',
            'Content-Length': String(fileSize - startByte),
            'Accept-Ranges': 'bytes',
        });

        const stream = fs.createReadStream(videoPath, { start: startByte });
        return new StreamableFile(stream);
    }
}
