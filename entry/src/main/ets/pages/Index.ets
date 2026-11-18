import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError, systemDateTime } from '@kit.BasicServicesKit';
import { geoLocationManager } from '@kit.LocationKit';

const APPROXIMATE: Permissions = 'ohos.permission.APPROXIMATELY_LOCATION';
const PRECISE: Permissions = 'ohos.permission.LOCATION';
const TIMEOUT_MS = 30_000;
const MAX_EVENTS = 12;
const REGION_LOADING = '正在解析地区…';
const REGION_AFTER_STOP = '停止连续定位后解析最后一个点的地区';

@Entry
@Component
struct Index {
  @State private access: string = '待查询';
  @State private locationSwitch: string = '待查询';
  @State private requestingPermission: boolean = false;
  @State private locating: boolean = false;
  @State private subscribed: boolean = false;
  @State private updateCount: number = 0;
  @State private result: string = '等待定位结果';
  @State private region: string = '';
  @State private events: string[] = [];
  private visible: boolean = false;
  private latestLocation?: geoLocationManager.Location;
  private regionRequestId: number = 0;
  private listener: ((location: geoLocationManager.Location) => void) | undefined = undefined;
  private accessManager = abilityAccessCtrl.createAtManager();

  onPageShow(): void {
    this.visible = true;
    this.refreshStatus();
  }

  onPageHide(): void {
    this.visible = false;
    this.regionRequestId++;
    if (this.region === REGION_LOADING || this.region === REGION_AFTER_STOP) {
      this.region = '地区未解析，请重新获取定位';
    }
    this.stopUpdates('页面隐藏');
  }

  aboutToDisappear(): void {
    this.visible = false;
    this.regionRequestId++;
    this.stopUpdates('页面销毁', false);
  }

  private elapsedSince(start: number): number {
    return systemDateTime.getUptime(systemDateTime.TimeType.STARTUP) - start;
  }

  private addEvent(message: string): void {
    const time = new Date().toLocaleTimeString();
    this.events = [`${time}  ${message}`, ...this.events].slice(0, MAX_EVENTS);
  }

  private reportError(operation: string, error: BusinessError): void {
    this.addEvent(`${operation}失败（${error.code ?? '无错误码'}）${error.message}`);
  }

