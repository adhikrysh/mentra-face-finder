import React from 'react';
import { View, Image, Text, TouchableOpacity, StyleSheet } from 'react-native';
import type { FaceMatch } from '@/types/face-finder';

interface PhotoThumbnailProps {
  match: FaceMatch;
  thumbnailUri: string;
  onPress: () => void;
}

export function PhotoThumbnail({ match, thumbnailUri, onPress }: PhotoThumbnailProps) {
  const date = new Date(match.photoDate * 1000);
  const dateStr = date.toLocaleDateString(undefined, {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
  });

  const labelColor =
    match.confidenceLabel === 'strong' ? '#00CC66' : '#FFAA00';

  return (
    <TouchableOpacity onPress={onPress} style={styles.container}>
      <Image source={{ uri: thumbnailUri }} style={styles.image} />
      <View style={styles.meta}>
        <Text style={styles.date}>{dateStr}</Text>
        <Text style={[styles.confidence, { color: labelColor }]}>
          {(match.similarity * 100).toFixed(0)}%
        </Text>
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    margin: 2,
    maxWidth: '33.33%',
  },
  image: {
    aspectRatio: 1,
    borderRadius: 4,
    backgroundColor: '#222',
  },
  meta: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 4,
    paddingHorizontal: 2,
  },
  date: {
    fontSize: 11,
    color: '#999',
  },
  confidence: {
    fontSize: 11,
    fontWeight: '600',
  },
});
