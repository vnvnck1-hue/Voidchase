# Composite the ImageGen repair ONLY into damaged base pixels. Never writes game assets.
Add-Type -AssemblyName System.Drawing
$reviewDir = $PSScriptRoot
$projectDir = Split-Path (Split-Path $reviewDir -Parent) -Parent
$original = [System.Drawing.Bitmap]::new((Join-Path $projectDir 'assets/void_defense_original/background/props/arch_left.png'))
$generated = [System.Drawing.Bitmap]::new((Join-Path $reviewDir 'arch_left_imagegen.png'))
$patch = [System.Drawing.Bitmap]::new($original.Width, $original.Height)
$graphics = [System.Drawing.Graphics]::FromImage($patch)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.DrawImage($generated, [System.Drawing.Rectangle]::new(0, 0, $patch.Width, $patch.Height))
$graphics.Dispose()
$result = $original.Clone([System.Drawing.Rectangle]::new(0, 0, $original.Width, $original.Height), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$mask = [System.Drawing.Drawing2D.GraphicsPath]::new()
$points = [System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(51, 207),
    [System.Drawing.PointF]::new(111, 230),
    [System.Drawing.PointF]::new(135, 250),
    [System.Drawing.PointF]::new(145, 251),
    [System.Drawing.PointF]::new(144, 227),
    [System.Drawing.PointF]::new(160, 216),
    [System.Drawing.PointF]::new(226, 198),
    [System.Drawing.PointF]::new(228, 287),
    [System.Drawing.PointF]::new(51, 287)
)
$mask.AddPolygon($points)
$topOfRepair = @{}
for ($x = 0; $x -lt $original.Width; $x++) {
    for ($y = 190; $y -lt $original.Height; $y++) {
        if ($mask.IsVisible([single]$x, [single]$y)) { $topOfRepair[$x] = $y; break }
    }
}
$changed = 0
for ($y = 0; $y -lt $original.Height; $y++) {
    for ($x = 0; $x -lt $original.Width; $x++) {
        $old = $original.GetPixel($x, $y)
        if ($old.A -eq 0 -or -not $mask.IsVisible([single]$x, [single]$y)) { continue }
        # Retain the original moss, original perimeter alpha, and all unaffected pixels.
        if ($old.B -le $old.G + 10 -or $old.B -le $old.R + 5) { continue }
        $sampleX = [Math]::Min(210, [Math]::Max(60, $x))
        # Sample inside the generated face, avoiding its slightly displaced edge line.
        $sampleY = [Math]::Min(265, [Math]::Max($y, $topOfRepair[$x] + 8))
        $color = $patch.GetPixel($sampleX, $sampleY)
        if ($color.A -lt 180) { continue }
        $result.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($old.A, $color.R, $color.G, $color.B))
        $changed++
    }
}
$result.Save((Join-Path $reviewDir 'arch_left_cleaned.png'), [System.Drawing.Imaging.ImageFormat]::Png)

$comparison = [System.Drawing.Bitmap]::new(1060, 1330)
$graphics = [System.Drawing.Graphics]::FromImage($comparison)
$graphics.Clear([System.Drawing.Color]::FromArgb(38, 34, 49))
$font = [System.Drawing.Font]::new('Malgun Gothic', 17)
$smallFont = [System.Drawing.Font]::new('Malgun Gothic', 12)
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(226, 220, 239))
$graphics.DrawString('원본', $font, $brush, 130, 18)
$graphics.DrawString('하단 가공 흔적 정리', $font, $brush, 625, 18)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$graphics.DrawImage($original, [System.Drawing.Rectangle]::new(45, 70, 460, 574))
$graphics.DrawImage($result, [System.Drawing.Rectangle]::new(555, 70, 460, 574))
$graphics.DrawString('문제 부위 확대', $smallFont, $brush, 45, 686)
$sourceRect = [System.Drawing.Rectangle]::new(45, 192, 185, 95)
$graphics.DrawImage($original, [System.Drawing.Rectangle]::new(45, 730, 460, 236), $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
$graphics.DrawImage($result, [System.Drawing.Rectangle]::new(555, 730, 460, 236), $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
$graphics.DrawString('실제 리소스 크기 (230 × 287)', $smallFont, $brush, 45, 990)
$graphics.DrawImage($original, [System.Drawing.Rectangle]::new(160, 1020, 230, 287))
$graphics.DrawImage($result, [System.Drawing.Rectangle]::new(670, 1020, 230, 287))
$comparison.Save((Join-Path $reviewDir 'comparison.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$alphaChanges = 0
$outsideChanges = 0
for ($y = 0; $y -lt $original.Height; $y++) {
    for ($x = 0; $x -lt $original.Width; $x++) {
        $old = $original.GetPixel($x, $y)
        $new = $result.GetPixel($x, $y)
        if ($old.A -ne $new.A) { $alphaChanges++ }
        if ($y -lt 198 -and $old.ToArgb() -ne $new.ToArgb()) { $outsideChanges++ }
    }
}
Write-Output "Changed base pixels: $changed; alpha changes: $alphaChanges; changes above repair: $outsideChanges"
$graphics.Dispose()
$font.Dispose()
$smallFont.Dispose()
$brush.Dispose()
$mask.Dispose()
$comparison.Dispose()
$result.Dispose()
$patch.Dispose()
$generated.Dispose()
$original.Dispose()
