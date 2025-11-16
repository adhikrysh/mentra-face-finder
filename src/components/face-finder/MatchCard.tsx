import React from 'react';
import { View, Text, Image, TouchableOpacity, StyleSheet } from 'react-native';
import Animated, { FadeInDown, FadeOutDown } from 'react-native-reanimated';
import type { FaceMatch } from '@/types/face-finder';

interface MatchCardProps {
  match: FaceMatch;
  thumbnailUri?: string;
  onSeeAll: () => void;
}

export function MatchCard({ match, thumbnailUri, onSeeAll }: MatchCardProps) {
  const label =
    match.confidenceLabel === 'strong' ? 'Strong match' : 'Possible match';
  const labelColor =
    match.confidenceLabel === 'strong' ? '#00CC66' : '#FFAA00';

  return (
    <Animated.View
      entering={FadeInDown.duration(300)}
      exiting={FadeOutDown.duration(200)}
      style={styles.container}
    >
      {thumbnailUri && (
        <Image source={{ uri: thumbnailUri }} style={styles.thumbnail} />
      )}
      <View style={styles.info}>
        <Text style={[styles.label, { color: labelColor }]}>{label}</Text>
        <Text style={styles.similarity}>
          {(match.similarity * 100).toFixed(0)}% similarity
        </Text>
      </View>
      <TouchableOpacity onPress={onSeeAll} style={styles.seeAll}>
        <Text style={styles.seeAllText}>See all</Text>
      </TouchableOpacity>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  container: {
    position: 'absolute',
    bottom: 40,
    left: 16,
    right: 16,
    backgroundColor: 'rgba(0, 0, 0, 0.85)',
    borderRadius: 12,
    flexDirection: 'row',
    alignItems: 'center',
    padding: 12,
  },
  thumbnail: {
    width: 56,
    height: 56,
    borderRadius: 8,
    backgroundColor: '#333',
  },
  info: {
    flex: 1,
    marginLeft: 12,
  },
  label: {
    fontSize: 16,
    fontWeight: '600',
  },
  similarity: {
    fontSize: 13,
    color: '#999',
    marginTop: 2,
  },
  seeAll: {
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  seeAllText: {
    color: '#007AFF',
    fontSize: 15,
    fontWeight: '500',
  },
});
