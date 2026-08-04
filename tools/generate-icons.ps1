[CmdletBinding()]
param(
    [string]$OutputDirectory,
    [string]$PreviewDirectory
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) "assets"
}

function New-RoundedRectanglePath {
    param(
        [System.Drawing.RectangleF]$Bounds,
        [float]$Radius
    )

    $diameter = $Radius * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc($Bounds.Left, $Bounds.Top, $diameter, $diameter, 180, 90)
    $path.AddArc($Bounds.Right - $diameter, $Bounds.Top, $diameter, $diameter, 270, 90)
    $path.AddArc($Bounds.Right - $diameter, $Bounds.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($Bounds.Left, $Bounds.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function New-IconBitmap {
    param(
        [int]$Size,
        [ValidateSet("terminal", "reasonix")]
        [string]$Kind
    )

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $inset = [Math]::Max(1.0, $Size * 0.055)
    $bounds = [System.Drawing.RectangleF]::new(
        [single]$inset,
        [single]$inset,
        [single]($Size - (2 * $inset)),
        [single]($Size - (2 * $inset))
    )
    $radius = $Size * 0.20
    $tile = New-RoundedRectanglePath -Bounds $bounds -Radius $radius

    if ($Kind -eq "terminal") {
        $background = [System.Drawing.Color]::FromArgb(255, 30, 37, 49)
        $border = [System.Drawing.Color]::FromArgb(255, 74, 94, 117)
        $accent = [System.Drawing.Color]::FromArgb(255, 65, 213, 255)

        $brush = New-Object System.Drawing.SolidBrush($background)
        $graphics.FillPath($brush, $tile)
        $brush.Dispose()

        $borderPen = New-Object System.Drawing.Pen($border, [Math]::Max(1.0, $Size * 0.045))
        $graphics.DrawPath($borderPen, $tile)
        $borderPen.Dispose()

        $stroke = [Math]::Max(1.6, $Size * 0.105)
        $promptPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, $stroke)
        $promptPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $promptPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $promptPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        [System.Drawing.PointF[]]$points = @(
            ([System.Drawing.PointF]::new([single]($Size * 0.27), [single]($Size * 0.34))),
            ([System.Drawing.PointF]::new([single]($Size * 0.43), [single]($Size * 0.50))),
            ([System.Drawing.PointF]::new([single]($Size * 0.27), [single]($Size * 0.66)))
        )
        $graphics.DrawLines($promptPen, $points)
        $promptPen.Dispose()

        $cursorPen = New-Object System.Drawing.Pen($accent, $stroke)
        $cursorPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $cursorPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $graphics.DrawLine($cursorPen, $Size * 0.51, $Size * 0.66, $Size * 0.72, $Size * 0.66)
        $cursorPen.Dispose()
    } else {
        $background = [System.Drawing.Color]::FromArgb(255, 78, 70, 210)
        $border = [System.Drawing.Color]::FromArgb(255, 139, 140, 255)
        $node = [System.Drawing.Color]::FromArgb(255, 88, 221, 255)

        $brush = New-Object System.Drawing.SolidBrush($background)
        $graphics.FillPath($brush, $tile)
        $brush.Dispose()

        $borderPen = New-Object System.Drawing.Pen($border, [Math]::Max(1.0, $Size * 0.045))
        $graphics.DrawPath($borderPen, $tile)
        $borderPen.Dispose()

        $stroke = [Math]::Max(1.6, $Size * 0.09)
        $rPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, $stroke)
        $rPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $rPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $rPen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
        $graphics.DrawLine($rPen, $Size * 0.31, $Size * 0.73, $Size * 0.31, $Size * 0.27)

        $loop = New-Object System.Drawing.Drawing2D.GraphicsPath
        $loop.StartFigure()
        $loop.AddBezier($Size * 0.31, $Size * 0.28, $Size * 0.68, $Size * 0.22, $Size * 0.72, $Size * 0.49, $Size * 0.33, $Size * 0.50)
        $graphics.DrawPath($rPen, $loop)
        $loop.Dispose()
        $graphics.DrawLine($rPen, $Size * 0.47, $Size * 0.50, $Size * 0.70, $Size * 0.74)
        $rPen.Dispose()

        $nodeBrush = New-Object System.Drawing.SolidBrush($node)
        $nodeSize = [Math]::Max(2.0, $Size * 0.13)
        [System.Drawing.PointF[]]$nodePoints = @(
            ([System.Drawing.PointF]::new([single]($Size * 0.31), [single]($Size * 0.27))),
            ([System.Drawing.PointF]::new([single]($Size * 0.67), [single]($Size * 0.35))),
            ([System.Drawing.PointF]::new([single]($Size * 0.70), [single]($Size * 0.74)))
        )
        foreach ($point in $nodePoints) {
            $graphics.FillEllipse($nodeBrush, $point.X - ($nodeSize / 2), $point.Y - ($nodeSize / 2), $nodeSize, $nodeSize)
        }
        $nodeBrush.Dispose()
    }

    $tile.Dispose()
    $graphics.Dispose()
    return $bitmap
}

function Write-MultiSizeIcon {
    param(
        [string]$Path,
        [string]$Kind,
        [int[]]$Sizes
    )

    $frames = @()
    foreach ($size in $Sizes) {
        $bitmap = New-IconBitmap -Size $size -Kind $Kind
        $stream = New-Object System.IO.MemoryStream
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        $frames += [pscustomobject]@{ Size = $size; Data = $stream.ToArray() }
        $stream.Dispose()

        if ($PreviewDirectory -and $size -eq 256) {
            New-Item -ItemType Directory -Path $PreviewDirectory -Force | Out-Null
            $bitmap.Save((Join-Path $PreviewDirectory "$Kind.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        }
        $bitmap.Dispose()
    }

    $file = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
    $writer = New-Object System.IO.BinaryWriter($file)
    $writer.Write([uint16]0)
    $writer.Write([uint16]1)
    $writer.Write([uint16]$frames.Count)

    $offset = 6 + (16 * $frames.Count)
    foreach ($frame in $frames) {
        $dimension = if ($frame.Size -ge 256) { 0 } else { $frame.Size }
        $writer.Write([byte]$dimension)
        $writer.Write([byte]$dimension)
        $writer.Write([byte]0)
        $writer.Write([byte]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]32)
        $writer.Write([uint32]$frame.Data.Length)
        $writer.Write([uint32]$offset)
        $offset += $frame.Data.Length
    }
    foreach ($frame in $frames) {
        $writer.Write([byte[]]$frame.Data)
    }
    $writer.Dispose()
    $file.Dispose()
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$sizes = @(16, 20, 24, 32, 40, 48, 64, 128, 256)
Write-MultiSizeIcon -Path (Join-Path $OutputDirectory "terminal.ico") -Kind "terminal" -Sizes $sizes
Write-MultiSizeIcon -Path (Join-Path $OutputDirectory "reasonix.ico") -Kind "reasonix" -Sizes $sizes

Write-Host "Generated terminal.ico and reasonix.ico in $OutputDirectory"
