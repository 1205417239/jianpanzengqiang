# KeyboardTools + Kayoko（第一版框架）

固定键盘工具栏：

**剪贴板｜全选｜粘贴｜撤销｜收起键盘**

剪贴板界面采用 Kayoko 风格：清除图片、清除剪贴板、剪贴板/收藏夹、来源 App、历史内容、收藏与删除。

## 说明

- 基于 KeyboardTools 的 inputAccessoryView 思路。
- 剪贴板历史与收藏采用 Kayoko 项目思路，并重新实现为单一 Tweak。
- 本版本针对 RootHide/arm64e Theos 构建框架，目标 iOS 16.5 SDK / iOS 17.0 deployment。
- 未保证在 iOS 17.2.1 上已经实机验证；这是第一版可编译框架，需要在设备上测试注入与键盘行为。
- 来源 App 图标使用 UIKit 私有 API `_applicationIconImageForBundleIdentifier:format:scale:`，不同系统版本可能需要调整。

## 开源许可

KeyboardTools 原项目：CrazyMind90。
Kayoko 原项目：kissalexandra/Kayoko，原仓库为 GPL-3.0。若基于 Kayoko 原代码继续发布，请遵守其 GPL-3.0 条款。本仓库中的 Kayoko 相关功能按 GPL-3.0 兼容方式提供。
