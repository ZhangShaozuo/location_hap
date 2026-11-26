export interface S2GridCenter {
  latitude: number;
  longitude: number;
}

export const getGridCenter: (latitude: number, longitude: number, level: number) => S2GridCenter;
