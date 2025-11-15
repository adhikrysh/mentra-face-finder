import { NativeModule, requireNativeModule } from 'expo-modules-core';

interface FaceFinderNativeModule extends NativeModule {
  startLibraryScan(): Promise<void>;
  getEmbeddingCount(): Promise<number>;
  deleteAllFaceData(): Promise<void>;
  findMatches(embeddingJson: string): Promise<string>;
  reloadEmbeddingsIntoMemory(): Promise<number>;
}

export default requireNativeModule<FaceFinderNativeModule>('FaceFinder');
