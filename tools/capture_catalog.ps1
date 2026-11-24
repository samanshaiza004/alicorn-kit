param(
    [string]$BinDir = 'out',
    [string]$OutDir = 'website/public/captures',
    [string]$Only = ''
)

# Captures genuine native windows for the component catalog. Each example runs
# through the real SDL_GPU host, then its window is captured with PrintWindow
# (PW_RENDERFULLCONTENT). No component is recreated in HTML: the PNGs are the
# native application output.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class AliKitCapture {
    private delegate bool EnumWindowProc(IntPtr hwnd, IntPtr data);
    [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowProc callback, IntPtr data);
    [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetClassName(IntPtr hwnd, StringBuilder name, int count);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hwnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hwnd, int command);
    [DllImport("user32.dll")] private static extern bool AttachThreadInput(uint attach, uint attachTo, bool value);
    [DllImport("kernel32.dll")] private static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extra);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    struct INPUT { public uint type; public InputUnion data; }

    [StructLayout(LayoutKind.Explicit, Size = 32)]
    struct InputUnion {
        [FieldOffset(0)] public KEYBDINPUT ki;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct KEYBDINPUT {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, INPUT[] inputs, int size);

    const uint INPUT_KEYBOARD = 1;
    const uint KEYEVENTF_KEYUP = 0x0002;
    const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    const uint MOUSEEVENTF_LEFTUP = 0x0004;

    public static uint Click(int x, int y) {
        SetCursorPos(x, y);
        mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, UIntPtr.Zero);
        mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, UIntPtr.Zero);
        return 0;
    }

    public static uint SendShortcut(ushort[] keys) {
        var inputs = new List<INPUT>();
        foreach (ushort key in keys) inputs.Add(KeyInput(key, 0));
        for (int i = keys.Length - 1; i >= 0; i -= 1) inputs.Add(KeyInput(keys[i], KEYEVENTF_KEYUP));
        var array = inputs.ToArray();
        return SendInput((uint)array.Length, array, Marshal.SizeOf(typeof(INPUT)));
    }

    static INPUT KeyInput(ushort vk, uint flags) {
        var input = new INPUT();
        input.type = INPUT_KEYBOARD;
        input.data.ki.wVk = vk;
        input.data.ki.dwFlags = flags;
        return input;
    }

    public static string ClassOf(IntPtr hwnd) {
        var sb = new StringBuilder(256); GetClassName(hwnd, sb, 256); return sb.ToString();
    }

    public static IntPtr[] WindowsForProcess(int processId) {
        var result = new List<IntPtr>();
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            uint pid; GetWindowThreadProcessId(hwnd, out pid);
            if (pid == processId) result.Add(hwnd);
            return true;
        }, IntPtr.Zero);
        return result.ToArray();
    }

    public static IntPtr FirstSdlWindow(int processId) {
        IntPtr found = IntPtr.Zero;
        EnumWindows(delegate(IntPtr hwnd, IntPtr data) {
            uint pid; GetWindowThreadProcessId(hwnd, out pid);
            if (pid != processId || ClassOf(hwnd) != "SDL_app" || !IsWindowVisible(hwnd)) return true;
            found = hwnd;
            return false;
        }, IntPtr.Zero);
        return found;
    }

    // SetForegroundWindow is cooperative; attach to the current foreground
    // thread so scripted runs are not defeated by a terminal holding activation.
    public static bool ForceForeground(IntPtr hwnd) {
        IntPtr foreground = GetForegroundWindow();
        uint foregroundPid;
        uint foregroundThread = foreground != IntPtr.Zero ? GetWindowThreadProcessId(foreground, out foregroundPid) : 0;
        uint currentThread = GetCurrentThreadId();
        bool attached = foregroundThread != 0 && foregroundThread != currentThread &&
            AttachThreadInput(foregroundThread, currentThread, true);
        ShowWindow(hwnd, 9);
        BringWindowToTop(hwnd);
        SetForegroundWindow(hwnd);
        if (attached) { AttachThreadInput(foregroundThread, currentThread, false); }
        return GetForegroundWindow() == hwnd;
    }

    public static int[] Rect(IntPtr hwnd) {
        RECT r; if (!GetWindowRect(hwnd, out r)) return new int[] { 0, 0, 0, 0 };
        return new int[] { r.Left, r.Top, r.Right - r.Left, r.Bottom - r.Top };
    }

    public static bool SavePng(IntPtr hwnd, string path) {
        int[] r = Rect(hwnd);
        if (r[2] <= 0 || r[3] <= 0) return false;
        using (var bmp = new System.Drawing.Bitmap(r[2], r[3]))
        using (var g = System.Drawing.Graphics.FromImage(bmp)) {
            IntPtr hdc = g.GetHdc();
            bool ok;
            try { ok = PrintWindow(hwnd, hdc, 2); }
            finally { g.ReleaseHdc(hdc); }
            if (!ok) return false;
            bmp.Save(path, System.Drawing.Imaging.ImageFormat.Png);
            return true;
        }
    }
}
'@

