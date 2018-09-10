Add-Type -AssemblyName 'System.Windows.Forms'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.ComponentModel;


public enum TernaryRasterOperations : uint {
    /// <summary>dest = source</summary>
    SRCCOPY = 0x00CC0020,
    /// <summary>dest = source OR dest</summary>
    SRCPAINT = 0x00EE0086,
    /// <summary>dest = source AND dest</summary>
    SRCAND = 0x008800C6,
    /// <summary>dest = source XOR dest</summary>
    SRCINVERT = 0x00660046,
    /// <summary>dest = source AND (NOT dest)</summary>
    SRCERASE = 0x00440328,
    /// <summary>dest = (NOT source)</summary>
    NOTSRCCOPY = 0x00330008,
    /// <summary>dest = (NOT src) AND (NOT dest)</summary>
    NOTSRCERASE = 0x001100A6,
    /// <summary>dest = (source AND pattern)</summary>
    MERGECOPY = 0x00C000CA,
    /// <summary>dest = (NOT source) OR dest</summary>
    MERGEPAINT = 0x00BB0226,
    /// <summary>dest = pattern</summary>
    PATCOPY    = 0x00F00021,
    /// <summary>dest = DPSnoo</summary>
    PATPAINT = 0x00FB0A09,
    /// <summary>dest = pattern XOR dest</summary>
    PATINVERT = 0x005A0049,
    /// <summary>dest = (NOT dest)</summary>
    DSTINVERT = 0x00550009,
    /// <summary>dest = BLACK</summary>
    BLACKNESS = 0x00000042,
    /// <summary>dest = WHITE</summary>
    WHITENESS = 0x00FF0062,
    /// <summary>
    /// Capture window as seen on screen.  This includes layered windows 
    /// such as WPF windows with AllowsTransparency="true"
    /// </summary>
    CAPTUREBLT = 0x40000000
}

[StructLayout(LayoutKind.Sequential, Pack = 1)]
public struct BLENDFUNCTION
{
    public byte BlendOp;
    public byte BlendFlags;
    public byte SourceConstantAlpha;
    public byte AlphaFormat;
}

[StructLayout(LayoutKind.Sequential)]
public struct Point
{
    public Int32 x;
    public Int32 y;
}
[StructLayout(LayoutKind.Sequential)]
public struct Size
{
    public Int32 cx;
    public Int32 cy;
}

public static class User32
{
    [DllImport("user32.dll", SetLastError=true)]
    public static extern int SetClipboardData(int uFormat, IntPtr hMem);
    [DllImport("user32.dll")]
    public static extern bool EmptyClipboard();

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool CloseClipboard();

    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool OpenClipboard(IntPtr hWndNewOwner);

    [DllImport("user32.dll", ExactSpelling = true)]
    public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

