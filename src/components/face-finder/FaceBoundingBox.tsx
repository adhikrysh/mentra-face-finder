import React from 'react';
import { StyleSheet } from 'react-native';
import Animated, {
  useAnimatedStyle,
  withTiming,
} from 'react-native-reanimated';
import type { DetectedFace } from '@/types/face-finder';

interface FaceBoundingBoxProps {
  face: DetectedFace;
  cameraWidth: number;
  cameraHeight: number;
}

const MATCH_STATE_COLORS: Record<DetectedFace['matchState'], string> = {
  searching: '#888888',
  matched: '#00CC66',
  no_match: '#88888844',
  low_quality: '#88888822',
};

export function FaceBoundingBox({
  face,
  cameraWidth,
  cameraHeight,
}: FaceBoundingBoxProps) {
  const borderColor = MATCH_STATE_COLORS[face.matchState];

  const animatedStyle = useAnimatedStyle(() => ({
    left: withTiming(face.boundingBox.x * cameraWidth, { duration: 100 }),
    top: withTiming(face.boundingBox.y * cameraHeight, { duration: 100 }),
    width: withTiming(face.boundingBox.width * cameraWidth, { duration: 100 }),
    height: withTiming(face.boundingBox.height * cameraHeight, { duration: 100 }),
  }));

  return (
    <Animated.View
      style={[
        styles.box,
        { borderColor },
        animatedStyle,
      ]}
    />
  );
}

const styles = StyleSheet.create({
  box: {
    position: 'absolute',
    borderWidth: 2,
    borderRadius: 4,
  },
});
