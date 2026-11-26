#include "napi/native_api.h"

#include <cmath>

#include "s2_grid.h"

namespace {

napi_value GetGridCenter(napi_env env, napi_callback_info info)
{
    size_t argc = 3;
    napi_value args[3] = {};
    double latitude;
    double longitude;
    double level;
    if (napi_get_cb_info(env, info, &argc, args, nullptr, nullptr) != napi_ok ||
        argc != 3 ||
        napi_get_value_double(env, args[0], &latitude) != napi_ok ||
        napi_get_value_double(env, args[1], &longitude) != napi_ok ||
        napi_get_value_double(env, args[2], &level) != napi_ok) {
        napi_throw_type_error(env, nullptr, "Expected numeric latitude, longitude and S2 level");
        return nullptr;
    }

    location_hap::GridCenter center;
    if (!std::isfinite(level) || std::trunc(level) != level || level < 0 ||
        level > location_hap::kMaxS2Level ||
        !location_hap::GetS2Center(latitude, longitude, static_cast<int>(level), center)) {
        napi_throw_range_error(env, nullptr, "Invalid coordinate or S2 level");
        return nullptr;
    }

    napi_value result;
    napi_value lat;
    napi_value lng;
    if (napi_create_object(env, &result) != napi_ok ||
        napi_create_double(env, center.latitude, &lat) != napi_ok ||
        napi_create_double(env, center.longitude, &lng) != napi_ok ||
        napi_set_named_property(env, result, "latitude", lat) != napi_ok ||
        napi_set_named_property(env, result, "longitude", lng) != napi_ok) {
        napi_throw_error(env, nullptr, "Unable to create S2 grid center");
        return nullptr;
    }
    return result;
}

napi_value Init(napi_env env, napi_value exports)
{
    const napi_property_descriptor properties[] = {
        {"getGridCenter", nullptr, GetGridCenter, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    return napi_define_properties(env, exports, 1, properties) == napi_ok ? exports : nullptr;
}

napi_module module = {
    1, 0, nullptr, Init, "location_s2", nullptr, {nullptr}
};

}  // namespace

extern "C" __attribute__((constructor)) void RegisterLocationS2Module()
{
    napi_module_register(&module);
}
