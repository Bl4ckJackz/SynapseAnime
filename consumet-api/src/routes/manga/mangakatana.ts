import { FastifyRequest, FastifyReply, FastifyInstance } from 'fastify';
import MangaKatana from '../../providers/mangakatana';

const routes = async (fastify: FastifyInstance) => {
    const mangaKatana = new MangaKatana();

    fastify.get('/:query', async (request: FastifyRequest, reply: FastifyReply) => {
        const query = (request.params as { query: string }).query;
        const page = (request.query as { page?: number }).page;
        const res = await mangaKatana.search(query, page);
        reply.status(200).send(res);
    });

    fastify.get('/info', async (request: FastifyRequest, reply: FastifyReply) => {
        const id = (request.query as { id: string }).id;
        if (!id) return reply.status(400).send({ message: 'id is required' });
        try {
            const res = await mangaKatana.fetchMangaInfo(id);
            reply.status(200).send(res);
        } catch (err) {
            reply.status(500).send({ message: (err as Error).message });
        }
    });

    fastify.get('/read', async (request: FastifyRequest, reply: FastifyReply) => {
        const chapterId = (request.query as { chapterId: string }).chapterId;
        if (!chapterId) return reply.status(400).send({ message: 'chapterId is required' });
        try {
            const res = await mangaKatana.fetchChapterPages(chapterId);
            reply.status(200).send(res);
        } catch (err) {
            reply.status(500).send({ message: (err as Error).message });
        }
    });
};

export default routes;
