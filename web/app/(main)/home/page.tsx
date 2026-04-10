"use client";

import { useEffect, useState } from "react";
import { useToast } from "@/components/ui/Toast";
import { animeService } from "@/services/anime.service";
import { FeaturedCarousel } from "@/components/anime/FeaturedCarousel";
import { AnimeCategorySection } from "@/components/anime/AnimeCategorySection";
import type { Anime } from "@/types/anime";

export default function HomePage() {
  const { toast } = useToast();

  const [featured, setFeatured] = useState<Anime[]>([]);
  const [newReleases, setNewReleases] = useState<Anime[]>([]);
  const [topRated, setTopRated] = useState<Anime[]>([]);
  const [popular, setPopular] = useState<Anime[]>([]);
  const [airing, setAiring] = useState<Anime[]>([]);
  const [upcoming, setUpcoming] = useState<Anime[]>([]);

  const [loadingFeatured, setLoadingFeatured] = useState(true);
  const [loadingNew, setLoadingNew] = useState(true);
  const [loadingTop, setLoadingTop] = useState(true);
  const [loadingPopular, setLoadingPopular] = useState(true);
  const [loadingAiring, setLoadingAiring] = useState(true);
  const [loadingUpcoming, setLoadingUpcoming] = useState(true);

  useEffect(() => {
    animeService
      .getTopRated(1, 8)
      .then((res) => {
        setFeatured(res.data.slice(0, 5));
        setTopRated(res.data);
      })
      .catch((err) => toast(err.message || "Failed to load top rated", "error"))
      .finally(() => {
        setLoadingFeatured(false);
        setLoadingTop(false);
      });

    animeService
      .getNewReleases(1, 12)
      .then((res) => setNewReleases(res.data))
      .catch((err) =>
        toast(err.message || "Failed to load new releases", "error"),
      )
      .finally(() => setLoadingNew(false));

    animeService
      .getPopular(1, 12)
      .then((res) => setPopular(res.data))
      .catch((err) =>
        toast(err.message || "Failed to load popular anime", "error"),
      )
      .finally(() => setLoadingPopular(false));

    animeService
      .getAiring(1, 12)
      .then((res) => setAiring(res.data))
      .catch((err) =>
        toast(err.message || "Failed to load airing anime", "error"),
      )
      .finally(() => setLoadingAiring(false));

    animeService
      .getUpcoming(1, 12)
      .then((res) => setUpcoming(res.data))
      .catch((err) =>
        toast(err.message || "Failed to load upcoming anime", "error"),
      )
      .finally(() => setLoadingUpcoming(false));
  }, [toast]);

  return (
    <div className="flex flex-col gap-8 p-4 md:p-6">
      {/* Featured carousel */}
      {!loadingFeatured && featured.length > 0 && (
        <FeaturedCarousel animeList={featured} />
      )}

      <AnimeCategorySection
        title="New Releases"
        animeList={newReleases}
        loading={loadingNew}
      />

      <AnimeCategorySection
        title="Top Rated"
        animeList={topRated}
        loading={loadingTop}
      />

      <AnimeCategorySection
        title="Popular"
        animeList={popular}
        loading={loadingPopular}
      />

      <AnimeCategorySection
        title="Airing Now"
        animeList={airing}
        loading={loadingAiring}
      />

      <AnimeCategorySection
        title="Upcoming"
        animeList={upcoming}
        loading={loadingUpcoming}
      />
    </div>
  );
}
