import { useEffect, useState } from 'react';
import * as Location from 'expo-location';

/**
 * Where the device is, if it will say.
 *
 * Modelled as four states rather than a nullable coordinate because the
 * difference between them is what the screen has to explain. "Not yet" and
 * "never" call for different sentences, and a refusal is permanent for most of
 * the people who give one — treating it as an error would leave the app broken
 * for them forever, when everything except the ordering works without it.
 */
export type DeviceLocation =
  | { status: 'pending' }
  | { status: 'available'; latitude: number; longitude: number }
  | { status: 'declined' }
  | { status: 'unavailable' };

export function useDeviceLocation(): DeviceLocation {
  const [location, setLocation] = useState<DeviceLocation>({ status: 'pending' });

  useEffect(() => {
    let live = true;

    // Nothing awaits this. The caller renders on the pending state, and a
    // result — of any kind — arrives later or not at all.
    (async () => {
      try {
        const permission = await Location.requestForegroundPermissionsAsync();
        if (!live) return;

        if (permission.status !== Location.PermissionStatus.GRANTED) {
          setLocation({ status: 'declined' });
          return;
        }

        const position = await Location.getCurrentPositionAsync({
          accuracy: Location.Accuracy.Balanced,
        });
        if (!live) return;

        setLocation({
          status: 'available',
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
        });
      } catch {
        // A device with no location services, a browser that refuses over
        // plain HTTP, a fix that never arrives. All of it is one fact from
        // here: no coordinates, and the screen carries on without them.
        if (live) setLocation({ status: 'unavailable' });
      }
    })();

    return () => {
      live = false;
    };
  }, []);

  return location;
}
