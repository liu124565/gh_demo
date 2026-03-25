param(
    [string]$TitleHint = "",
    [string]$ExeHint = "",
    [string]$LaunchTarget = "",
    [string]$Username = "",
    [string]$Password = "",
    [int]$TimeoutSec = 25,
    [string]$LoginButtonHint = "Login|Log in|Sign in|Sign In|SignIn",
    [string]$Mode = "uia",
    [int]$TabCount = 1,
    [double]$StartDelaySec = 0,
    [double]$InputWaitSec = 4.0
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);
}
"@

function Get-ProcessNameFromElement {
    param([System.Windows.Automation.AutomationElement]$Element)
    try {
        $pid = $Element.Current.ProcessId
        if ($pid -le 0) { return "" }
        return (Get-Process -Id $pid -ErrorAction Stop).Name
    } catch {
        return ""
    }
}

function Find-MatchingWindow {
    param(
        [string]$TitleHint,
        [string]$ExeHint
    )
    $windowCond = New-Object System.Windows.Automation.PropertyCondition `
        ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), `
        ([System.Windows.Automation.ControlType]::Window)
    $windows = [System.Windows.Automation.AutomationElement]::RootElement.FindAll(
        [System.Windows.Automation.TreeScope]::Children,
        $windowCond
    )

    $best = $null
    $bestScore = 0
    foreach ($w in $windows) {
        $name = $w.Current.Name
        $score = 0
        if ($TitleHint -and $name -and $name -like "*$TitleHint*") { $score += 2 }
        if ($ExeHint) {
            $procName = Get-ProcessNameFromElement -Element $w
            if ($procName -and $procName -like "*$ExeHint*") { $score += 1 }
        }
        if ($score -gt $bestScore) {
            $bestScore = $score
            $best = $w
        }
    }
    return $best
}

function Escape-SendKeys {
    param([string]$Text)
    return ($Text -replace '([+^%~(){}\[\]])', '{$1}')
}

function Resolve-ExeHint {
    param(
        [string]$ExeHint,
        [string]$LaunchTarget
    )
    if (-not [string]::IsNullOrWhiteSpace($ExeHint)) {
        return $ExeHint
    }
    if ([string]::IsNullOrWhiteSpace($LaunchTarget)) {
        return ""
    }
    $lower = $LaunchTarget.ToLowerInvariant()
    if ($lower.EndsWith(".lnk")) {
        try {
            $shell = New-Object -ComObject WScript.Shell
            $shortcut = $shell.CreateShortcut($LaunchTarget)
            if ($shortcut -and $shortcut.TargetPath) {
                $target = [System.IO.Path]::GetFileNameWithoutExtension($shortcut.TargetPath)
                return $target
            }
        } catch {
            return ""
        }
    }
    if ($lower.EndsWith(".exe")) {
        try {
            return [System.IO.Path]::GetFileNameWithoutExtension($LaunchTarget)
        } catch {
            return ""
        }
    }
    return ""
}

function Send-ClipboardText {
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return }
    [System.Windows.Forms.Clipboard]::SetText($Text)
    Start-Sleep -Milliseconds 80
    [System.Windows.Forms.SendKeys]::SendWait("^v")
    Start-Sleep -Milliseconds 80
}

function Wait-ForInputReady {
    param(
        [System.Windows.Automation.AutomationElement]$Window,
        [double]$TimeoutSec
    )
    if (-not $Window -or $TimeoutSec -le 0) { return }
    $editCond = New-Object System.Windows.Automation.PropertyCondition `
        ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), `
        ([System.Windows.Automation.ControlType]::Edit)
    $comboCond = New-Object System.Windows.Automation.PropertyCondition `
        ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), `
        ([System.Windows.Automation.ControlType]::ComboBox)
    $inputCond = New-Object System.Windows.Automation.OrCondition($editCond, $comboCond)
    $end = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $end) {
        try {
            $inputs = $Window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $inputCond)
            if ($inputs -and $inputs.Count -gt 0) {
                return
            }
        } catch {
            # ignore and retry
        }
        Start-Sleep -Milliseconds 200
    }
}

function Set-ElementValue {
    param(
        [System.Windows.Automation.AutomationElement]$Element,
        [string]$Value
    )
    if (-not $Element) { return $false }
    try {
        $pattern = $Element.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern)
        if ($pattern) {
            $pattern.SetValue($Value)
            return $true
        }
    } catch {
        # fall back to SendKeys
    }
    try {
        $Element.SetFocus()
        [System.Windows.Forms.SendKeys]::SendWait("^a")
        [System.Windows.Forms.SendKeys]::SendWait((Escape-SendKeys -Text $Value))
        return $true
    } catch {
        return $false
    }
}

