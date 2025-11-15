import { useCameraStore } from '../../src/stores/cameraStore';

describe('useCameraStore', () => {
  beforeEach(() => {
    useCameraStore.getState().reset();
  });

  it('starts with empty detected faces', () => {
    const state = useCameraStore.getState();
    expect(state.detectedFaces).toEqual([]);
    expect(state.activeMatches).toEqual([]);
  });

  it('updates detected faces', () => {
    const faces = [
      {
        faceId: 'face_0',
        boundingBox: { x: 0.1, y: 0.2, width: 0.3, height: 0.4 },
        matchState: 'matched' as const,
        topMatches: [],
      },
    ];

    useCameraStore.getState().setDetectedFaces(faces);
    expect(useCameraStore.getState().detectedFaces).toEqual(faces);
  });

  it('extracts active matches from detected faces', () => {
    const faces = [
      {
        faceId: 'face_0',
        boundingBox: { x: 0.1, y: 0.2, width: 0.3, height: 0.4 },
        matchState: 'matched' as const,
        topMatches: [
          {
            embeddingId: 'emb_1',
            photoLocalId: 'photo_1',
            similarity: 0.65,
            confidenceLabel: 'strong' as const,
            photoDate: 1700000000,
          },
        ],
      },
      {
        faceId: 'face_1',
        boundingBox: { x: 0.5, y: 0.3, width: 0.2, height: 0.3 },
        matchState: 'no_match' as const,
        topMatches: [],
      },
    ];

    useCameraStore.getState().setDetectedFaces(faces);
    expect(useCameraStore.getState().activeMatches).toHaveLength(1);
    expect(useCameraStore.getState().activeMatches[0].faceId).toBe('face_0');
  });
});
