import { FastifyRequest, FastifyReply, FastifyInstance, RegisterOptions } from 'fastify';
import { HiAnime } from 'aniwatch';

import cache from '../../utils/cache';
import { redis, REDIS_TTL } from '../../main';
import { Redis } from 'ioredis';

const routes = async (fastify: FastifyInstance, options: RegisterOptions) => {
  const hianime = new HiAnime.Scraper();

  fastify.get('/', (_, rp) => {
    rp.status(200).send({
      intro: `Welcome to the hianime provider: check out the provider's website @ https://hianime.to/`,
      routes: [
        '/:query',
        '/info',
        '/watch/:episodeId',
        '/advanced-search',
        '/top-airing',
        '/most-popular',
        '/most-favorite',
        '/latest-completed',
        '/recently-updated',
        '/recently-added',
        '/top-upcoming',
        '/studio/:studio',
        '/subbed-anime',
        '/dubbed-anime',
        '/movie',
        '/tv',
        '/ova',
        '/ona',
        '/special',
        '/genres',
        '/genre/:genre',
        '/schedule',
        '/spotlight',
        '/search-suggestions/:query',
      ],
      documentation: 'https://docs.consumet.org/#tag/hianime',
    });
  });

  fastify.get('/:query', async (request: FastifyRequest, reply: FastifyReply) => {
    const query = (request.params as { query: string }).query;
    const page = (request.query as { page: number }).page;

    try {
      let res = redis
        ? await cache.fetch(
          redis as Redis,
          `hianime:search:v2:${query}:${page}`,
          async () => await hianime.search(query, page),
          REDIS_TTL,
        )
        : await hianime.search(query, page);

      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply
        .status(500)
        .send({ message: 'Something went wrong. Contact developer for help.' });
    }
  });

  fastify.get('/info', async (request: FastifyRequest, reply: FastifyReply) => {
    const id = (request.query as { id: string }).id;

    if (typeof id === 'undefined')
      return reply.status(400).send({ message: 'id is required' });

    try {
      const fetchInfo = async () => {
        const info = await hianime.getInfo(id);
        const { episodes } = await hianime.getEpisodes(id);
        return {
          ...info.anime.info,
          ...info.anime.moreInfo,
          seasons: info.seasons,
          relatedAnimes: info.relatedAnimes,
          recommendedAnimes: info.recommendedAnimes,
          mostPopularAnimes: info.mostPopularAnimes,
          episodes: episodes.map((x: any) => ({ ...x, id: x.episodeId })),
          title: info.anime.info.name,
        };
      };

      let res = redis
        ? await cache.fetch(
          redis as Redis,
          `hianime:info:v2:${id}`,
          fetchInfo,
          REDIS_TTL,
        )
        : await fetchInfo();

      reply.status(200).send(res);
    } catch (err) {
      reply
        .status(500)
        .send({ message: 'Something went wrong. Contact developer for help.' });
    }
  });

  fastify.get(
    '/watch/:episodeId',
    async (request: FastifyRequest, reply: FastifyReply) => {
      let episodeId = decodeURIComponent((request.params as { episodeId: string }).episodeId);
      console.log(`[HIANIME DEBUG] Raw params episodeId: ${episodeId}`);
      console.log(`[HIANIME DEBUG] Request query: ${JSON.stringify(request.query)}`);

      const query = request.query as any;
      if (query.ep && !episodeId.includes('?ep=')) {
        episodeId += `?ep=${query.ep}`;
        console.log(`[HIANIME DEBUG] Reconstructed episodeId: ${episodeId}`);
      }

      if (episodeId.includes('$episode$')) {
        episodeId = episodeId.replace('$episode$', '?ep=');
      }
      const server = (request.query as { server: string }).server;
      const category = (request.query as { category: 'sub' | 'dub' | 'raw' }).category;

      if (typeof episodeId === 'undefined')
        return reply.status(400).send({ message: 'episodeId is required' });

      try {
        const fetchSources = async () => {
          if (server && category) {
            return await hianime.getEpisodeSources(episodeId, server as any, category as any);
          }

          const servers = await hianime.getEpisodeServers(episodeId);

          let selectedCategory = category;
          if (!selectedCategory) {
            if (servers.sub && servers.sub.length > 0) selectedCategory = 'sub';
            else if (servers.dub && servers.dub.length > 0) selectedCategory = 'dub';
            else if (servers.raw && servers.raw.length > 0) selectedCategory = 'raw';
          }

          if (!selectedCategory) return await hianime.getEpisodeSources(episodeId);

          const catServers = (servers[selectedCategory as keyof typeof servers] as any[]) || [];
          const priority = ['hd-1', 'megacloud', 'vidcloud', 'vidstreaming'];

          // Sort servers: priority ones first
          const sortedServers = catServers.sort((a: any, b: any) => {
            const indexA = priority.indexOf(a.name);
            const indexB = priority.indexOf(b.name);
            if (indexA !== -1 && indexB !== -1) return indexA - indexB;
            if (indexA !== -1) return -1;
            if (indexB !== -1) return 1;
            return 0;
          });

          if (sortedServers.length === 0) return await hianime.getEpisodeSources(episodeId);

          let lastError;
          for (const s of sortedServers) {
            try {
              console.log(`[HIANIME DEBUG] Trying server: ${s.name} (${selectedCategory})`);
              const result = await hianime.getEpisodeSources(episodeId, s.name, selectedCategory as any);
              if (result && result.sources && result.sources.length > 0) {
                console.log(`[HIANIME DEBUG] Success with server: ${s.name}`);
                return result;
              }
            } catch (err) {
              console.error(`[HIANIME DEBUG] Failed server ${s.name}: ${err}`);
              lastError = err;
            }
          }
          throw lastError || new Error('No working servers found');
        };


        let res = redis
          ? await cache.fetch(
            redis as Redis,
            `hianime:watch:v3:${episodeId}:${server}:${category}`,
            fetchSources,
            REDIS_TTL,
          )
          : await fetchSources();

        reply.status(200).send(res);
      } catch (err) {
        reply
          .status(500)
          .send({ message: 'Something went wrong. Contact developer for help.' });
      }
    },
  );

  // New route suggested by user for query-based access
  fastify.get('/episode/sources', async (request: FastifyRequest, reply: FastifyReply) => {
    const episodeId = (request.query as { animeEpisodeId?: string, episodeId?: string }).animeEpisodeId || (request.query as any).episodeId;
    const server = (request.query as { server: string }).server;
    const category = (request.query as { category: 'sub' | 'dub' | 'raw' }).category;

    if (!episodeId)
      return reply.status(400).send({ message: 'animeEpisodeId or episodeId is required' });

    try {
      // Re-use smart selection logic with RETRY capability
      const fetchSources = async () => {
        if (server && category) {
          return await hianime.getEpisodeSources(episodeId, server as any, category as any);
        }

        const servers = await hianime.getEpisodeServers(episodeId);

        let selectedCategory = category;
        if (!selectedCategory) {
          if (servers.sub && servers.sub.length > 0) selectedCategory = 'sub';
          else if (servers.dub && servers.dub.length > 0) selectedCategory = 'dub';
          else if (servers.raw && servers.raw.length > 0) selectedCategory = 'raw';
        }

        if (!selectedCategory) throw new Error('No category found');

        const catServers = (servers[selectedCategory as keyof typeof servers] as any[]) || [];
        const priority = ['hd-1', 'megacloud', 'vidcloud', 'vidstreaming'];

        const sortedServers = catServers.sort((a: any, b: any) => {
          const indexA = priority.indexOf(a.name);
          const indexB = priority.indexOf(b.name);
          if (indexA !== -1 && indexB !== -1) return indexA - indexB;
          if (indexA !== -1) return -1;
          if (indexB !== -1) return 1;
          return 0;
        });

        if (sortedServers.length === 0) return await hianime.getEpisodeSources(episodeId);

        let lastError;
        for (const s of sortedServers) {
          try {
            console.log(`[HIANIME DEBUG] Trying server: ${s.name} (${selectedCategory})`);
            const result = await hianime.getEpisodeSources(episodeId, s.name, selectedCategory as any);
            if (result && result.sources && result.sources.length > 0) {
              console.log(`[HIANIME DEBUG] Success with server: ${s.name}`);
              return result;
            }
          } catch (err) {
            console.error(`[HIANIME DEBUG] Failed server ${s.name}: ${err}`);
            lastError = err;
          }
        }
        throw lastError || new Error('No working servers found');
      };

      // Different cache key base to distinguish from /watch/:id
      const cacheKey = `hianime:episode-sources:v1:${episodeId}:${server}:${category}`;
      let res = redis
        ? await cache.fetch(
          redis as Redis,
          cacheKey,
          fetchSources,
          REDIS_TTL,
        )
        : await fetchSources();

      reply.status(200).send(res);

    } catch (err) {
      reply.status(500).send({ message: 'Something went wrong.' });
    }
  });

  fastify.get('/genres', async (request: FastifyRequest, reply: FastifyReply) => {
    try {
      let res = redis
        ? await cache.fetch(
          redis as Redis,
          `hianime:genres:v2`,
          async () => {
            const home = await hianime.getHomePage();
            return home.genres;
          },
          REDIS_TTL,
        )
        : (await hianime.getHomePage()).genres;

      reply.status(200).send(res);
    } catch (err) {
      reply
        .status(500)
        .send({ message: 'Something went wrong. Contact developer for help.' });
    }
  });

  fastify.get('/schedule', async (request: FastifyRequest, reply: FastifyReply) => {
    const date = (request.query as { date: string }).date;

    try {
      let res = redis
        ? await cache.fetch(
          redis as Redis,
          `hianime:schedule:v2:${date}`,
          async () => await hianime.getEstimatedSchedule(date),
          REDIS_TTL,
        )
        : await hianime.getEstimatedSchedule(date);

      reply.status(200).send(res);
    } catch (err) {
      reply
        .status(500)
        .send({ message: 'Something went wrong. Contact developer for help.' });
    }
  });

  fastify.get('/spotlight', async (request: FastifyRequest, reply: FastifyReply) => {
    // Spotlight is usually part of home page in aniwatch
    try {
      let res = redis
        ? await cache.fetch(
          redis as Redis,
          `hianime:spotlight:v2`,
          async () => {
            const home = await hianime.getHomePage();
            return home.spotlightAnimes;
          },
          REDIS_TTL,
        )
        : (await hianime.getHomePage()).spotlightAnimes;

      reply.status(200).send(res);
    } catch (err) {
      reply
        .status(500)
        .send({ message: 'Something went wrong. Contact developer for help.' });
    }
  });

  fastify.get(
    '/search-suggestions/:query',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const query = (request.params as { query: string }).query;

      try {
        let res = redis
          ? await cache.fetch(
            redis as Redis,
            `hianime:suggestions:v2:${query}`,
            async () => await hianime.searchSuggestions(query),
            REDIS_TTL,
          )
          : await hianime.searchSuggestions(query);

        if (Array.isArray(res)) {
          const suggestions = res.map((x: any) => ({ ...x, title: x.name || x.jname }));
          reply.status(200).send({ suggestions, results: suggestions });
        } else {
          reply.status(200).send(res);
        }
      } catch (err) {
        reply
          .status(500)
          .send({ message: 'Something went wrong. Contact developer for help.' });
      }
    },
  );

  fastify.get(
    '/advanced-search',
    async (request: FastifyRequest, reply: FastifyReply) => {
      const queryParams = request.query as any;
      const page = queryParams.page || 1;
      const query = queryParams.query || '';

      try {
        const filters: any = {};
        if (queryParams.type) filters.type = queryParams.type;
        if (queryParams.status) filters.status = queryParams.status;
        if (queryParams.rated) filters.rated = queryParams.rated;
        if (queryParams.score) filters.score = queryParams.score;
        if (queryParams.season) filters.season = queryParams.season;
        if (queryParams.language) filters.language = queryParams.language;
        if (queryParams.sort) filters.sort = queryParams.sort;
        if (queryParams.genres) filters.genres = queryParams.genres;
        if (queryParams.startDate) filters.start_date = queryParams.startDate;
        if (queryParams.endDate) filters.end_date = queryParams.endDate;

        const cacheKey = `hianime:advanced-search:v2:${JSON.stringify(queryParams)}`;

        let res = redis
          ? await cache.fetch(
            redis as Redis,
            cacheKey,
            async () => await hianime.search(query, page, filters),
            REDIS_TTL,
          )
          : await hianime.search(query, page, filters);

        const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
        reply.status(200).send({ ...res, animes, results: animes });
      } catch (err) {
        reply.status(500).send({ message: 'Something went wrong.' });
      }
    },
  );

  fastify.get('/top-airing', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('top-airing' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching top airing' });
    }
  });

  fastify.get('/most-popular', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('most-popular' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching most popular' });
    }
  });

  fastify.get('/most-favorite', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('most-favorite' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching most favorite' });
    }
  });

  fastify.get('/latest-completed', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('completed' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching completed' });
    }
  });

  fastify.get('/recently-updated', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('recently-updated' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching recently updated' });
    }
  });

  fastify.get('/recently-added', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('recently-added' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching recently added' });
    }
  });

  fastify.get('/top-upcoming', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('top-upcoming' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching top upcoming' });
    }
  });

  fastify.get('/studio/:studio', async (request: FastifyRequest, reply: FastifyReply) => {
    const studio = (request.params as { studio: string }).studio;
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getProducerAnimes(studio, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching studio' });
    }
  });

  fastify.get('/subbed-anime', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('subbed-anime' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching subbed' });
    }
  });

  fastify.get('/dubbed-anime', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('dubbed-anime' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching dubbed' });
    }
  });

  fastify.get('/movie', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('movie' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching movies' });
    }
  });

  fastify.get('/tv', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('tv' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching TV' });
    }
  });

  fastify.get('/ova', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('ova' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching OVA' });
    }
  });

  fastify.get('/ona', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('ona' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching ONA' });
    }
  });

  fastify.get('/special', async (request: FastifyRequest, reply: FastifyReply) => {
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getCategoryAnime('special' as any, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching special' });
    }
  });

  fastify.get('/genre/:genre', async (request: FastifyRequest, reply: FastifyReply) => {
    const genre = (request.params as { genre: string }).genre;
    const page = (request.query as { page: number }).page || 1;
    try {
      const res = await hianime.getGenreAnime(genre, page);
      const animes = res.animes.map((x: any) => ({ ...x, title: x.name }));
      reply.status(200).send({ ...res, animes, results: animes });
    } catch (err) {
      reply.status(500).send({ message: 'Error fetching genre' });
    }
  });
};

export default routes;
