import { useScanStore } from '../../src/stores/scanStore';

describe('useScanStore', () => {
  beforeEach(() => {
    useScanStore.getState().reset();
  });

  it('starts in idle state', () => {
    const state = useScanStore.getState();
    expect(state.status).toBe('idle');
    expect(state.totalPhotos).toBe(0);
    expect(state.completedPhotos).toBe(0);
    expect(state.facesFound).toBe(0);
  });

  it('transitions to scanning', () => {
    useScanStore.getState().setScanning();
    expect(useScanStore.getState().status).toBe('scanning');
  });

  it('updates progress', () => {
    useScanStore.getState().setScanning();
    useScanStore.getState().updateProgress({
      totalPhotos: 1000,
      completedPhotos: 250,
      facesFound: 42,
    });

    const state = useScanStore.getState();
    expect(state.totalPhotos).toBe(1000);
    expect(state.completedPhotos).toBe(250);
    expect(state.facesFound).toBe(42);
  });

  it('transitions to complete', () => {
    useScanStore.getState().setScanning();
    useScanStore.getState().setComplete(150);

    const state = useScanStore.getState();
    expect(state.status).toBe('complete');
    expect(state.facesFound).toBe(150);
  });

  it('resets to initial state', () => {
    useScanStore.getState().setScanning();
    useScanStore.getState().updateProgress({
      totalPhotos: 500,
      completedPhotos: 500,
      facesFound: 80,
    });
    useScanStore.getState().reset();

    const state = useScanStore.getState();
    expect(state.status).toBe('idle');
    expect(state.totalPhotos).toBe(0);
  });
});
