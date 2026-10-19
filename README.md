# ABreak

macOS 菜单栏休息提醒（LookAway 的最小复刻），重点是**远程控制时自动免打扰**。

默认配置与作者的 LookAway 设置一致：每 45 分钟休息 20 秒，会议、视频播放、全屏应用时暂停，每 20 分钟坐姿提醒。

## 构建

```sh
scripts/test.sh                 # core unit tests
scripts/build-app.sh            # -> build/ABreak.app
scripts/build-app.sh --install  # copy to /Applications and launch
```

## 智能暂停来源

| 条件 | 检测方式 |
|---|---|
| 本机被远程控制 | `UURemoteServer` 的 TCP 已建立连接 ≥2、UDP socket ≥1、CPU ≥3% 或持有防显示器休眠断言；连续 2 次命中生效，20 秒无命中解除 |
| 用本机控制其他设备 | 前台应用 Bundle ID 为 `com.netease.uuremote` |
| 会议/通话 | CoreAudio 进程级麦克风占用、CoreMediaIO 摄像头占用 |
| 视频播放 | 任一进程持有 `PreventUserIdleDisplaySleep` 断言 |
| 全屏 / 指定应用 | 前台应用窗口铺满屏幕 / Bundle ID 命中列表 |

## 调试

```sh
build/ABreak.app/Contents/MacOS/ABreak --probe   # print raw detector signals every 2s
```

状态切换记录在 `~/Library/Logs/ABreak.log`。
