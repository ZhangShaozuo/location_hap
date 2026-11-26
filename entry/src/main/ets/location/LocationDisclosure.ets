import { geoLocationManager } from '@kit.LocationKit';
import nativeGrid from 'liblocation_s2.so';

const REGIONAL_S2_LEVEL: number = 11;
const DISTRICT_TIMEOUT_MS: number = 5_000;

export interface RegionalLocation {
  latitude: number;
  longitude: number;
  s2Level: number;
}

export interface CityLocation {
  city: string;
}

export class LocationDisclosureError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export async function getRegionalLocation(
  request: geoLocationManager.CurrentLocationRequest
): Promise<RegionalLocation> {
  const fix = await geoLocationManager.getCurrentLocation(request);
  const center = nativeGrid.getGridCenter(fix.latitude, fix.longitude, REGIONAL_S2_LEVEL);
  return { latitude: center.latitude, longitude: center.longitude, s2Level: REGIONAL_S2_LEVEL };
}

export async function getCityLocation(): Promise<CityLocation> {
  if (typeof geoLocationManager.getCurrentDistrict !== 'function' ||
    !canIUse('SystemCapability.Location.Location.Geocoder')) {
    throw new LocationDisclosureError('当前系统不支持行政区接口，需要 API 26.0.0 或以上及相应设备能力。');
  }

  const params: geoLocationManager.DistrictRequestParams = {
    locale: 'zh',
    timeoutMs: DISTRICT_TIMEOUT_MS
  };
  const district = await geoLocationManager.getCurrentDistrict(params);
  const city = district.locality?.trim();
  if (!city) {
    throw new LocationDisclosureError('系统未返回城市。');
  }
  return { city };
}
