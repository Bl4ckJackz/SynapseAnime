import { FastifyRequest, FastifyReply, FastifyInstance } from 'fastify';
import MangaSee from '../../providers/mangasee';

const routes = async (fastify: FastifyInstance) => {
    const mangaSee = new MangaSee();

    fastify.get('/:query', async (request: FastifyRequest, reply: FastifyReply) => {
        const query = (request.params as { query: string }).query;
        const res = await mangaSee.search(query);
        reply.status(200).send(res);
    });

    fastify.get('/info', async (request: FastifyRequest, reply: FastifyReply) => {
        const id = (request.query as { id: string }).id;
        if (!id) return reply.status(400).send({ message: 'id is required' });
        try {
            const res = await mangaSee.fetchMangaInfo(id);
            reply.status(200).send(res);
        } catch (err) {
            reply.status(500).send({ message: (err as Error).message });
        }
    });

    fastify.get('/read', async (request: FastifyRequest, reply: FastifyReply) => {
        const chapterId = (request.query as { chapterId: string }).chapterId;
        if (!chapterId) return reply.status(400).send({ message: 'chapterId is required' });
        try {
            const res = await mangaSee.fetchChapterPages(chapterId);
            reply.status(200).send(res);
        } catch (err) {
            reply.status(500).send({ message: (err as Error).message });
        }
    });
};

export default routes;
