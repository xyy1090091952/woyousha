# iOS 真机运行

## 前置条件

使用 macOS 和 Xcode，手机已信任电脑、开启开发者模式并解锁。Xcode 中已有可用的开发签名和描述文件；启动脚本不修改账号、证书或信任设置。

## ios-device

- 动作定义见 [run.json](run.json)，执行 [run-ios-device.sh](scripts/run-ios-device.sh)。
- 默认设备为 `OGS17`。更换手机时可通过 `WOYOUSHA_DEVICE` 环境变量指定设备名或标识。
- 脚本执行 Debug 编译、更新安装、前台启动和进程检查。更新安装保留已有应用数据，不卸载应用。
- 构建缓存和日志保存在系统临时目录，不进入 Git。
- 已验证本项目产物安装到连接的 iPhone 并前台启动，进程保持运行。相机快门、焦点和实际照片回传仍需人工真机交互；启动成功不代表拍照流程已完成实测。
- 若 Agent 终端的直接签名报 `errSecInternalComponent`，不要修改证书或绕过签名。已验证可让 Xcode 自身对当前工程执行 Run：选择 `woyousha` scheme 和 `OGS17` 运行目标。Xcode 的原生脚本接口也支持该动作。
- 调试附加提示 `Device needs to be unlocked` 时，需要手机实际解锁并保持前台，不能仅依据“已连接”判断可调试。
