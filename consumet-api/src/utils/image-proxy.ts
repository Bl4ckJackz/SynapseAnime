import { FastifyRequest, FastifyReply, FastifyInstance, RegisterOptions } from 'fastify';
import axios from 'axios';

type ProxyRequest = FastifyRequest<{
    Querystring: { url: string; headers?: string };
}>;

export default class ImageProxy {
    public proxy = async (fastify: FastifyInstance, options: RegisterOptions) => {
        fastify.get(
            '/image-proxy',
            async (request: ProxyRequest, reply: FastifyReply) => {
                const { url, headers } = request.query;

                if (!url) {
                    return reply.status(400).send({ message: 'URL is required' });
                }

                try {
                    const parsedHeaders = headers ? JSON.parse(headers) : {};

                    const response = await axios({
                        method: 'get',
                        url: url,
                        responseType: 'stream',
                        headers: {
                            ...parsedHeaders,
                            // User-Agent is often required key
                            'User-Agent': parsedHeaders['User-Agent'] || 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                        }
                    });

                    // Forward content-type
                    if (response.headers['content-type']) {
                        reply.header('Content-Type', response.headers['content-type']);
                    }

                    // Set caching headers
                    reply.header('Cache-Control', 'public, max-age=31536000'); // Cache for 1 year

                    return reply.send(response.data);

                } catch (error) {
                    console.error('Image proxy error:', error);
                    return reply.status(500).send({ message: 'Error fetching image' });
                }
            },
        );
    };
}
