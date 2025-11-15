import { create } from 'zustand';
import type { DetectedFace } from '@/types/face-finder';

interface CameraState {
  detectedFaces: DetectedFace[];
  activeMatches: DetectedFace[];
  setDetectedFaces: (faces: DetectedFace[]) => void;
  reset: () => void;
}

export const useCameraStore = create<CameraState>((set) => ({
  detectedFaces: [],
  activeMatches: [],

  setDetectedFaces: (faces) =>
    set({
      detectedFaces: faces,
      activeMatches: faces.filter((f) => f.matchState === 'matched'),
    }),

  reset: () => set({ detectedFaces: [], activeMatches: [] }),
}));
