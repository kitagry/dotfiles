#!/bin/bash

MESSAGE="${1:-通知}"

notify_macos() {
  local msg="$1"
  osascript -e "display notification \"${msg}\" with title \"Claude Code\""
}

notify_wsl() {
  local msg="$1"
  powershell.exe -noprofile -command "
    Add-Type -AssemblyName System.Windows.Forms
    \$n = New-Object System.Windows.Forms.NotifyIcon
    \$n.Icon = [System.Drawing.SystemIcons]::Application
    \$n.BalloonTipTitle = 'Claude Code'
    \$n.BalloonTipText = '$msg'
    \$n.Visible = \$true
    \$n.ShowBalloonTip(3000)
    Start-Sleep 4
    \$n.Dispose()
  " &
}

notify_linux() {
  local msg="$1"
  if command -v notify-send &>/dev/null; then
    notify-send "Claude Code" "$msg"
  fi
}

if command -v osascript &>/dev/null; then
  notify_macos "$MESSAGE"
elif grep -qi microsoft /proc/version 2>/dev/null; then
  notify_wsl "$MESSAGE"
else
  notify_linux "$MESSAGE"
fi
