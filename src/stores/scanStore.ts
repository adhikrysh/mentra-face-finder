import { create } from 'zustand';
import type { ScanProgress } from '@/types/face-finder';

interface ScanState extends ScanProgress {
  setScanning: () => void;
  updateProgress: (progress: Omit<ScanProgress, 'status'>) => void;
  setComplete: (totalFaces: number) => void;
  reset: () => void;
}

const initialState: ScanProgress = {
  status: 'idle',
  totalPhotos: 0,
  completedPhotos: 0,
  facesFound: 0,
};

export const useScanStore = create<ScanState>((set) => ({
  ...initialState,

  setScanning: () => set({ status: 'scanning' }),

  updateProgress: (progress) =>
    set({
      totalPhotos: progress.totalPhotos,
      completedPhotos: progress.completedPhotos,
      facesFound: progress.facesFound,
    }),

  setComplete: (totalFaces) =>
    set({
      status: 'complete',
      facesFound: totalFaces,
    }),

  reset: () => set(initialState),
}));