if (-not $TitleHint -and -not $ExeHint) {
    exit 2
}

$resolvedExeHint = Resolve-ExeHint -ExeHint $ExeHint -LaunchTarget $LaunchTarget

$endTime = (Get-Date).AddSeconds($TimeoutSec)
$window = $null
while ((Get-Date) -lt $endTime) {
    $window = Find-MatchingWindow -TitleHint $TitleHint -ExeHint $resolvedExeHint
    if ($window) { break }
    Start-Sleep -Milliseconds 300
}
if (-not $window) {
    exit 3
}

$hwnd = [IntPtr]$window.Current.NativeWindowHandle
if ($hwnd -ne [IntPtr]::Zero) {
    [Win32]::ShowWindowAsync($hwnd, 5) | Out-Null
    [Win32]::SetForegroundWindow($hwnd) | Out-Null
}
$null = $window.SetFocus()
Start-Sleep -Milliseconds 200

if ($StartDelaySec -gt 0) {
    Start-Sleep -Milliseconds ([int]($StartDelaySec * 1000))
}

if ($Mode -eq "clipboard_tab") {
    Wait-ForInputReady -Window $window -TimeoutSec $InputWaitSec
    if ($Username) {
        Send-ClipboardText -Text $Username
    }
    $tabs = [Math]::Max(1, $TabCount)
    if ($Password) {
        for ($i = 0; $i -lt $tabs; $i++) {
            [System.Windows.Forms.SendKeys]::SendWait("{TAB}")
            Start-Sleep -Milliseconds 80
        }
        Send-ClipboardText -Text $Password
    }
    exit 0
}

$editCond = New-Object System.Windows.Automation.PropertyCondition `
    ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), `
    ([System.Windows.Automation.ControlType]::Edit)
$comboCond = New-Object System.Windows.Automation.PropertyCondition `
    ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), `
    ([System.Windows.Automation.ControlType]::ComboBox)
$inputCond = New-Object System.Windows.Automation.OrCondition($editCond, $comboCond)

$inputs = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $inputCond)
$userEdit = $null
$passEdit = $null

foreach ($e in $inputs) {
    if (-not $e.Current.IsEnabled) { continue }
    $isPwd = [bool]$e.GetCurrentPropertyValue([System.Windows.Automation.AutomationElement]::IsPasswordProperty)
    $name = $e.Current.Name
    if (-not $isPwd -and $name -and $name -match "pass|密码") { $isPwd = $true }
    if ($isPwd -and -not $passEdit) {
        $passEdit = $e
        continue
    }
    if (-not $isPwd -and -not $userEdit) {
        $userEdit = $e
    }
}

if (-not $userEdit -and $inputs.Count -gt 0) {
    $userEdit = $inputs[0]
}
if (-not $passEdit -and $inputs.Count -ge 2) {
    $passEdit = $inputs[1]
}

if ($Username) {
    Set-ElementValue -Element $userEdit -Value $Username | Out-Null
    Start-Sleep -Milliseconds 120
}
if ($Password) {
    Set-ElementValue -Element $passEdit -Value $Password | Out-Null
    Start-Sleep -Milliseconds 120
}

if (-not $userEdit -and $Username) {
    [System.Windows.Forms.SendKeys]::SendWait((Escape-SendKeys -Text $Username))
    [System.Windows.Forms.SendKeys]::SendWait("{TAB}")
    Start-Sleep -Milliseconds 120
}
if (-not $passEdit -and $Password) {
    [System.Windows.Forms.SendKeys]::SendWait((Escape-SendKeys -Text $Password))
    Start-Sleep -Milliseconds 120
}

$btnCond = New-Object System.Windows.Automation.PropertyCondition `
    ([System.Windows.Automation.AutomationElement]::ControlTypeProperty), `
    ([System.Windows.Automation.ControlType]::Button)

$buttons = $window.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)
$loginButton = $null
foreach ($b in $buttons) {
    $name = $b.Current.Name
    if ($name -and $name -match $LoginButtonHint) {
        $loginButton = $b
        break
    }
}

if ($loginButton) {
    try {
        $invoke = $loginButton.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        if ($invoke) {
            $invoke.Invoke()
            exit 0
        }
    } catch {
        # fallback to enter key
    }
}

if ($passEdit) {
    try { $passEdit.SetFocus() } catch {}
}
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
exit 0
