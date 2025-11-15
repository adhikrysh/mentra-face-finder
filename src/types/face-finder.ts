export interface DetectedFace {
  faceId: string;
  boundingBox: BoundingBox;
  matchState: 'searching' | 'matched' | 'no_match' | 'low_quality';
  topMatches: FaceMatch[];
}

export interface BoundingBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface FaceMatch {
  embeddingId: string;
  photoLocalId: string;
  similarity: number;
  confidenceLabel: 'strong' | 'possible';
  photoDate: number;
  photoLocation?: { lat: number; lon: number };
}

export interface ScanProgress {
  status: 'idle' | 'scanning' | 'complete';
  totalPhotos: number;
  completedPhotos: number;
  facesFound: number;
}

export interface ImageSource {
  type: 'camera_frame' | 'glasses_photo' | 'library_asset';
  identifier: string;
}
