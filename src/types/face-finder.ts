/**
 * Core TypeScript interfaces for the Mentra Face Finder PoC.
 */

/** Bounding box coordinates for a detected face, normalized to [0,1] range. */
export interface BoundingBox {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** State of a single match result against the local photo library. */
export interface FaceMatch {
  /** ID of the stored face embedding this result corresponds to. */
  embeddingId: string;
  /** Local asset ID of the source photo from expo-media-library. */
  photoLocalId: string;
  /** Cosine similarity score in range [0, 1]. */
  similarity: number;
  /** Human-readable confidence label derived from similarity score. */
  confidenceLabel: 'high' | 'medium' | 'low';
  /** ISO 8601 date string of when the source photo was taken. */
  photoDate: string;
  /** Optional location metadata from the source photo EXIF data. */
  photoLocation?: {
    latitude: number;
    longitude: number;
  };
}

/** Match state for a face detected in the live camera frame. */
export type MatchState =
  | 'idle'
  | 'scanning'
  | 'matched'
  | 'no_match';

/** A face detected in the current camera frame. */
export interface DetectedFace {
  /** Unique identifier for this detection instance. */
  faceId: string;
  /** Bounding box of the face within the camera frame (normalized). */
  boundingBox: BoundingBox;
  /** Current match state for this face. */
  matchState: MatchState;
  /** Top matching results from the local photo library, sorted by similarity descending. */
  topMatches: FaceMatch[];
}

/** Progress state for a photo library scan operation. */
export interface ScanProgress {
  /** Overall status of the scan operation. */
  status: 'idle' | 'scanning' | 'complete' | 'error';
  /** Total number of photos to process in the current scan. */
  totalPhotos: number;
  /** Number of photos processed so far. */
  completedPhotos: number;
  /** Number of distinct faces found and indexed so far. */
  facesFound: number;
}

/** Reference to an image from either the camera or the local photo library. */
export interface ImageSource {
  /** Whether this image came from the live camera or the photo library. */
  type: 'camera' | 'library';
  /** For camera: a frame timestamp or UUID. For library: the local asset ID. */
  identifier: string;
}
