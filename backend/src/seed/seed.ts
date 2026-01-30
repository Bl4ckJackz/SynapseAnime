import { DataSource } from 'typeorm';
import { Anime, AnimeStatus } from '../entities/anime.entity';
import { Episode } from '../entities/episode.entity';
import { ReleaseSchedule } from '../entities/release-schedule.entity';
import * as dotenv from 'dotenv';

dotenv.config();

// Public HLS test streams for demo purposes
const TEST_STREAMS = [
  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8',
  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
];

// Mock anime data with diverse genres
const MOCK_ANIME: Array<{
  title: string;
  description: string;
  genres: string[];
  status: AnimeStatus;
  releaseYear: number;
  rating: number;
  totalEpisodes: number;
  coverUrl: string;
}> = [
  {
    title: 'Cyber Nexus',
    description:
      'In 2087, humanity lives alongside AI companions. When a rogue AI threatens to merge human and machine consciousness, a young hacker must choose between evolution and extinction.',
    genres: ['Sci-Fi', 'Action', 'Cyberpunk'],
    status: AnimeStatus.ONGOING,
    releaseYear: 2024,
    rating: 8.7,
    totalEpisodes: 12,
    coverUrl: 'https://picsum.photos/seed/cybernexus/300/450',
  },
  {
    title: 'Spirit Blade Chronicles',
    description:
      'A young swordsman inherits a blade containing the spirits of legendary warriors. Together with his companions, he journeys across mystical lands to seal ancient demons.',
    genres: ['Fantasy', 'Adventure', 'Action'],
    status: AnimeStatus.COMPLETED,
    releaseYear: 2023,
    rating: 9.1,
    totalEpisodes: 24,
    coverUrl: 'https://picsum.photos/seed/spiritblade/300/450',
  },
  {
    title: 'Tokyo Midnight Academy',
    description:
      'Students at an elite academy discover their classmates have supernatural abilities. As dark forces gather, alliances are tested and secrets unravel.',
    genres: ['School', 'Supernatural', 'Mystery'],
    status: AnimeStatus.ONGOING,
    releaseYear: 2024,
    rating: 8.4,
    totalEpisodes: 13,
    coverUrl: 'https://picsum.photos/seed/midnightacademy/300/450',
  },
  {
    title: 'Galactic Rangers',
    description:
      "A ragtag crew of space mercenaries becomes the galaxy's last hope when an interdimensional invasion threatens all known worlds.",
    genres: ['Sci-Fi', 'Mecha', 'Space'],
    status: AnimeStatus.COMPLETED,
    releaseYear: 2022,
    rating: 8.9,
    totalEpisodes: 26,
    coverUrl: 'https://picsum.photos/seed/galacticrangers/300/450',
  },
  {
    title: 'Demon Chef Academy',
    description:
      'In a world where cooking competitions determine political power, a half-demon chef rises through the ranks using forbidden culinary techniques.',
    genres: ['Comedy', 'Fantasy', 'Food'],
    status: AnimeStatus.ONGOING,
    releaseYear: 2024,
    rating: 8.2,
    totalEpisodes: 12,
    coverUrl: 'https://picsum.photos/seed/demonchef/300/450',
  },
  {
    title: 'Whispers of the Forgotten',
    description:
      'A medium who can hear the last words of the dead investigates cold cases, but each solved mystery brings her closer to a truth about her own past.',
    genres: ['Mystery', 'Horror', 'Psychological'],
    status: AnimeStatus.COMPLETED,
    releaseYear: 2023,
    rating: 9.3,
    totalEpisodes: 12,
    coverUrl: 'https://picsum.photos/seed/whispers/300/450',
  },
  {
    title: 'Dragon Heart Academy',
    description:
      'Young dragon tamers compete to form bonds with legendary beasts. When dragons start disappearing, students must uncover an ancient conspiracy.',
    genres: ['Fantasy', 'Adventure', 'School'],
    status: AnimeStatus.ONGOING,
    releaseYear: 2024,
    rating: 8.6,
    totalEpisodes: 25,
    coverUrl: 'https://picsum.photos/seed/dragonheart/300/450',
  },
  {
    title: 'Neon Samurai',
    description:
      'In a futuristic Neo-Tokyo, cybernetically enhanced samurai protect the innocent from corporate tyranny while following an ancient code of honor.',
    genres: ['Action', 'Cyberpunk', 'Samurai'],
    status: AnimeStatus.COMPLETED,
    releaseYear: 2022,
    rating: 9.0,
    totalEpisodes: 24,
    coverUrl: 'https://picsum.photos/seed/neonsamurai/300/450',
  },
  {
    title: 'Love in Bloom',
    description:
      'Two rival florists in a small seaside town compete for customers but slowly fall for each other as they prepare for a legendary flower festival.',
    genres: ['Romance', 'Slice of Life', 'Comedy'],
    status: AnimeStatus.COMPLETED,
    releaseYear: 2023,
    rating: 8.5,
    totalEpisodes: 12,
    coverUrl: 'https://picsum.photos/seed/loveinbloom/300/450',
  },
  {
    title: 'Phantom Melody',
    description:
      'A ghost pianist possesses a struggling musician, creating hits together. But as fame grows, so do complications between the living and the dead.',
    genres: ['Music', 'Supernatural', 'Drama'],
    status: AnimeStatus.ONGOING,
    releaseYear: 2024,
    rating: 8.8,
    totalEpisodes: 13,
    coverUrl: 'https://picsum.photos/seed/phantommelody/300/450',
  },
  {
    title: 'Ultimate Striker',
    description:
      'A soccer prodigy with a mysterious past joins a struggling high school team. With unorthodox techniques, they aim for the national championship.',
    genres: ['Sports', 'School', 'Drama'],
    status: AnimeStatus.ONGOING,
    releaseYear: 2024,
    rating: 8.3,
    totalEpisodes: 24,
    coverUrl: 'https://picsum.photos/seed/striker/300/450',
  },
  {
    title: 'Void Hunters',
    description:
      'Elite soldiers explore dimensional rifts to recover lost technology. Each mission warps their perception of reality and tests their humanity.',
    genres: ['Sci-Fi', 'Horror', 'Action'],
    status: AnimeStatus.COMPLETED,
    releaseYear: 2022,
    rating: 8.9,
    totalEpisodes: 12,
    coverUrl: 'https://picsum.photos/seed/voidhunters/300/450',
  },
  {
    title: 'Magic Council',
    description:
      'Young mages compete in deadly trials to secure seats on the ruling Magic Council. Politics, romance, and forbidden spells intertwine.',
    genres: ['Fantasy', 'Political', 'Romance'],
    status: AnimeStatus.ONGOING,
    releaseYear: 2024,
    rating: 8.4,
    totalEpisodes: 26,
    coverUrl: 'https://picsum.photos/seed/magiccouncil/300/450',
  },
  {
    title: 'Reborn as a Slime Lord',
    description:
      'A corporate worker is reincarnated as the weakest monster in a fantasy world. Through wit and diplomacy, he builds a monster nation.',
    genres: ['Isekai', 'Fantasy', 'Comedy'],
    status: AnimeStatus.COMPLETED,
    releaseYear: 2023,
    rating: 9.2,
    totalEpisodes: 24,
    coverUrl: 'https://picsum.photos/seed/slimelord/300/450',
  },
  {
    title: 'Detective Agency Zero',
    description:
      "A high school detective club tackles supernatural mysteries that the police can't explain. Their latest case threatens reality itself.",
    genres: ['Mystery', 'Supernatural', 'School'],
    status: AnimeStatus.ONGOING,
    releaseYear: 2024,
    rating: 8.7,
    totalEpisodes: 13,
    coverUrl: 'https://picsum.photos/seed/detectivezero/300/450',
  },
  {
    title: 'Cooking Wars: Revolution',
    description:
      'The sons and daughters of legendary chefs clash in the ultimate cooking tournament. Ancient recipes meet modern innovation.',
    genres: ['Food', 'Action', 'School'],
    status: AnimeStatus.COMPLETED,
    releaseYear: 2022,
    rating: 8.8,
    totalEpisodes: 36,
    coverUrl: 'https://picsum.photos/seed/cookingwars/300/450',
  },
  {
    title: 'Eternal Summer',
    description:
      'Five friends reunite at their childhood beach town, confronting old feelings and buried secrets from the summer that changed everything.',
    genres: ['Romance', 'Drama', 'Slice of Life'],
    status: AnimeStatus.COMPLETED,
    releaseYear: 2023,
    rating: 9.0,
    totalEpisodes: 12,
    coverUrl: 'https://picsum.photos/seed/eternalsummer/300/450',
  },
  {
    title: 'Mecha Legion Zero',
    description:
      "Humanity's last mechas defend against an alien invasion. Pilots form mental links with their machines, but the connection comes at a cost.",
    genres: ['Mecha', 'Sci-Fi', 'Action'],
    status: AnimeStatus.ONGOING,
    releaseYear: 2024,
    rating: 8.5,
    totalEpisodes: 24,
    coverUrl: 'https://picsum.photos/seed/mechalegion/300/450',
  },
];

