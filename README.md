# HarmonyOS 定位服务测试 HAP

这是一个 ArkTS Stage 应用，最低兼容 HarmonyOS 5.0.0（API 12）。在手机、平板或支持 GPS 模拟的 HarmonyOS 模拟器上，可用它手动验证 `@kit.LocationKit` 的 `geoLocationManager`。

| 页面操作 | 调用与观察项 |
| --- | --- |
| 申请定位权限 | 一起申请模糊和精确定位权限，显示各自的授权状态 |
| 刷新开关和权限 | 用 `isLocationEnabled()` 读取系统定位开关，同时重新查询授权 |
| 获取单次定位 | 调用 `getCurrentLocation()`，超时设为 30 秒，显示坐标、精度、时间戳和调用耗时 |
| 读取缓存定位 | 调用 `getLastLocation()`；可用位置时间戳判断缓存有多旧 |
| 开始 / 停止连续定位 | 用同一回调调用 `on('locationChange')` / `off('locationChange')`；记录回调次数和从发起订阅起的耗时。页面隐藏时也会尝试取消订阅 |

「最近一次定位」显示 WGS‑84 经纬度、国家或地区，以及省／市／区等行政区。单次定位或缓存读取成功后会调用系统逆地理编码服务解析本次坐标。连续定位在停止时解析最后一个点，避免逐次回调都触发查询。此服务可能需要联网，支持情况因设备和地区而异。地区解析失败时仍可查看坐标和精度，错误码见调用记录。应用不会保存定位结果到磁盘。

## 构建与运行

1. 用支持 HarmonyOS API 12 或更高版本的 DevEco Studio 打开项目根目录，等待同步完成。
2. 使用真机时，启用开发者选项和 USB 调试，连接设备，在 **File → Project Structure → Project → Signing Configs** 配置本地调试签名。使用模拟器时，在 Device Manager 创建并启动支持 GPS 模拟的手机镜像。
3. 选中 `entry` 和目标设备，点击 **Run** 编译、安装和启动。单独构建时，在 **Build** 菜单选择 **Build Hap(s)/APP(s) → Build Hap(s)**，产物位于 `entry/build/default/outputs/default/`。

## 设备验证步骤

| 场景 | 操作 | 观察项 |
| --- | --- | --- |
| 拒绝授权 | 首次点「申请定位权限」并拒绝，然后点「获取单次定位」 | 权限显示未授权；定位调用通常报告 `201` |
| 模糊和精确定位 | 在同一地点，分别在只授权模糊和同时授权精确时做单次定位 | 对比经纬度、精度和行政区。偏移没有跨过行政边界时，两次的行政区可能相同 |
| 定位开关关闭 | 已授权时关闭系统定位开关，回到应用刷新后再次做单次定位 | 开关显示关闭。记录设备返回的错误，API 12 通常为 `3301100` |
| 单次定位和缓存 | 打开系统定位并完成一次定位，再读取缓存定位 | 分别记录两次的位置时间戳与耗时；如系统没有缓存，记录 `3301200` |
| 连续定位 | 点「开始连续定位」，在真机移动，或在模拟器的 GPS 扩展里注入不同位置 / 回放 GPX | 回调计数增加，位置随输入更新；点击停止后继续移动，确认计数不再增加。再开始一轮，切到后台后返回，确认订阅已取消 |

模拟器验证系统接口、授权和回调链路。测量实际定位精度、搜星耗时和运动表现需要使用真机。

- [华为 Geolocation Manager API](https://developer.huawei.com/consumer/en/doc/harmonyos-references/js-apis-geolocationmanager/)
- [DevEco Studio 模拟器 GPS 功能](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/ide-emulator-more-features/)
- [华为 Location Kit 错误码](https://developer.huawei.com/consumer/en/doc/harmonyos-references/errorcode-geolocationmanager/)
