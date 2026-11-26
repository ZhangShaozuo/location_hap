# HarmonyOS 定位服务测试 HAP

这是一个 ArkTS Stage 应用。项目保留 HarmonyOS 5.0.0（API 12）兼容配置，构建需要支持 API 26.0.0 或更高版本的 DevEco Studio 和 SDK。在手机、平板或支持 GPS 模拟的 HarmonyOS 模拟器上，可用它手动验证 `@kit.LocationKit` 的 `geoLocationManager`。

| 页面操作 | 调用与观察项 |
| --- | --- |
| 申请定位权限 | 一起申请模糊和精确定位权限，显示各自的授权状态 |
| 仅申请模糊定位权限 | 只申请大致位置，用于验证两个披露分支 |
| 刷新开关和权限 | 用 `isLocationEnabled()` 读取系统定位开关，同时重新查询授权 |
| 获取单次定位 | 调用 `getCurrentLocation()`，超时设为 30 秒，显示坐标、精度、时间戳和调用耗时 |
| 读取缓存定位 | 调用 `getLastLocation()`；可用位置时间戳判断缓存有多旧 |
| 开始 / 停止连续定位 | 用同一回调调用 `on('locationChange')` / `off('locationChange')`；记录回调次数和从发起订阅起的耗时。页面隐藏时也会尝试取消订阅 |

「最近一次定位」显示 WGS‑84 经纬度、国家或地区，以及省／市／区等行政区。单次定位或缓存读取成功后会调用系统逆地理编码服务解析本次坐标。连续定位在停止时解析最后一个点，避免逐次回调都触发查询。此服务可能需要联网，支持情况因设备和地区而异。地区解析失败时仍可查看坐标和精度，错误码见调用记录。应用不会保存定位结果到磁盘。

## 位置披露测试

「位置披露测试」单独展示交给调用方的结果。「最近一次定位」是原始诊断输出，供开发者核对系统数据。

| 入口 | 调用链路 | 披露字段 |
| --- | --- | --- |
| 区域级模糊 · S2 网格中心 | Location Kit 取 WGS‑84 坐标，再通过 Node‑API 调用 Google S2 C++ 库。以 Level 11 查找所在单元并计算中心 | 网格中心经纬度、S2 层级 |
| 城市级模糊 · 仅城市 | 直接调用 `geoLocationManager.getCurrentDistrict()`，读取 `DistrictInfo.locality` | 城市名 |

Level 11 是本测试应用的固定策略，全球平均网格面积约 20.3 km²。城市分支需要运行设备支持 API 26.0.0 的行政区接口、地理编码系统能力和模糊位置权限。接口不可用、调用失败或城市字段缺失时，页面显示失败状态。该分支不通过坐标反查行政区。两个分支可通过 `entry/src/main/ets/location/LocationDisclosure.ets` 复用。

## 构建与运行

1. 用 DevEco Studio 26.0.0 或配套更新版本打开项目，安装对应的 HarmonyOS SDK、NDK 和 CMake（至少 3.18），并确认构建环境可运行 Git。首次构建时，CMake 从 GitHub 拉取固定提交的 Google S2 和 Abseil，编译并链接到 `liblocation_s2.so`。真机与模拟器分别构建 `arm64-v8a` 和 `x86_64`。
2. 使用真机时，启用开发者选项和 USB 调试，连接设备，在 **File → Project Structure → Project → Signing Configs** 配置本地调试签名。使用模拟器时，在 Device Manager 创建并启动支持 GPS 模拟的手机镜像。
3. 选中 `entry` 和目标设备，点击 **Run** 编译、安装和启动。单独构建时，在 **Build** 菜单选择 **Build Hap(s)/APP(s) → Build Hap(s)**，产物位于 `entry/build/default/outputs/default/`。

## 设备验证步骤

| 场景 | 操作 | 观察项 |
| --- | --- | --- |
| 拒绝授权 | 首次点「申请定位权限」并拒绝，然后点「获取单次定位」 | 权限显示未授权；定位调用通常报告 `201` |
| 模糊和精确定位 | 在同一地点，分别在只授权模糊和同时授权精确时做单次定位 | 对比经纬度、精度和行政区。偏移没有跨过行政边界时，两次的行政区可能相同 |
| 定位开关关闭 | 已授权时关闭系统定位开关，回到应用刷新后再次做单次定位 | 开关显示关闭。记录设备返回的错误，API 12 通常为 `3301100` |
| S2 区域级模糊 | 在模拟器注入落在同一 Level 11 单元内的 WGS‑84 坐标，在每个点点击「区域级模糊 · S2 网格中心」 | 两次应显示同一网格中心。移到不同网格后，结果应切换到新中心。可用深圳示例 `22.531472, 114.047613` 和 `22.531473, 114.047614` |
| 城市级模糊 | 在支持 API 26.0.0 的设备上仅授予模糊权限，再点击「城市级模糊 · 仅城市」 | 系统返回城市时只显示城市名。旧系统、不支持设备或接口失败时显示失败状态 |
| 单次定位和缓存 | 打开系统定位并完成一次定位，再读取缓存定位 | 分别记录两次的位置时间戳与耗时；如系统没有缓存，记录 `3301200` |
| 连续定位 | 点「开始连续定位」，在真机移动，或在模拟器的 GPS 扩展里注入不同位置 / 回放 GPX | 回调计数增加，位置随输入更新；点击停止后继续移动，确认计数不再增加。再开始一轮，切到后台后返回，确认订阅已取消 |

模拟器验证系统接口、授权和回调链路。测量实际定位精度、搜星耗时和运动表现需要使用真机。

- [华为 Geolocation Manager API](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-geolocationmanager/)
- [DevEco Studio 模拟器 GPS 功能](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-emulator-more-features/)
- [华为 Location Kit 错误码](https://developer.huawei.com/consumer/en/doc/harmonyos-references/errorcode-geolocationmanager/)
- [鸿蒙 NDK 第三方原生库接入](https://developer.huawei.com/consumer/en/doc/HarmonyOS-Guides/integrate-third-party-dlls/)
- [S2 网格尺寸](https://s2geometry.io/resources/s2cell_statistics.html)
