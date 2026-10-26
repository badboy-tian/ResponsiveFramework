import {
  FlutterPlugin, FlutterPluginBinding, AbilityAware, AbilityPluginBinding, FlutterManager,
  MethodChannel, MethodCall, MethodCallHandler, MethodResult,
  EventChannel, EventSink, StreamHandler, Log
} from '@ohos/flutter_ohos';
import display from '@ohos.display';
import window from '@ohos.window';
import HashMap from '@ohos.util.HashMap';

type Payload = HashMap<string, Object>;

// 只传公开 API 的物理坐标，由 Dart 使用当前 FlutterView DPR 做唯一一次转换。
export default class ResponsiveFrameworkPlugin implements FlutterPlugin, AbilityAware,
  MethodCallHandler, StreamHandler {
  private methods: MethodChannel | null = null;
  private events: EventChannel | null = null;
  private sink: EventSink | null = null;
  private binding: AbilityPluginBinding | null = null;
  private mainWindow: window.Window | null = null;
  private angles: number[] = [];
  private cachedSnapshot: Payload | null = null;
  private listeningStatus: boolean = false;
  private listeningMode: boolean = false;
  private listeningAngle: boolean = false;
  private listeningDisplay: boolean = false;
  private listeningSize: boolean = false;
  private listeningRect: boolean = false;

  getUniqueClassName(): string { return 'ResponsiveFrameworkPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.methods = new MethodChannel(binding.getBinaryMessenger(), 'responsive_framework/foldable/methods');
    this.events = new EventChannel(binding.getBinaryMessenger(), 'responsive_framework/foldable/events');
    this.methods.setMethodCallHandler(this);
    this.events.setStreamHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.stopListeners();
    this.sink = null;
    try { this.methods?.setMethodCallHandler(null); } catch (_) { this.warn('detach methods'); }
    try { this.events?.setStreamHandler(null); } catch (_) { this.warn('detach events'); }
    this.methods = null;
    this.events = null;
    this.binding = null;
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.binding = binding;
    if (this.sink !== null) this.startListeners();
  }

  onDetachedFromAbility(): void {
    // 引擎可能长于 Ability 存活，先释放监听，再丢弃窗口与坐标来源。
    this.stopListeners();
    this.binding = null;
    this.angles = [];
    this.emit();
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'getSnapshot') result.success(this.snapshot());
    else result.notImplemented();
  }

  onListen(_args: Object | null, sink: EventSink): void {
    this.stopListeners();
    this.sink = sink;
    this.startListeners();
    this.emit();
  }

  onCancel(_args: Object | null): void {
    this.stopListeners();
    this.sink = null;
    this.angles = [];
    this.cachedSnapshot = null;
  }

  // 使用固定回调引用，取消时只移除本插件的监听，不能影响宿主的其他插件。
  private statusChanged = (_status: display.FoldStatus): void => {
    this.angles = [];
    this.emit();
  };
  private modeChanged = (_mode: display.FoldDisplayMode): void => { this.emit(); };
  private displayChanged = (_id: number): void => { this.emit(); };
  private sizeChanged = (_size: window.Size): void => { this.emit(); };
  private rectChanged = (_rect: window.RectChangeOptions): void => { this.emit(); };
  private angleChanged = (angles: number[]): void => {
    this.angles = angles.slice();
    // 角度是高频传感器数据，几何仅在姿态、屏幕或窗口变化时重新查询。
    if (this.cachedSnapshot !== null) {
      this.cachedSnapshot.set('angles', this.angles);
      this.sink?.success(this.cachedSnapshot);
    } else this.emit();
  };

  private warn(operation: string): void {
    Log.w('ResponsiveFramework', `${operation} unavailable; retaining supported fold data`);
  }

  private startListeners(): void {
    if (!this.listeningStatus) {
      try { display.on('foldStatusChange', this.statusChanged); this.listeningStatus = true; }
      catch (_) { this.warn('foldStatusChange'); }
    }
    if (!this.listeningMode) {
      try { display.on('foldDisplayModeChange', this.modeChanged); this.listeningMode = true; }
      catch (_) { this.warn('foldDisplayModeChange'); }
    }
    if (!this.listeningAngle) {
      try { display.on('foldAngleChange', this.angleChanged); this.listeningAngle = true; }
      catch (_) { this.warn('foldAngleChange'); }
    }
    if (!this.listeningDisplay) {
      try { display.on('change', this.displayChanged); this.listeningDisplay = true; }
      catch (_) { this.warn('display change'); }
    }
    this.bindWindow();
  }

  private bindWindow(): void {
    if (this.mainWindow !== null || this.binding === null) return;
    try {
      // 使用本 Ability 的窗口，避免 getLastWindow 在多窗口场景取到其他窗口。
      this.mainWindow = FlutterManager.getInstance().getWindowStage(this.binding.getAbility()).getMainWindowSync();
    } catch (_) { return; }
    if (this.sink === null) return;
    try { this.mainWindow.on('windowSizeChange', this.sizeChanged); this.listeningSize = true; }
    catch (_) { this.warn('windowSizeChange'); }
    try { this.mainWindow.on('windowRectChange', this.rectChanged); this.listeningRect = true; }
    catch (_) { this.warn('windowRectChange'); }
  }

  private stopListeners(): void {
    if (this.listeningStatus) {
      try { display.off('foldStatusChange', this.statusChanged); } catch (_) { this.warn('off fold status'); }
    }
    if (this.listeningMode) {
      try { display.off('foldDisplayModeChange', this.modeChanged); } catch (_) { this.warn('off display mode'); }
    }
    if (this.listeningAngle) {
      try { display.off('foldAngleChange', this.angleChanged); } catch (_) { this.warn('off fold angle'); }
    }
    if (this.listeningDisplay) {
      try { display.off('change', this.displayChanged); } catch (_) { this.warn('off display change'); }
    }
    if (this.listeningSize && this.mainWindow !== null) {
      try { this.mainWindow.off('windowSizeChange', this.sizeChanged); } catch (_) { this.warn('off window size'); }
    }
    if (this.listeningRect && this.mainWindow !== null) {
      try { this.mainWindow.off('windowRectChange', this.rectChanged); } catch (_) { this.warn('off window rect'); }
    }
    this.listeningStatus = this.listeningMode = this.listeningAngle = this.listeningDisplay = false;
    this.listeningSize = this.listeningRect = false;
    this.mainWindow = null;
  }

  private rect(left: number, top: number, width: number, height: number): window.Rect {
    // 标准编解码器支持普通矩形对象，避免逐字段写入容器造成额外的可抛出调用。
    return { left: left, top: top, width: width, height: height };
  }

  private snapshot(): Payload {
    const value = new HashMap<string, Object>();
    this.cachedSnapshot = value;
    try {
      value.set('wireVersion', 1);
      value.set('angles', this.angles);
    } catch (_) { this.warn('snapshot header'); return value; }
    let foldable: boolean = false;
    try { foldable = display.isFoldable(); value.set('isFoldable', foldable); }
    catch (_) { this.warn('isFoldable'); }
    try { value.set('foldStatus', foldable ? display.getFoldStatus() : 0); }
    catch (_) { this.warn('getFoldStatus'); }
    this.bindWindow();
    if (!foldable || this.mainWindow === null) return value;
    try {
      const properties = this.mainWindow.getWindowProperties();
      const windowRect = properties.windowRect;
      const drawable = properties.drawableRect;
      const displayId = properties.displayId ?? display.getDefaultDisplaySync().id;
      value.set('displayId', displayId);
      // drawableRect 相对于窗口；windowRect 相对于屏幕，合成屏幕级 FlutterView 原点。
      value.set('viewRect', this.rect(windowRect.left + drawable.left, windowRect.top + drawable.top,
        drawable.width, drawable.height));
      const crease = this.creaseRegion();
      if (crease === undefined) return value;
      value.set('creaseDisplayId', crease.displayId);
      const rects: window.Rect[] = [];
      for (const item of crease.creaseRects) {
        rects.push(this.rect(item.left, item.top, item.width, item.height));
      }
      value.set('creases', rects);
    } catch (_) { this.warn('fold geometry'); }
    return value;
  }

  // 官方悬停态实践使用 API 20 的实时折痕；旧系统或空结果再回退，空矩形不作为几何发布。
  private creaseRegion(): display.FoldCreaseRegion | undefined {
    try {
      const live = display.getDefaultDisplaySync().getLiveCreaseRegion();
      if (live !== undefined && live.creaseRects.length > 0) return live;
    } catch (_) { /* API 20 以下不可用 */ }
    const current = display.getCurrentFoldCreaseRegion();
    return current !== undefined && current.creaseRects.length > 0 ? current : undefined;
  }

  private emit(): void { this.sink?.success(this.snapshot()); }
}
