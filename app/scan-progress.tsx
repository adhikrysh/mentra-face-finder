import React, { useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';
import { router } from 'expo-router';
import { useScanStore } from '@/stores/scanStore';
import FaceRecognition from '@/services/FaceRecognition';

export default function ScanProgressScreen() {
  const { status, totalPhotos, completedPhotos, facesFound } = useScanStore();

  useEffect(() => {
    FaceRecognition.setupEventListeners();
    FaceRecognition.startLibraryScan();

    return () => {
      FaceRecognition.cleanup();
    };
  }, []);

  useEffect(() => {
    if (status === 'complete') {
      // Auto-dismiss after scan completes
      const timeout = setTimeout(() => {
        router.back();
      }, 1500);
      return () => clearTimeout(timeout);
    }
  }, [status]);

  const progress =
    totalPhotos > 0 ? completedPhotos / totalPhotos : 0;

  return (
    <View style={styles.container}>
      <Text style={styles.title}>
        {status === 'complete' ? 'Scan Complete' : 'Scanning Photo Library'}
      </Text>

      <View style={styles.progressBarOuter}>
        <View
          style={[styles.progressBarInner, { width: `${progress * 100}%` }]}
        />
      </View>

      <View style={styles.stats}>
        <View style={styles.statRow}>
          <Text style={styles.statLabel}>Photos scanned</Text>
          <Text style={styles.statValue}>
            {completedPhotos.toLocaleString()} / {totalPhotos.toLocaleString()}
          </Text>
        </View>

        <View style={styles.statRow}>
          <Text style={styles.statLabel}>Faces discovered</Text>
          <Text style={styles.statValue}>{facesFound.toLocaleString()}</Text>
        </View>
      </View>

      {status === 'complete' && (
        <Text style={styles.doneText}>
          Indexed {facesFound} faces. Returning to camera...
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    justifyContent: 'center',
    paddingHorizontal: 32,
  },
  title: {
    fontSize: 22,
    fontWeight: '700',
    color: '#FFF',
    textAlign: 'center',
    marginBottom: 32,
  },
  progressBarOuter: {
    height: 6,
    backgroundColor: '#333',
    borderRadius: 3,
    overflow: 'hidden',
  },
  progressBarInner: {
    height: '100%',
    backgroundColor: '#007AFF',
    borderRadius: 3,
  },
  stats: {
    marginTop: 24,
    gap: 12,
  },
  statRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  statLabel: {
    fontSize: 15,
    color: '#999',
  },
  statValue: {
    fontSize: 15,
    color: '#FFF',
    fontWeight: '500',
  },
  doneText: {
    fontSize: 14,
    color: '#00CC66',
    textAlign: 'center',
    marginTop: 24,
  },
});
