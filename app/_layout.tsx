import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';

export default function RootLayout() {
  return (
    <>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerShown: false,
          contentStyle: { backgroundColor: '#000' },
        }}
      >
        <Stack.Screen name="index" />
        <Stack.Screen name="camera" />
        <Stack.Screen
          name="scan-progress"
          options={{ presentation: 'modal' }}
        />
        <Stack.Screen name="match-results" />
      </Stack>
    </>
  );
}