    [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
    public static extern IntPtr GetDC(IntPtr hWnd);

    [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
    public static extern int UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref Point pptDst, ref Size psize, IntPtr hdcSrc, ref Point pptSrc, Int32 crKey, ref BLENDFUNCTION pblend, Int32 dwFlags);
}

public static class Gdi32
{
    [DllImport("gdi32.dll", EntryPoint = "BitBlt", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool BitBlt([In] IntPtr hdc, int nXDest, int nYDest, int nWidth, int nHeight, [In] IntPtr hdcSrc, int nXSrc, int nYSrc, TernaryRasterOperations dwRop);

    [DllImport("gdi32.dll", EntryPoint = "CreateCompatibleBitmap")]
    public static extern IntPtr CreateCompatibleBitmap([In] IntPtr hdc, int nWidth, int nHeight);
    [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
    public static extern IntPtr CreateCompatibleDC(IntPtr hDC);

    [DllImport("gdi32.dll", ExactSpelling = true)]
    public static extern IntPtr SelectObject(IntPtr hDC, IntPtr hObj);

    [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
    public static extern int DeleteDC(IntPtr hDC);

    [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
    public static extern int DeleteObject(IntPtr hObj);

    [DllImport("gdi32.dll", ExactSpelling = true, SetLastError = true)]
    public static extern IntPtr ExtCreateRegion(IntPtr lpXform, uint nCount, IntPtr rgnData);
}


public class FishForm : Form
{
    public FishForm()
    {
        //this.DubbelBuffered = true;
    }

    protected override CreateParams CreateParams
    {
        get
        {
            CreateParams cParms = base.CreateParams;
            cParms.ExStyle |= 0x00080000; // WS_EX_LAYERED
            return cParms;
        }
    }
    protected override void OnHandleCreated(EventArgs e)
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint, true);
        SetStyle(ControlStyles.UserPaint, true);
        UpdateStyles();
        base.OnHandleCreated(e);

    }

}

'@ -ReferencedAssemblies System.Windows.Forms




function SetBits([System.Drawing.Bitmap] $bitmap, [System.Windows.Forms.Form] $win)
{
    $srcLoc = New-Object Point
    $topLoc = New-Object Point
    $BlendFunc = New-Object BLENDFUNCTION
    $bitMapSize = New-Object Size


    [byte] $AC_SRC_OVER = 0;
    [Int32] $ULW_ALPHA = 2;
    [byte] $AC_SRC_ALPHA = 1;
    if (![System.Drawing.Bitmap]::IsCanonicalPixelFormat($bitmap.PixelFormat) -or ![System.Drawing.Bitmap]::IsAlphaPixelFormat($bitmap.PixelFormat))
    {
        throw [ApplicationException] 'The picture must be 32bit picture with alpha channel.'
    }

    [IntPtr] $oldBits = [IntPtr]::Zero
    [IntPtr] $screenDC = [IntPtr]::Zero
    [IntPtr] $hBitmap = [IntPtr]::Zero
    [IntPtr] $memDc = [Gdi32]::CreateCompatibleDC($screenDC)

    try
    {
        $topLoc.x = $win.Left
        $topLoc.y = $win.Top

        $bitMapSize.cx = $bitmap.Width
        $bitMapSize.cy = $bitmap.Height

        $srcLoc.x = 0
        $srcLoc.y = 0

        $hBitmap = $bitmap.GetHbitmap([System.Drawing.Color]::FromArgb(0));
        $oldBits = [Gdi32]::SelectObject($memDc, $hBitmap);

        $blendFunc.BlendOp = $AC_SRC_OVER;
        $blendFunc.SourceConstantAlpha = 255;
        $blendFunc.AlphaFormat = $AC_SRC_ALPHA;
        $blendFunc.BlendFlags = 0;

        [void][User32]::UpdateLayeredWindow($win.Handle, $screenDC, [ref] $topLoc, [ref] $bitMapSize, $memDc, [ref] $srcLoc, 0, [ref] $blendFunc, $ULW_ALPHA)
    }

    finally
    {
        if ($hBitmap -ne [IntPtr]::Zero)
        {
            [void][Gdi32]::SelectObject($memDc, $oldBits);
            [void][Gdi32]::DeleteObject($hBitmap);
        }
        [void][User32]::ReleaseDC([IntPtr]::Zero, $screenDC);
        [void][Gdi32]::DeleteDC($memDc);
    }
}


function Start-SlideShow
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $BitmapUrl
    )
    $request = [System.Net.WebRequest]::Create($BitmapUrl)
    $response = $request.GetResponse()
    [System.Drawing.Bitmap] $image = $response.GetResponseStream()
    
    $Form = New-Object FishForm
    #$Form.AutoSize = $true
    $Form.Width = $image.Width
    $Form.Height = $image.Height
    $Form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
    #$Form.Location = $srcLoc
    $Form.Left = -$image.Width
    $Form.Top = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height - $image.Height
    $Form.Text = ''
    
    
    $Form.TopMost = $true
    $Form.UseWaitCursor = $false
    $Form.Opacity = 100
    $Form.ShowInTaskbar = $false
    $Form.UseWaitCursor = $false
    
    $Form.Show()
    while($Form.Left -lt [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width)
    {
        SetBits $image $Form
        $Form.Left += 5
        Start-Sleep -Milliseconds 25
    }
    $Form.Close()
    
}




function Invoke-ScreenShot([int32]$ax, [int32]$ay, [int32]$bx, [int32]$by)
{
    [IntPtr] $hScreen = [User32]::GetDC([IntPtr]::Zero)
    [IntPtr] $hBitmap = [IntPtr]::Zero
    [IntPtr] $hDC = [Gdi32]::CreateCompatibleDC($hScreen)
    $hBitmap = [Gdi32]::CreateCompatibleBitmap($hScreen, [Math]::abs($bx-$ax), [Math]::abs($by-$ay))
    [IntPtr] $old_obj = [Gdi32]::SelectObject($hDC, $hBitmap)
    [void][Gdi32]::BitBlt($hDC, 0, 0, [Math]::abs($bx-$ax), [Math]::abs($by-$ay), $hScreen, $ax, $ay, 13369376)
 
    [void][User32]::OpenClipboard([IntPtr]::Zero)
    [void][User32]::EmptyClipboard()
    [void][User32]::SetClipboardData(2, $hBitmap)
    [void][User32]::CloseClipboard()
    [void][Gdi32]::SelectObject($hDC, $old_obj)
    [void][Gdi32]::DeleteDC($hDC)
    [void][User32]::ReleaseDC([IntPtr]::Zero, $hScreen)
    [void][Gdi32]::DeleteDC($hBitmap)
}

$dpi = 1
try{
    $dpi = $(Get-itemproperty -Path 'HKCU:\Control Panel\Desktop\WindowMetrics\' -Name AppliedDPI).applieddpi
    $dpi = $dpi / 100.0 * 1.042
}catch{}
$x = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Width * $dpi
$y = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height * $dpi

#Invoke-ScreenShot 0 0 $x $y
#Start-SlideShow -BitmapUrl 'https://bit.ly/2J4aBVD'



