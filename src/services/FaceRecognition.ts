import FaceFinderModule from '@modules/face-finder/src/FaceFinderModule';
import { useScanStore } from '@/stores/scanStore';
import type { FaceMatch } from '@/types/face-finder';

class FaceRecognition {
  private static instance: FaceRecognition;
  private eventSubscriptions: Array<{ remove: () => void }> = [];

  private constructor() {}

  static getInstance(): FaceRecognition {
    if (!FaceRecognition.instance) {
      FaceRecognition.instance = new FaceRecognition();
    }
    return FaceRecognition.instance;
  }

  /** Subscribe to native scan events */
  setupEventListeners(): void {
    const progressSub = FaceFinderModule.addListener(
      'onScanProgress',
      (event: { totalPhotos: number; completedPhotos: number; facesFound: number }) => {
        useScanStore.getState().updateProgress({
          totalPhotos: event.totalPhotos,
          completedPhotos: event.completedPhotos,
          facesFound: event.facesFound,
        });
      }
    );

    const completeSub = FaceFinderModule.addListener(
      'onScanComplete',
      (event: { totalFaces: number }) => {
        useScanStore.getState().setComplete(event.totalFaces);
      }
    );

    this.eventSubscriptions.push(progressSub, completeSub);
  }

  /** Tear down event listeners */
  cleanup(): void {
    this.eventSubscriptions.forEach((sub) => sub.remove());
    this.eventSubscriptions = [];
  }

  /** Start scanning the photo library for faces */
  async startLibraryScan(): Promise<void> {
    useScanStore.getState().setScanning();
    await FaceFinderModule.startLibraryScan();
  }

  /** Get the number of indexed face embeddings */
  async getEmbeddingCount(): Promise<number> {
    return FaceFinderModule.getEmbeddingCount();
  }

  /** Delete all face data (embeddings + clusters) */
  async deleteAllFaceData(): Promise<void> {
    await FaceFinderModule.deleteAllFaceData();
    useScanStore.getState().reset();
  }

  /** Reload embeddings into memory (call after scan completes) */
  async reloadEmbeddings(): Promise<number> {
    return FaceFinderModule.reloadEmbeddingsIntoMemory();
  }
}

export default FaceRecognition.getInstance();
