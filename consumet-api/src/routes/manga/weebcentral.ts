import { FastifyRequest, FastifyReply, FastifyInstance, RegisterOptions } from 'fastify';
import { MANGA } from '@consumet/extensions';

import cache from '../../utils/cache';
import { redis, REDIS_TTL } from '../../main';
import { Redis } from 'ioredis';

const routes = async (fastify: FastifyInstance, options: RegisterOptions) => {
    const weebcentral = new MANGA.WeebCentral();

    fastify.get('/', (_, rp) => {
        rp.status(200).send({
            intro: `Welcome to the WeebCentral provider: check out the provider's website @ ${weebcentral.toString.baseUrl}`,
            routes: ['/:query', '/info/:id', '/read/:chapterId'],
            documentation: 'https://docs.consumet.org/#tag/weebcentral',
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
                    `weebcentral:search:${query}:${page ?? 1}`,
                    () => weebcentral.search(query, page),
                    REDIS_TTL,
                )
                : await weebcentral.search(query, page);

            reply.status(200).send(res);
        } catch (err) {
            reply.status(500).send({
                message: 'Something went wrong. Please try again later.',
            });
        }
    });

    // --- INFO ---
    fastify.get('/info/:id', async (request: FastifyRequest, reply: FastifyReply) => {
        const id = decodeURIComponent((request.params as { id: string }).id);

        try {
            const res = redis
                ? await cache.fetch(
                    redis as Redis,
                    `weebcentral:info:${id}`,
                    () => weebcentral.fetchMangaInfo(id),
                    REDIS_TTL,
                )
                : await weebcentral.fetchMangaInfo(id);

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
                        `weebcentral:read:${chapterId}`,
                        () => weebcentral.fetchChapterPages(chapterId),
                        REDIS_TTL,
                    )
                    : await weebcentral.fetchChapterPages(chapterId);

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
