# Mentra Face Finder

A proof-of-concept iOS app that recognizes faces through your phone camera and searches your photo library to find where you've seen that person before.

Built as a PoC for [MentraOS](https://github.com/Mentra-Community/MentraOS) smart glasses. The phone camera stands in for the glasses camera. When this runs on actual Mentra glasses, the recognition pipeline stays the same -- only the image input source changes.

## How it works

1. On first launch, the app scans your Camera Roll and extracts a face embedding (a 512-dimensional vector) for every face it finds. These embeddings are stored locally in SQLite.

2. When you open the camera, it runs face detection on every 5th frame. For each detected face, it generates an embedding and compares it against all stored embeddings using cosine similarity (implemented as a dot product over L2-normalized vectors, accelerated with Apple's vDSP).

3. If a match is found above the threshold, the app shows which photos from your library contain that person.

Everything runs on-device. No data leaves the phone.

## Architecture

```
React Native (Expo Router)
    |
    v
Native Bridge (Expo Modules)
    |
    v
Swift Native Modules
    - Apple Vision framework (face detection + landmarks)
    - MobileFaceNet via Core ML (face embeddings)
    - GRDB.swift / SQLite (embedding storage)
    - Accelerate / vDSP (vector matching)
    - Photos framework (Camera Roll access)
```

The face recognition pipeline:

```
Camera frame
  -> Face detection (VNDetectFaceRectanglesRequest)
  -> Landmark extraction (VNDetectFaceLandmarksRequest)
  -> Face alignment (affine transform to 112x112 canonical position)
  -> Embedding generation (MobileFaceNet Core ML model -> 512-dim vector)
  -> L2 normalization
  -> Dot product search against stored embeddings
  -> Threshold filtering (>0.55 = strong match, >0.40 = possible match)
```

Apple Vision does not provide face-specific embeddings. It has `VNGenerateImageFeaturePrintRequest` for generic image similarity, but that is not trained for face identity. So we use MobileFaceNet, a lightweight CNN (~5MB) trained with ArcFace loss on MS-Celeb-1M, which gets 99.55% accuracy on LFW and runs in ~15ms on the Neural Engine.

## Project structure

```
app/                          # Expo Router screens
  camera.tsx                  # Live camera with face overlays
  scan-progress.tsx           # Photo library indexing progress
  match-results.tsx           # Grid of matched photos

src/
  components/face-finder/     # FaceBoundingBox, MatchCard, PhotoThumbnail
  stores/                     # Zustand stores (scan, camera, match)
  services/FaceRecognition.ts # JS bridge to native modules
  types/face-finder.ts        # Shared TypeScript types

modules/face-finder/ios/      # Swift native modules
  FaceDetector.swift          # Vision framework face detection
  FaceAligner.swift           # Landmark-based affine alignment
  FaceEmbedder.swift          # Core ML MobileFaceNet inference
  EmbeddingStore.swift        # SQLite storage via GRDB.swift
  EmbeddingMatcher.swift      # In-memory dot product search (Accelerate)
  FaceClusterManager.swift    # Passive face clustering (union-find)
  PhotoLibraryScanner.swift   # Camera Roll batch indexing
  FaceFinderModule.swift      # Expo module bridge
  FrameProcessorPlugin.swift  # VisionCamera frame processor

scripts/convert_model.py      # ONNX to Core ML conversion
models/                       # MobileFaceNet.mlmodel goes here
```

## Setup

Requires: Xcode 15+, Node 18+, an Apple Developer account (for running on a physical device), Python 3 (for model conversion).

```bash
# Install JS dependencies
npm install

# Get the MobileFaceNet ONNX model from the InsightFace model zoo
# (must accept 112x112 RGB input, produce 512-dim output)
pip install coremltools onnx
python scripts/convert_model.py --input models/mobilefacenet.onnx --output models/MobileFaceNet.mlmodel

# Generate the iOS project
npx expo prebuild --platform ios

# Copy the Core ML model into the Xcode project
cp models/MobileFaceNet.mlmodel ios/mentra-face-finder/MobileFaceNet.mlmodel
# Then in Xcode, add it to the target's "Copy Bundle Resources" build phase

# Install pods
cd ios && pod install && cd ..

# Run on a physical iPhone (camera doesn't work on simulator)
npx expo run:ios --device
```

## Key design decisions

**Why MobileFaceNet instead of Apple's built-in APIs?** Apple Vision can detect faces and extract landmarks, but it does not expose face identity embeddings. The closest thing is `VNGenerateImageFeaturePrintRequest`, which produces generic image feature vectors, not face-specific ones. MobileFaceNet is purpose-built for face recognition and runs fast enough for real-time use on the Neural Engine.

**Why brute-force search instead of ANN?** At the scale of a personal photo library (under 50K faces), a brute-force dot product over 512-dim vectors takes under 20ms using Accelerate's vDSP. Approximate nearest neighbor libraries like FAISS add complexity and approximation error that aren't worth it until you hit hundreds of thousands of embeddings.

**Why SQLite (GRDB.swift) instead of Core Data?** GRDB gives direct SQL access with type-safe Swift bindings and no Core Data overhead. Embedding BLOBs are compact (2KB per face), and the query patterns are simple enough that raw SQL is clearer than an ORM.

**Why a frame processor plugin instead of sending images over the RN bridge?** Sending camera frames over the React Native bridge would mean base64-encoding ~2MB images 6 times per second. The VisionCamera frame processor plugin runs natively on the camera thread and only sends ~1KB of match metadata back to JS.

## Privacy

- All processing is on-device. No face data or embeddings are sent anywhere.
- Embeddings are not reversible. A 512-dim float vector cannot reconstruct a face.
- The app never labels identities or stores names. Face clusters are anonymous UUIDs.
- The SQLite database is encrypted at rest (NSFileProtectionComplete) and excluded from iCloud backup.
- A "Delete all face data" option wipes everything.

## Tech stack

- React Native 0.74 / Expo SDK 51
- react-native-vision-camera 4.x (camera + frame processors)
- Apple Vision framework (face detection, landmarks, quality scoring)
- Core ML with MobileFaceNet (face embeddings)
- Accelerate / vDSP (SIMD-optimized vector math)
- GRDB.swift 6.x (SQLite)
- Zustand 4.x (state management)
- react-native-reanimated 3.x (animated face overlays)
