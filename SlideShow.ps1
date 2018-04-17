Add-Type -AssemblyName 'System.Windows.Forms'

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.ComponentModel;


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
    [DllImport("user32.dll", ExactSpelling = true)]
    public static extern int ReleaseDC(IntPtr hWnd, IntPtr hDC);

    [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
    public static extern IntPtr GetDC(IntPtr hWnd);

    [DllImport("user32.dll", ExactSpelling = true, SetLastError = true)]
    public static extern int UpdateLayeredWindow(IntPtr hwnd, IntPtr hdcDst, ref Point pptDst, ref Size psize, IntPtr hdcSrc, ref Point pptSrc, Int32 crKey, ref BLENDFUNCTION pblend, Int32 dwFlags);
}

public static class Gdi32
{
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
    [IntPtr] $screenDC = [User32]::GetDC([IntPtr]::Zero)
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


#Start-SlideShow -BitmapUrl 'http://big5kayakchallenge.com/wp-content/uploads/2017/12/simple-bmp-format-images-free-download-tint-photo-editor-free-latest-version-in-bmp-format-images-free-download.png'

