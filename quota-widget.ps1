param([switch]$CheckData, [switch]$CheckLayout)
$ErrorActionPreference = 'Stop'
$sessionRoot = Join-Path $env:USERPROFILE '.codex\sessions'
$script:lastQuota = $null
$script:lastTime = $null

function Read-Quota {
    $files = Get-ChildItem -LiteralPath $sessionRoot -Filter '*.jsonl' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 6
    foreach ($file in $files) {
        $stream = $null
        $reader = $null
        try {
            $stream = [IO.File]::Open($file.FullName, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete)
            $offset = [Math]::Max(0, $stream.Length - 524288)
            [void]$stream.Seek($offset, [IO.SeekOrigin]::Begin)
            $reader = [IO.StreamReader]::new($stream, [Text.Encoding]::UTF8)
            if ($offset -gt 0) { [void]$reader.ReadLine() }
            $lines = $reader.ReadToEnd() -split "`n"
            [array]::Reverse($lines)
        } catch { continue } finally {
            if ($reader) { $reader.Dispose() } elseif ($stream) { $stream.Dispose() }
        }
        foreach ($line in $lines) {
            if ($line -notmatch '"type"\s*:\s*"token_count"' -or $line -notmatch '"rate_limits"\s*:') { continue }
            try {
                $event = $line | ConvertFrom-Json
                $quota = $event.payload.rate_limits
                if (!$quota.primary -or !$quota.secondary) { continue }
                if ($quota.limit_id -and $quota.limit_id -ne 'codex') { continue }
                $time = if ($event.timestamp -is [DateTime]) { [DateTimeOffset]$event.timestamp } else { [DateTimeOffset]::Parse([string]$event.timestamp) }
                if (!$script:lastTime -or $time -gt $script:lastTime) {
                    $script:lastQuota = $quota
                    $script:lastTime = $time
                }
                break
            } catch { }
        }
    }
}

Read-Quota
if ($CheckData) {
    if (!$script:lastQuota) { throw '没有找到本机额度记录。' }
    [pscustomobject]@{
        FiveHourRemaining = [Math]::Max(0, 100 - $script:lastQuota.primary.used_percent)
        WeeklyRemaining = [Math]::Max(0, 100 - $script:lastQuota.secondary.used_percent)
        UpdatedAt = $script:lastTime.ToString('o')
    } | ConvertTo-Json
    exit
}

