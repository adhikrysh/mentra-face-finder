import { useMatchStore } from '../../src/stores/matchStore';
import type { FaceMatch } from '../../src/types/face-finder';

describe('useMatchStore', () => {
  beforeEach(() => {
    useMatchStore.getState().reset();
  });

  it('starts with empty matches', () => {
    expect(useMatchStore.getState().currentMatches).toEqual([]);
    expect(useMatchStore.getState().selectedPhotoId).toBeNull();
  });

  it('sets current matches', () => {
    const matches: FaceMatch[] = [
      {
        embeddingId: 'emb_1',
        photoLocalId: 'photo_1',
        similarity: 0.7,
        confidenceLabel: 'strong',
        photoDate: 1700000000,
      },
      {
        embeddingId: 'emb_2',
        photoLocalId: 'photo_2',
        similarity: 0.45,
        confidenceLabel: 'possible',
        photoDate: 1699000000,
      },
    ];

    useMatchStore.getState().setCurrentMatches(matches);
    expect(useMatchStore.getState().currentMatches).toEqual(matches);
  });

  it('selects a photo', () => {
    useMatchStore.getState().setSelectedPhotoId('photo_1');
    expect(useMatchStore.getState().selectedPhotoId).toBe('photo_1');
  });

  it('clears selection', () => {
    useMatchStore.getState().setSelectedPhotoId('photo_1');
    useMatchStore.getState().setSelectedPhotoId(null);
    expect(useMatchStore.getState().selectedPhotoId).toBeNull();
  });
});
