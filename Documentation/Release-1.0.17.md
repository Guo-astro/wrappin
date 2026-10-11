# WrapPin 1.0.17（Build 55）

## 中文

本版让地图上的地点卡片可以收起，给选点留出更多地图空间，回应 [#29](https://github.com/suversal/WrapPin/issues/29)。两个版本来自同一份源码和同一个版本号。

### 改进

- 地点卡片可以收起：在卡片上向下滑，或轻点卡片顶部的横条；向上滑或再点一次横条即可展开。WrapPin 会记住这个选择，首次安装默认展开。
- 收起后卡片只保留地点名称、一行地址或坐标、收藏和清除按钮，以及主按钮。模拟坐标方式缩成地址旁的小菜单，仍可直接切换，模拟进行中切换照旧立即生效。
- 收起时隐藏坐标方式的选择器和说明、“复制坐标”、预览步行和预览驾车，以及空闲和正常模拟中的提示文案。未配对、连接中、失败、正在恢复真实位置等状态文案，以及“停止并恢复”按钮始终显示。
- 开启“减弱动态效果”时，收起和展开只使用短暂的淡入淡出。

### 下载与验证

- 标准版：`WrapPin-Standard-1.0.17-build55-unsigned.ipa`；Bundle ID `com.suversal.wrappin`；SHA-256 `2a2bd8fb1c6462c11baff0bc7e42a7a7d1b02650ab5a1b9a3ac5acc2b718741f`
- 隧道版：`WrapPin-Tunnel-1.0.17-build55-unsigned.ipa`；Bundle ID `com.suversal.wrappin.selfsigned`，扩展 `com.suversal.wrappin.selfsigned.tunnel`；SHA-256 `a0c91e2a215165cc86ff0689d246752db9b974453e6ca7adbd682fa662bdf94f`
- 最低系统：iOS 27.0；架构：arm64；均为未签名包。
- 本地化、后台定位生命周期、失败阶段、坐标模式、路线恢复、隧道跳转、路线选择检查，Release Archive 以及 IPA 完整性、身份、版本和扩展有无检查均已通过。原生引擎没有改动，未重跑原生引擎测试。
- 维护者在实体 iPhone 上用本地测试包 Build 53 和 54 试用了收起与展开，未逐项记录测试项。Build 55 的功能代码与 Build 54 相同，本身没有装机。
- Build 53 和 54 是本地测试包，没有公开发布。

### 已知边界

- 辅助功能的超大字号下，卡片本身需要上下滚动，因此只能通过顶部横条收起，不支持滑动。
- 路线预览卡片不支持收起。
- 1.0.16 的已知边界不变：蜂窝网络下通过 Shadowrocket、Surge、Loon 建立设备连接仍不可靠，使用这三个应用时请连接 Wi-Fi。

## English

WrapPin 1.0.17 lets the selected-location card on the map collapse, leaving more of the map free for choosing a point, in response to [#29](https://github.com/suversal/WrapPin/issues/29). Both editions are built from one source tree and one version.

Swipe down on the card or tap the handle at its top to collapse it; swipe up or tap the handle again to expand it. WrapPin remembers the choice, and a new installation starts expanded. While collapsed, the card keeps the place, one line of address or coordinates, the favourite and clear buttons and the main button, and shows the simulation coordinate mode as a small menu that still switches it, immediately during an active simulation. The mode selector with its hint, **Copy coordinates**, the route preview buttons and the routine status line are hidden until the card is expanded. Pairing, connection, failure and restore messages and **Stop & Restore** always stay visible. With Reduce Motion on, collapsing and expanding use a short fade only.

The unsigned packages require iOS 27.0 or later. `WrapPin-Standard-1.0.17-build55-unsigned.ipa` has SHA-256 `2a2bd8fb1c6462c11baff0bc7e42a7a7d1b02650ab5a1b9a3ac5acc2b718741f`; `WrapPin-Tunnel-1.0.17-build55-unsigned.ipa` has SHA-256 `a0c91e2a215165cc86ff0689d246752db9b974453e6ca7adbd682fa662bdf94f`. They passed the source checks and archive, integrity, identity, version and extension checks; native engine tests were not rerun because the engine is unchanged. The maintainer tried collapsing and expanding on a physical iPhone with local test Builds 53 and 54, without recording individual cases; Build 55 has the same feature code as Build 54 and has not itself been installed on a device. Builds 53 and 54 were local test builds and were not published.

At accessibility text sizes the card scrolls, so it collapses through the handle only. The route preview card cannot be collapsed. The known limitations of 1.0.16 are unchanged: on mobile data, the device connection through Shadowrocket, Surge or Loon is unreliable, so use Wi-Fi with these apps.
