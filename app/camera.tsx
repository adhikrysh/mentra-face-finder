import React, { useCallback, useEffect, useRef, useState } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, Dimensions } from 'react-native';
import { router } from 'expo-router';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useFrameProcessor,
} from 'react-native-vision-camera';
import { Worklets } from 'react-native-worklets-core';
import { useScanStore } from '@/stores/scanStore';
import { useCameraStore } from '@/stores/cameraStore';
import { useMatchStore } from '@/stores/matchStore';
import { FaceBoundingBox } from '@/components/face-finder/FaceBoundingBox';
import { MatchCard } from '@/components/face-finder/MatchCard';
import type { DetectedFace } from '@/types/face-finder';

const { width: SCREEN_WIDTH, height: SCREEN_HEIGHT } = Dimensions.get('window');

export default function CameraScreen() {
  const { hasPermission, requestPermission } = useCameraPermission();
  const device = useCameraDevice('back');
  const scanStatus = useScanStore((s) => s.status);
  const detectedFaces = useCameraStore((s) => s.detectedFaces);
  const activeMatches = useCameraStore((s) => s.activeMatches);
  const [hasCheckedScan, setHasCheckedScan] = useState(false);

  // Request camera permission on mount
  useEffect(() => {
    if (!hasPermission) {
      requestPermission();
    }
  }, [hasPermission]);

  // Check if first scan needed
  useEffect(() => {
    if (scanStatus === 'idle' && !hasCheckedScan) {
      setHasCheckedScan(true);
      router.push('/scan-progress');
    }
  }, [scanStatus, hasCheckedScan]);

  // JS callback for frame processor results
  const setFaces = useCameraStore((s) => s.setDetectedFaces);
  const handleFaces = Worklets.createRunOnJS((result: { faces: DetectedFace[] }) => {
    if (result?.faces) {
      setFaces(result.faces);
    }
  });

  const frameProcessor = useFrameProcessor((frame) => {
    'worklet';
    // @ts-expect-error — native plugin registered as faceFinderProcess
    const result = __faceFinderProcess(frame);
    if (result) {
      handleFaces(result);
    }
  }, [handleFaces]);

  const handleSeeAll = useCallback(() => {
    if (activeMatches.length > 0 && activeMatches[0].topMatches.length > 0) {
      useMatchStore.getState().setCurrentMatches(activeMatches[0].topMatches);
      router.push('/match-results');
    }
  }, [activeMatches]);

  if (!hasPermission) {
    return (
      <View style={styles.container}>
        <Text style={styles.permissionText}>
          Camera access is required to detect faces.
        </Text>
        <TouchableOpacity onPress={requestPermission} style={styles.button}>
          <Text style={styles.buttonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  if (!device) {
    return (
      <View style={styles.container}>
        <Text style={styles.permissionText}>No camera device found.</Text>
      </View>
    );
  }

  const primaryMatch =
    activeMatches.length > 0 && activeMatches[0].topMatches.length > 0
      ? activeMatches[0].topMatches[0]
      : null;

  return (
    <View style={styles.container}>
      <Camera
        style={StyleSheet.absoluteFill}
        device={device}
        isActive={true}
        frameProcessor={frameProcessor}
        pixelFormat="yuv"
      />

      {/* Face bounding box overlays */}
      {detectedFaces.map((face) => (
        <FaceBoundingBox
          key={face.faceId}
          face={face}
          cameraWidth={SCREEN_WIDTH}
          cameraHeight={SCREEN_HEIGHT}
        />
      ))}

      {/* Match card */}
      {primaryMatch && (
        <MatchCard match={primaryMatch} onSeeAll={handleSeeAll} />
      )}

      {/* Settings gear */}
      <TouchableOpacity
        style={styles.settingsButton}
        onPress={() => router.push('/scan-progress')}
      >
        <Text style={styles.settingsIcon}>⚙</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    justifyContent: 'center',
    alignItems: 'center',
  },
  permissionText: {
    color: '#FFF',
    fontSize: 16,
    textAlign: 'center',
    paddingHorizontal: 32,
    marginBottom: 16,
  },
  button: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 8,
  },
  buttonText: {
    color: '#FFF',
    fontSize: 16,
    fontWeight: '600',
  },
  settingsButton: {
    position: 'absolute',
    top: 60,
    right: 16,
    width: 44,
    height: 44,
    justifyContent: 'center',
    alignItems: 'center',
  },
  settingsIcon: {
    fontSize: 24,
    color: '#FFF',
  },
});
