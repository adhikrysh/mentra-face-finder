import { create } from 'zustand';
import type { FaceMatch } from '@/types/face-finder';

interface MatchState {
  currentMatches: FaceMatch[];
  selectedPhotoId: string | null;
  setCurrentMatches: (matches: FaceMatch[]) => void;
  setSelectedPhotoId: (id: string | null) => void;
  reset: () => void;
}

export const useMatchStore = create<MatchState>((set) => ({
  currentMatches: [],
  selectedPhotoId: null,

  setCurrentMatches: (matches) => set({ currentMatches: matches }),
  setSelectedPhotoId: (id) => set({ selectedPhotoId: id }),
  reset: () => set({ currentMatches: [], selectedPhotoId: null }),
}));