  private refreshStatus(): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const token = context.applicationInfo.accessTokenId;
      const granted = abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      const approximate = this.accessManager.checkAccessTokenSync(token, APPROXIMATE) === granted;
      const precise = this.accessManager.checkAccessTokenSync(token, PRECISE) === granted;
      this.access = `模糊 ${approximate ? '已授权' : '未授权'} · 精确 ${precise ? '已授权' : '未授权'}`;
    } catch (error) {
      this.access = '读取失败';
      this.reportError('读取权限', error as BusinessError);
    }

    try {
      this.locationSwitch = geoLocationManager.isLocationEnabled() ? '开启' : '关闭';
    } catch (error) {
      this.locationSwitch = '读取失败';
      this.reportError('读取定位开关', error as BusinessError);
    }
  }

  private async requestPermission(): Promise<void> {
    this.requestingPermission = true;
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const response = await this.accessManager.requestPermissionsFromUser(context, [APPROXIMATE, PRECISE]);
      this.addEvent(`权限请求返回 [${response.authResults.join(', ')}]`);
    } catch (error) {
      this.reportError('申请权限', error as BusinessError);
    } finally {
      this.refreshStatus();
      this.requestingPermission = false;
    }
  }

  private showLocation(source: string, location: geoLocationManager.Location, elapsed: number,
    resolveRegion: boolean = true): void {
    this.latestLocation = location;
    this.regionRequestId++;
    const time = new Date(location.timeStamp).toLocaleString();
    this.result = `${source} · ${elapsed} ms\n` +
      `纬度 ${location.latitude.toFixed(6)}° · 经度 ${location.longitude.toFixed(6)}°\n` +
      `精度 ${location.accuracy.toFixed(1)} m\n定位时间 ${time}`;
    this.addEvent(`${source}成功 · ${elapsed} ms · 精度 ${location.accuracy.toFixed(1)} m`);
    if (resolveRegion) {
      this.lookupRegion(location);
    } else {
      this.region = REGION_AFTER_STOP;
    }
  }

  private async lookupRegion(location: geoLocationManager.Location): Promise<void> {
    if (!this.visible) {
      this.region = '地区未解析，请重新获取定位';
      return;
    }
    const requestId = this.regionRequestId;
    this.region = REGION_LOADING;
    const request: geoLocationManager.ReverseGeoCodeRequest = {
      latitude: location.latitude,
      longitude: location.longitude,
      locale: 'zh',
      maxItems: 1
    };
    try {
      const addresses = await geoLocationManager.getAddressesFromLocation(request);
      if (requestId === this.regionRequestId) {
        this.region = addresses.length > 0 ? this.formatRegion(addresses[0]) : '未查到该坐标的地区';
      }
    } catch (error) {
      if (requestId === this.regionRequestId) {
        this.region = '地区解析失败，定位坐标可用';
        this.reportError('解析地区', error as BusinessError);
      }
    }
  }

  private formatRegion(address: geoLocationManager.GeoAddress): string {
    const country = address.countryName?.trim() || address.countryCode?.trim() || '';
    const parts: string[] = [];
    for (const field of [address.administrativeArea, address.subAdministrativeArea, address.locality,
      address.subLocality]) {
      const name = field?.trim();
      if (name && name !== country && !parts.includes(name)) {
        parts.push(name);
      }
    }
    if (!country && parts.length === 0) {
      return '未查到该坐标的地区';
    }
    return `国家或地区  ${country || '未知'}\n行政区  ${parts.join(' · ') || '暂无'}`;
  }

  private async locateOnce(): Promise<void> {
    this.locating = true;
    const start = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP);
    const request: geoLocationManager.CurrentLocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      timeoutMs: TIMEOUT_MS
    };
    this.addEvent('已发起单次定位，超时 30 秒');
    try {
      const location = await geoLocationManager.getCurrentLocation(request);
      this.showLocation('单次定位', location, this.elapsedSince(start));
    } catch (error) {
      this.reportError(`单次定位（${this.elapsedSince(start)} ms）`, error as BusinessError);
    } finally {
      this.locating = false;
    }
  }

  private readLastLocation(): void {
    const start = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP);
    try {
      const location = geoLocationManager.getLastLocation();
      this.showLocation('缓存定位', location, this.elapsedSince(start));
    } catch (error) {
      this.reportError('读取缓存定位', error as BusinessError);
    }
  }

  private startUpdates(): void {
    const request: geoLocationManager.LocationRequest = {
      priority: geoLocationManager.LocationRequestPriority.FIRST_FIX,
      scenario: geoLocationManager.LocationRequestScenario.UNSET,
      timeInterval: 1,
      distanceInterval: 0,
      maxAccuracy: 0
    };
    const start = systemDateTime.getUptime(systemDateTime.TimeType.STARTUP);
    const listener = (location: geoLocationManager.Location): void => {
      if (this.visible && this.listener === listener) {
        this.updateCount++;
        this.showLocation(`连续定位 #${this.updateCount}`, location, this.elapsedSince(start), false);
      }
    };

    try {
      this.updateCount = 0;
      this.listener = listener;
      geoLocationManager.on('locationChange', request, listener);
      this.subscribed = true;
      this.addEvent('已订阅连续定位，正在等待系统回调');
    } catch (error) {
      this.listener = undefined;
      this.reportError('订阅连续定位', error as BusinessError);
    }
  }

  private stopUpdates(reason: string, updateView: boolean = true): void {
    const listener = this.listener;
    if (listener === undefined) {
      return;
    }
    try {
      geoLocationManager.off('locationChange', listener);
      this.listener = undefined;
      if (updateView) {
        this.subscribed = false;
        this.addEvent(`已取消订阅（${reason}），共收到 ${this.updateCount} 次回调`);
        const location = this.latestLocation;
        if (this.visible && location !== undefined && this.region === REGION_AFTER_STOP) {
          this.lookupRegion(location);
        }
      }
    } catch (error) {
      if (updateView) {
        this.reportError(`取消订阅（${reason}）`, error as BusinessError);
      } else {
        console.warn(`取消定位订阅失败（${(error as BusinessError).code}）`);
      }
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('定位服务测试')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#143832')
        Column({ space: 6 }) {
          Text(`定位开关  ${this.locationSwitch}`).fontSize(16)
          Text(`定位权限  ${this.access}`).fontSize(15)
        }.alignItems(HorizontalAlign.Start)

        Column({ space: 8 }) {
          Button('申请定位权限')
            .enabled(!this.requestingPermission && !this.subscribed && !this.locating)
            .width('100%')
            .onClick(() => { this.requestPermission(); })
          Button('刷新开关和权限')
            .width('100%')
            .onClick(() => { this.refreshStatus(); })
          Button(this.locating ? '正在定位…' : '获取单次定位')
            .enabled(!this.requestingPermission && !this.locating)
            .width('100%')
            .onClick(() => { this.locateOnce(); })
          Button('读取缓存定位')
            .enabled(!this.requestingPermission)
            .width('100%')
            .onClick(() => { this.readLastLocation(); })
          Button(this.subscribed ? '停止连续定位' : '开始连续定位')
            .enabled(!this.requestingPermission)
            .width('100%')
            .onClick(() => {
              if (this.subscribed) {
                this.stopUpdates('手动停止');
              } else {
                this.startUpdates();
              }
            })
        }.width('100%')

        Text(`订阅${this.subscribed ? '进行中' : '未开启'} · 本轮回调 ${this.updateCount} 次`)
          .fontSize(15)
        Column({ space: 8 }) {
          Text('最近一次定位').fontSize(18).fontWeight(FontWeight.Medium)
          Text(this.result).fontSize(15).lineHeight(23)
          if (this.region.length > 0) {
            Text(this.region).fontSize(15).lineHeight(23).fontColor('#143832')
          }
        }
        .width('100%')
        .padding(16)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(Color.White)
        .borderRadius(12)

        Text('调用记录').fontSize(18).fontWeight(FontWeight.Medium)
        Text(this.events.length > 0 ? this.events.join('\n') : '暂无调用记录')
          .fontSize(14)
          .lineHeight(22)
          .width('100%')
      }
      .width('100%')
      .constraintSize({ maxWidth: 520 })
      .padding(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .align(Alignment.Top)
    .backgroundColor('#F4F7F6')
  }
}
