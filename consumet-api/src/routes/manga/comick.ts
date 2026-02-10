import { FastifyRequest, FastifyReply, FastifyInstance, RegisterOptions } from 'fastify';
import ComicK from '../../providers/comick';

import cache from '../../utils/cache';
import { redis, REDIS_TTL } from '../../main';
import { Redis } from 'ioredis';

const routes = async (fastify: FastifyInstance, options: RegisterOptions) => {
    const comick = new ComicK();

    fastify.get('/', (_, rp) => {
        rp.status(200).send({
            intro: `Welcome to the ComicK provider: check out the provider's website @ ${comick.toString.baseUrl}`,
            routes: ['/:query', '/info/:id', '/read/:chapterId'],
            documentation: 'https://docs.consumet.org/#tag/comick',
        });
    });

    // --- SEARCH ---
    fastify.get('/:query', async (request: FastifyRequest, reply: FastifyReply) => {
        const { query } = request.params as { query: string };
        const { page } = request.query as { page?: number };

        try {
            const res = redis
                ? await cache.fetch(
                    redis as Redis,
                    `comick:search:${query}:${page ?? 1}`,
                    () => comick.search(query, page?.toString()),
                    REDIS_TTL,
                )
                : await comick.search(query, page?.toString());

            reply.status(200).send(res);
        } catch (err) {
            // Silently fail for search to avoid client-side error spam
            reply.status(200).send({ results: [] });
        }
    });

    // --- INFO ---
    fastify.get('/info/:id', async (request: FastifyRequest, reply: FastifyReply) => {
        const id = decodeURIComponent((request.params as { id: string }).id);

        try {
            const res = redis
                ? await cache.fetch(
                    redis as Redis,
                    `comick:info:${id}`,
                    () => comick.fetchMangaInfo(id),
                    REDIS_TTL,
                )
                : await comick.fetchMangaInfo(id);

            reply.status(200).send(res);
        } catch (err) {
            reply.status(500).send({
                message: 'Something went wrong. Please try again later.',
            });
        }
    });

    // --- READ CHAPTER ---
    fastify.get(
        '/read/:chapterId',
        async (request: FastifyRequest, reply: FastifyReply) => {
            const { chapterId } = request.params as { chapterId: string };

            try {
                const res = redis
                    ? await cache.fetch(
                        redis as Redis,
                        `comick:read:${chapterId}`,
                        () => comick.fetchChapterPages(chapterId),
                        REDIS_TTL,
                    )
                    : await comick.fetchChapterPages(chapterId);

                reply.status(200).send(res);
            } catch (err) {
                reply.status(500).send({
                    message: 'Something went wrong. Please try again later.',
                });
            }
        },
    );
};

export default routes;
