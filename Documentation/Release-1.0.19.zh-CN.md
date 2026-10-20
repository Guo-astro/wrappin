# WrapPin 1.0.19（Build 63）

[English](Release-1.0.19.md)

## 主要变化

本版新增快捷指令支持、四个隧道跳转应用和坐标模式记忆。

- **快捷指令**：安装后，“模拟收藏地点”和“停止并恢复真实位置”两个操作会自动出现在“快捷指令”App、Spotlight 和 Siri 中，也可用于自动化。两者都会打开 WrapPin；开始模拟时不等待连接完成，停止时等待设备确认，未确认清除时如实报告失败。设置 → 快捷指令提供说明，并可直接跳到“快捷指令”App。
- **更多隧道跳转应用**：新增 Stash、Egern、Quantumult X 和 sing-box。Stash、Egern 会被请求启动隧道；Quantumult X 和 sing-box 只打开应用，需手动开启隧道。WrapPin 不读取也不修改它们的配置。
- **坐标模式记忆**：收藏和历史地点沿用上次使用的坐标模式；距上次手动切换 100 公里内的新地点沿用那次选择。重置 WrapPin 时一并清除。

## 下载与安装

- 标准版：`WrapPin-Standard-1.0.19-build63-unsigned.ipa`，供 SideStore 或其他自签方式使用。
- 隧道版：`WrapPin-Tunnel-1.0.19-build63-unsigned.ipa`，需要带 Packet Tunnel 权限的签名证书及描述文件。
- 两个版本均为未签名 IPA，最低系统为 iOS 27.0。免费 Apple 账号和 SideStore 请使用标准版。

SHA-256：

- 标准版：`09cb9d4dc9754a5f41ebc55d6dd325356dc38006126ff9e3683d90330e5dcf10`
- 隧道版：`b47260db83b7bcbbe1b67554856209ea1984b0147803e74b766d0572b284db76`

两个包均由 commit `81c70a4b8cfe33e412a90b22d9d06cdf5a594795` 使用 Xcode 27.0（`27A266a`）构建。之后的发布文档改动不影响打包源码。发布地址：[v1.0.19](https://github.com/suversal/WrapPin/releases/tag/v1.0.19)。

## 验证与边界

- 维护者已用功能代码相同的 1.0.18 Build 62 测试包在真机上验证可用，包括两个快捷指令，未逐项记录测试清单。Build 63 只改变版本号，本身尚未独立装机。
- 两个 scheme 的 Debug、Release 构建，8 个检查脚本及 Rust 10 项单元测试均通过；两个 IPA 的包标识、快捷指令元数据、扩展和 ZIP 完整性检查均通过。
- 快捷指令只在本机向“快捷指令”和 Siri 提供收藏名称与地点描述，不提供坐标，未新增统计事件。
- 存在待处理的中断记录、正在进行路线模拟，或尚未完成设置与配对时，快捷指令不会开始模拟；恢复仍由用户手动选择。
- 原有蜂窝网络限制同样适用于第三方隧道应用，建议使用 Wi-Fi。