function Wait-Until([scriptblock]$predicate, [int]$timeoutMs = 8000) {
    $deadline = [DateTime]::UtcNow.AddMilliseconds($timeoutMs)
    do {
        if (& $predicate) { return $true }
        Start-Sleep -Milliseconds 50
    } while ([DateTime]::UtcNow -lt $deadline)
    return (& $predicate)
}

function Invoke-ControlByName($window, [string]$name) {
    try {
        $root = [System.Windows.Automation.AutomationElement]::FromHandle($window)
        $all = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants,
            [System.Windows.Automation.Condition]::TrueCondition)
        foreach ($element in $all) {
            if ($element.Current.Name -notlike "*$name*") { continue }
            try {
                $pattern = $element.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
                $pattern.Invoke()
                return $true
            } catch {}
            try {
                $toggle = $element.GetCurrentPattern([System.Windows.Automation.TogglePattern]::Pattern)
                $toggle.Toggle()
                return $true
            } catch {}
        }
    } catch {
        return $false
    }
    return $false
}

function Capture-Example {
    param(
        [string]$Name,
        [string]$Exe,
        [int]$Width = 0,
        [int]$Height = 0,
        [string]$ClickButton = '',
        [int]$ClickX = -1,
        [int]$ClickY = -1,
        [switch]$CtrlShiftP
    )
    $process = Start-Process -FilePath $Exe -WorkingDirectory (Split-Path -Parent $Exe) -PassThru
    try {
        $window = [IntPtr]::Zero
        $deadline = [DateTime]::UtcNow.AddMilliseconds(12000)
        do {
            $window = [AliKitCapture]::FirstSdlWindow($process.Id)
            if ($window -ne [IntPtr]::Zero) { break }
            Start-Sleep -Milliseconds 50
        } while ([DateTime]::UtcNow -lt $deadline)
        if ($window -eq [IntPtr]::Zero) {
            throw "$Name did not create an SDL_app window."
        }
        Start-Sleep -Milliseconds 1400
        [void][AliKitCapture]::ForceForeground($window)
        Start-Sleep -Milliseconds 250
        if ($CtrlShiftP) {
            [void][AliKitCapture]::SendShortcut([uint16[]](0x11, 0x10, 0x50)) # Ctrl, Shift, P
            Start-Sleep -Milliseconds 900
        } elseif ($ClickButton) {
            if (-not (Invoke-ControlByName $window $ClickButton)) {
                if ($ClickX -lt 0 -or $ClickY -lt 0) { throw "Could not invoke button '$ClickButton' in $Name." }
                $rect = [AliKitCapture]::Rect($window)
                [void][AliKitCapture]::Click($rect[0] + $ClickX, $rect[1] + $ClickY)
            }
            Start-Sleep -Milliseconds 900
        } else {
            Start-Sleep -Milliseconds 500
        }
        $path = Join-Path $OutDir "$Name.png"
        if (-not [AliKitCapture]::SavePng($window, $path)) {
            throw "PrintWindow capture failed for $Name."
        }
        Write-Host "captured $Name -> $path"
    } finally {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
        $process.WaitForExit()
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$OutDir = (Resolve-Path -LiteralPath $OutDir).Path
$BinDir = (Resolve-Path -LiteralPath $BinDir).Path
$components = @(
    @{ Name='command-palette'; Exe='command_palette_example.exe'; CtrlShiftP=$true },
    @{ Name='tree-view'; Exe='tree_view_example.exe' },
    @{ Name='icon-picker'; Exe='icon_picker_example.exe'; ClickButton='Insert icon'; ClickX=100; ClickY=106 },
    @{ Name='palette-parts'; Exe='palette_parts_example.exe' },
    @{ Name='radio-group'; Exe='radio_group_example.exe' },
    @{ Name='progress'; Exe='progress_example.exe' },
    @{ Name='segmented'; Exe='segmented_example.exe' },
    @{ Name='notices'; Exe='notices_example.exe' },
    @{ Name='sidebar'; Exe='sidebar_example.exe'; ClickButton='Collapse rail' },
    @{ Name='menu'; Exe='menu_example.exe' },
    @{ Name='table'; Exe='table_example.exe' },
    @{ Name='data-grid'; Exe='data_grid_example.exe' }
)
foreach ($component in $components) {
    if ($Only -ne '' -and $component.Name -ne $Only) { continue }
    $exe = Join-Path $BinDir $component.Exe
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
        throw "Missing example binary '$exe'. Run tools/test.ps1 or build the example first."
    }
    $clickButton = ''
    $clickX = -1
    $clickY = -1
    $ctrlShiftP = $false
    if ($component.ContainsKey('ClickButton')) { $clickButton = $component.ClickButton }
    if ($component.ContainsKey('ClickX')) { $clickX = $component.ClickX }
    if ($component.ContainsKey('ClickY')) { $clickY = $component.ClickY }
    if ($component.ContainsKey('CtrlShiftP')) { $ctrlShiftP = $component.CtrlShiftP }
    Capture-Example -Name $component.Name -Exe $exe `
        -ClickButton $clickButton -ClickX $clickX -ClickY $clickY `
        -CtrlShiftP:$ctrlShiftP
}

