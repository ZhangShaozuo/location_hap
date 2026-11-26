#ifndef LOCATION_HAP_S2_GRID_H
#define LOCATION_HAP_S2_GRID_H

namespace location_hap {

struct GridCenter {
    double latitude;
    double longitude;
};

constexpr int kMaxS2Level = 30;

bool GetS2Center(double latitude, double longitude, int level, GridCenter& center);

}  // namespace location_hap

#endif
