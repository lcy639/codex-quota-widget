# Codex 额度小窗

一个置顶的 Windows 桌面小窗，显示最近一次本机 Codex 会话记录中的五小时、每周额度和重置时间。

## 使用

1. 先在本机使用 Codex，生成包含额度信息的会话记录。
2. 双击 `launch.cmd` 启动。鼠标悬停可查看重置时间，拖动可改变位置。

也可从 PowerShell 启动，或用 `-CheckData` 查看本机是否有可解析的额度记录。

```powershell
powershell.exe -NoProfile -STA -File .\quota-widget.ps1
powershell.exe -NoProfile -File .\quota-widget.ps1 -CheckData
```

## 数据来源

每 20 秒读取 `%USERPROFILE%\.codex\sessions` 下的本机 JSONL 文件，从 `token_count` 事件里读取 `rate_limits`。小窗不读取登录密钥，也不发起网络请求。长时间空闲、在其他设备使用或额度已重置但本机还没收到新记录时，显示可能延迟。Codex 日志格式变化也可能影响读取。

项目独立维护，使用 Windows PowerShell 与 WPF。

## 许可证

[MIT](LICENSE)