async function seed() {
  const dataSource = new DataSource({
    type: 'sqlite',
    database: './anime_player.db',
    entities: [Anime, Episode, ReleaseSchedule],
    synchronize: true,
  });

  await dataSource.initialize();
  console.log('Database connected');

  const animeRepo = dataSource.getRepository(Anime);
  const episodeRepo = dataSource.getRepository(Episode);
  const scheduleRepo = dataSource.getRepository(ReleaseSchedule);

  // Clear existing data
  await scheduleRepo.delete({});
  await episodeRepo.delete({});
  await animeRepo.delete({});
  console.log('Cleared existing data');

  // Insert anime
  for (const animeData of MOCK_ANIME) {
    const anime = animeRepo.create(animeData);
    await animeRepo.save(anime);

    // Generate episodes (3-5 per anime for demo)
    const episodeCount = Math.min(
      animeData.totalEpisodes,
      Math.floor(Math.random() * 3) + 3,
    );
    const episodes: Episode[] = [];

    for (let i = 1; i <= episodeCount; i++) {
      const episode = episodeRepo.create({
        animeId: anime.id,
        number: i,
        title: `Episode ${i}: ${generateEpisodeTitle(i)}`,
        duration: 1200 + Math.floor(Math.random() * 600), // 20-30 minutes
        streamUrl: TEST_STREAMS[i % TEST_STREAMS.length],
        thumbnail: `https://picsum.photos/seed/${anime.title.toLowerCase().replace(/\s/g, '')}-ep${i}/320/180`,
      });
      episodes.push(episode);
    }
    await episodeRepo.save(episodes);

    // Add release schedule for ongoing anime
    if (animeData.status === AnimeStatus.ONGOING) {
      const nextEpisode = episodeCount + 1;
      const releaseDate = new Date();
      releaseDate.setDate(
        releaseDate.getDate() + Math.floor(Math.random() * 7) + 1,
      );

      const schedule = scheduleRepo.create({
        animeId: anime.id,
        episodeNumber: nextEpisode,
        releaseDate: releaseDate,
        notified: false,
      });
      await scheduleRepo.save(schedule);
    }

    console.log(`Created: ${anime.title} with ${episodeCount} episodes`);
  }

  console.log('\n✅ Seed completed successfully!');
  console.log(`Total anime: ${MOCK_ANIME.length}`);

  await dataSource.destroy();
}

function generateEpisodeTitle(episodeNumber: number): string {
  const titles = [
    'The Beginning',
    'First Steps',
    'New Challenges',
    'Rising Tensions',
    'The Revelation',
    'Decisive Battle',
    'Hidden Truths',
    'Bonds of Fate',
    'The Turning Point',
    'Dark Awakening',
  ];
  return titles[(episodeNumber - 1) % titles.length];
}

seed().catch((error) => {
  console.error('Seed failed:', error);
  process.exit(1);
});
