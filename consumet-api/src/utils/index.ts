import { FastifyInstance, RegisterOptions } from 'fastify';

import Providers from './providers';

import ImageProxy from './image-proxy';

const routes = async (fastify: FastifyInstance, options: RegisterOptions) => {
  await fastify.register(new Providers().getProviders);
  await fastify.register(new ImageProxy().proxy);

  fastify.get('/', async (request: any, reply: any) => {
    reply.status(200).send('Welcome to Consumet Utils!');
  });
};

export default routes;