Add-Type -AssemblyName PresentationFramework
[xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Codex 额度" Width="304" Height="280" WindowStyle="None"
        ResizeMode="NoResize" AllowsTransparency="True" Background="Transparent"
        Topmost="False" ShowInTaskbar="True" WindowStartupLocation="Manual">
  <Border Background="#17212D" BorderBrush="#3B4B5B" BorderThickness="1" CornerRadius="14" Padding="18,12">
    <StackPanel>
      <DockPanel Margin="0,0,0,12">
        <Button x:Name="CloseButton" DockPanel.Dock="Right" Content="×" Width="25" Height="24" Background="Transparent" Foreground="#AAB8C8" BorderThickness="0" FontSize="19" ToolTip="关闭小窗"/>
        <ToggleButton x:Name="PinButton" DockPanel.Dock="Right" Width="27" Height="24" Margin="0,0,5,0" IsChecked="False" Cursor="Hand" AutomationProperties.Name="切换窗口置顶">
          <ToggleButton.Style>
            <Style TargetType="ToggleButton">
              <Setter Property="Background" Value="Transparent"/>
              <Setter Property="Foreground" Value="#8292A6"/>
              <Setter Property="ToolTip" Value="点击置顶"/>
              <Setter Property="Template">
                <Setter.Value>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border x:Name="PinBorder" Background="{TemplateBinding Background}" CornerRadius="5">
                      <Path x:Name="PinIcon" Data="M 8,2 L 16,2 L 16,4 L 14,5 L 14,10 L 18,13 L 18,15 L 13,15 L 12,22 L 11,15 L 6,15 L 6,13 L 10,10 L 10,5 L 8,4 Z" Fill="{TemplateBinding Foreground}" Width="12" Height="18" Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center" RenderTransformOrigin="0.5,0.5">
                        <Path.RenderTransform><RotateTransform Angle="-35"/></Path.RenderTransform>
                      </Path>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="PinBorder" Property="Background" Value="#344256"/></Trigger>
                      <Trigger Property="IsChecked" Value="True">

                        <Setter TargetName="PinIcon" Property="RenderTransform"><Setter.Value><RotateTransform Angle="0"/></Setter.Value></Setter>
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </Setter.Value>
              </Setter>
              <Style.Triggers>
                <Trigger Property="IsChecked" Value="True">

                  <Setter Property="ToolTip" Value="已置顶，点击取消"/>
                </Trigger>
              </Style.Triggers>
            </Style>
          </ToggleButton.Style>
        </ToggleButton>
        <TextBlock Text="Codex · 剩余额度" Foreground="#F1F5F9" FontSize="14" VerticalAlignment="Center"/>
      </DockPanel>
      <DockPanel><TextBlock Text="5 小时" Foreground="#CBD5E1"/><TextBlock x:Name="FiveText" Text="—" Foreground="#76E4C5" FontSize="18" HorizontalAlignment="Right"/></DockPanel>
      <ProgressBar x:Name="FiveBar" Height="5" Margin="0,4,0,5" Maximum="100" Foreground="#76E4C5" Background="#344256" BorderThickness="0"/>
      <TextBlock x:Name="FiveResetText" Text="下次重置：等待额度记录" Foreground="#AAB8C8" FontSize="11" Margin="0,0,0,12"/>
      <DockPanel><TextBlock Text="每周" Foreground="#CBD5E1"/><TextBlock x:Name="WeekText" Text="—" Foreground="#9EBBFF" FontSize="18" HorizontalAlignment="Right"/></DockPanel>
      <ProgressBar x:Name="WeekBar" Height="5" Margin="0,4,0,5" Maximum="100" Foreground="#9EBBFF" Background="#344256" BorderThickness="0"/>
      <TextBlock x:Name="WeekResetText" Text="下次重置：等待额度记录" Foreground="#AAB8C8" FontSize="11" Margin="0,0,0,12"/>
      <TextBlock x:Name="UpdateText" Foreground="#AAB8C8" FontSize="11"/>
      <TextBlock x:Name="NoteText" Text="每 20 秒读取本机记录 · 拖动可移动" Foreground="#8292A6" FontSize="10" Margin="0,4,0,0"/>
    </StackPanel>
  </Border>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $markup
$window = [Windows.Markup.XamlReader]::Load($reader)
$window.Left = [System.Windows.SystemParameters]::WorkArea.Right - $window.Width - 24
$window.Top = [System.Windows.SystemParameters]::WorkArea.Bottom - $window.Height - 24
$fiveText = $window.FindName('FiveText')
$weekText = $window.FindName('WeekText')
$fiveBar = $window.FindName('FiveBar')
$weekBar = $window.FindName('WeekBar')
$fiveResetText = $window.FindName('FiveResetText')
$weekResetText = $window.FindName('WeekResetText')
$updateText = $window.FindName('UpdateText')
$noteText = $window.FindName('NoteText')
$pinButton = $window.FindName('PinButton')
$pinButton.Add_Checked({ $window.Topmost = $true })
$pinButton.Add_Unchecked({ $window.Topmost = $false })
$window.FindName('CloseButton').Add_Click({ $window.Close() })
$window.Add_MouseLeftButtonDown({ if ($_.ChangedButton -eq 'Left') { $window.DragMove() } })

function Update-Display {
    try {
        Read-Quota
        if (!$script:lastQuota) { $updateText.Text = '等待本机额度记录'; return }
        $five = [Math]::Max(0, [Math]::Min(100, 100 - $script:lastQuota.primary.used_percent))
        $week = [Math]::Max(0, [Math]::Min(100, 100 - $script:lastQuota.secondary.used_percent))
        $fiveText.Text = "$five%"; $weekText.Text = "$week%"
        $fiveBar.Value = $five; $weekBar.Value = $week
        $zone = [TimeZoneInfo]::FindSystemTimeZoneById('China Standard Time')
        $localTime = [TimeZoneInfo]::ConvertTime($script:lastTime, $zone)
        $updateText.Text = '记录时间 ' + $localTime.ToString('MM-dd HH:mm') + ' · 北京时间'
        $age = [DateTimeOffset]::UtcNow - $script:lastTime
        $noteText.Text = if ($age.TotalMinutes -gt 10) { '显示上次记录 · 本机使用 Codex 后更新' } else { '每 20 秒读取本机记录 · 拖动可移动' }
        $reset5 = [DateTimeOffset]::FromUnixTimeSeconds([long]$script:lastQuota.primary.resets_at)
        $resetW = [DateTimeOffset]::FromUnixTimeSeconds([long]$script:lastQuota.secondary.resets_at)
        $fiveResetText.Text = '下次重置：' + [TimeZoneInfo]::ConvertTime($reset5, $zone).ToString('MM-dd HH:mm') + '（北京时间）'
        $weekResetText.Text = '下次重置：' + [TimeZoneInfo]::ConvertTime($resetW, $zone).ToString('MM-dd HH:mm') + '（北京时间）'
        $window.ToolTip = '5 小时重置：' + [TimeZoneInfo]::ConvertTime($reset5, $zone).ToString('MM-dd HH:mm') + "`n每周重置：" + [TimeZoneInfo]::ConvertTime($resetW, $zone).ToString('MM-dd HH:mm') + "`n数据来源：本机 Codex 会话记录。其他设备的消耗需本机获得新记录后显示。"
        if ([DateTimeOffset]::UtcNow -gt $reset5) { $fiveText.Text = "$five%*"; $noteText.Text = '* 重置时间已到，等待新额度记录' }
        if ([DateTimeOffset]::UtcNow -gt $resetW) { $weekText.Text = "$week%*"; $noteText.Text = '* 重置时间已到，等待新额度记录' }
    } catch { $noteText.Text = '暂时无法读取 · 将自动重试' }
}

Update-Display
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(20)
$timer.Add_Tick({ Update-Display })
$timer.Start()
$window.Add_Closed({ $timer.Stop() })
if ($CheckLayout) {
    if ($window.Topmost -or $pinButton.IsChecked) { throw '默认状态应不置顶' }
    $pinButton.IsChecked = $true
    if (!$window.Topmost) { throw '图钉开启置顶失败' }
    $pinButton.IsChecked = $false
    if ($window.Topmost) { throw '图钉取消置顶失败' }
    Write-Output 'Pin toggle OK'
}
if ($CheckLayout) { $timer.Stop(); if (!$fiveResetText.Text.StartsWith('下次重置：') -or !$weekResetText.Text.StartsWith('下次重置：') -or $noteText.Text -eq '暂时无法读取 · 将自动重试') { throw '重置时间显示检查失败' }; $window.Measure([Windows.Size]::new(304,280)); $window.Arrange([Windows.Rect]::new(0,0,304,280)); Write-Output $fiveResetText.Text; Write-Output $weekResetText.Text; Write-Output 'Layout OK'; exit }
[void]$window.ShowDialog()
