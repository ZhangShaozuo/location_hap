#include "s2_grid.h"

#include <cmath>

#include "s2/s2cell_id.h"
#include "s2/s2latlng.h"

namespace location_hap {

bool GetS2Center(double latitude, double longitude, int level, GridCenter& center)
{
    static_assert(kMaxS2Level == S2CellId::kMaxLevel);
    if (!std::isfinite(latitude) || !std::isfinite(longitude) ||
        latitude < -90.0 || latitude > 90.0 ||
        longitude < -180.0 || longitude > 180.0 ||
        level < 0 || level > kMaxS2Level) {
        return false;
    }

    // Both spellings of the antimeridian identify the same point.
    if (longitude == 180.0) {
        longitude = -180.0;
    }
    if (std::abs(latitude) == 90.0) {
        longitude = 0.0;
    }
    const S2LatLng point = S2LatLng::FromDegrees(latitude, longitude);
    const S2LatLng gridCenter = S2CellId(point).parent(level).ToLatLng();
    center = {gridCenter.lat().degrees(), gridCenter.lng().degrees()};
    return true;
}

}  // namespace location_hap
