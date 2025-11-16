import React, { useEffect, useState } from 'react';
import {
  View,
  Text,
  FlatList,
  TouchableOpacity,
  Image,
  StyleSheet,
  Dimensions,
} from 'react-native';
import { router } from 'expo-router';
import * as MediaLibrary from 'expo-media-library';
import { useMatchStore } from '@/stores/matchStore';
import { PhotoThumbnail } from '@/components/face-finder/PhotoThumbnail';
import type { FaceMatch } from '@/types/face-finder';

const NUM_COLUMNS = 3;
const SCREEN_WIDTH = Dimensions.get('window').width;
const THUMBNAIL_SIZE = Math.floor(SCREEN_WIDTH / NUM_COLUMNS) - 4;

export default function MatchResultsScreen() {
  const currentMatches = useMatchStore((s) => s.currentMatches);
  const selectedPhotoId = useMatchStore((s) => s.selectedPhotoId);
  const setSelectedPhotoId = useMatchStore((s) => s.setSelectedPhotoId);
  const [thumbnails, setThumbnails] = useState<Record<string, string>>({});

  // Load thumbnails for matched photos
  useEffect(() => {
    loadThumbnails();
  }, [currentMatches]);

  async function loadThumbnails() {
    const uriMap: Record<string, string> = {};

    for (const match of currentMatches) {
      try {
        const asset = await MediaLibrary.getAssetInfoAsync(match.photoLocalId);
        if (asset?.localUri) {
          uriMap[match.photoLocalId] = asset.localUri;
        }
      } catch {
        // Skip assets that can't be loaded
      }
    }

    setThumbnails(uriMap);
  }

  const renderItem = ({ item }: { item: FaceMatch }) => {
    const uri = thumbnails[item.photoLocalId];
    if (!uri) return null;

    return (
      <PhotoThumbnail
        match={item}
        thumbnailUri={uri}
        onPress={() => setSelectedPhotoId(item.photoLocalId)}
      />
    );
  };

  // Full-screen photo view
  if (selectedPhotoId && thumbnails[selectedPhotoId]) {
    return (
      <View style={styles.fullScreenContainer}>
        <Image
          source={{ uri: thumbnails[selectedPhotoId] }}
          style={styles.fullScreenImage}
          resizeMode="contain"
        />
        <TouchableOpacity
          style={styles.closeButton}
          onPress={() => setSelectedPhotoId(null)}
        >
          <Text style={styles.closeText}>Close</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity onPress={() => router.back()}>
          <Text style={styles.backText}>Back</Text>
        </TouchableOpacity>
        <Text style={styles.title}>
          {currentMatches.length} Match{currentMatches.length !== 1 ? 'es' : ''}
        </Text>
        <View style={{ width: 50 }} />
      </View>

      {currentMatches.length === 0 ? (
        <View style={styles.emptyState}>
          <Text style={styles.emptyText}>No matches found</Text>
        </View>
      ) : (
        <FlatList
          data={currentMatches}
          keyExtractor={(item) => item.embeddingId}
          renderItem={renderItem}
          numColumns={NUM_COLUMNS}
          getItemLayout={(_, index) => ({
            length: THUMBNAIL_SIZE + 30,
            offset: (THUMBNAIL_SIZE + 30) * Math.floor(index / NUM_COLUMNS),
            index,
          })}
          contentContainerStyle={styles.grid}
        />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 60,
    paddingHorizontal: 16,
    paddingBottom: 12,
  },
  backText: {
    color: '#007AFF',
    fontSize: 17,
  },
  title: {
    color: '#FFF',
    fontSize: 17,
    fontWeight: '600',
  },
  grid: {
    padding: 2,
  },
  emptyState: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
  },
  emptyText: {
    color: '#666',
    fontSize: 16,
  },
  fullScreenContainer: {
    flex: 1,
    backgroundColor: '#000',
    justifyContent: 'center',
  },
  fullScreenImage: {
    width: '100%',
    height: '100%',
  },
  closeButton: {
    position: 'absolute',
    top: 60,
    right: 16,
    paddingHorizontal: 16,
    paddingVertical: 8,
    backgroundColor: 'rgba(0, 0, 0, 0.6)',
    borderRadius: 8,
  },
  closeText: {
    color: '#FFF',
    fontSize: 16,
  },
});
