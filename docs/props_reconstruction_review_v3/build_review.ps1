# Review artifacts only. No writes to assets/, scenes/, scripts/ or build/.
Add-Type -AssemblyName System.Drawing
if (-not ('PropReviewBounds' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class PropReviewBounds {
    public static Rectangle Of(Bitmap image) {
        var data = image.LockBits(new Rectangle(0,0,image.Width,image.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            int stride = Math.Abs(data.Stride);
            byte[] bytes = new byte[stride * image.Height];
            Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
            int left=image.Width, top=image.Height, right=-1, bottom=-1;
            for (int y=0; y<image.Height; y++) for (int x=0; x<image.Width; x++) {
                if (bytes[y*stride+x*4+3] <= 8) continue;
                left=Math.Min(left,x); top=Math.Min(top,y); right=Math.Max(right,x); bottom=Math.Max(bottom,y);
            }
            if (right<left) return new Rectangle(0,0,image.Width,image.Height);
            left=Math.Max(0,left-2); top=Math.Max(0,top-2);
            right=Math.Min(image.Width-1,right+2); bottom=Math.Min(image.Height-1,bottom+2);
            return Rectangle.FromLTRB(left,top,right+1,bottom+1);
        } finally { image.UnlockBits(data); }
    }
}
'@ -ReferencedAssemblies @('System.Drawing.Common','System.Drawing.Primitives','System.Runtime.InteropServices')
}
$reviewDir = $PSScriptRoot
$projectDir = Split-Path (Split-Path $reviewDir -Parent) -Parent
$assembly = Get-Content -LiteralPath (Join-Path $projectDir 'docs/void_defense_original/assembly.json') -Raw | ConvertFrom-Json
$layers = @($assembly.layers | Where-Object { $_.path -match '/props/' })
$font = [System.Drawing.Font]::new('Malgun Gothic', 13)
$smallFont = [System.Drawing.Font]::new('Malgun Gothic', 11)
$brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(225,218,239))
$faintBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(175,166,194))
$cardBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(47,41,61))
$metadata = @()
$previousStatus = @{}
$manifestPath = Join-Path $reviewDir 'manifest.json'
if (Test-Path -LiteralPath $manifestPath) {
    foreach ($entry in (Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json)) {
        $previousStatus[$entry.name] = $entry.status
    }
}

function Draw-Fit($graphics, $bitmap, [System.Drawing.Rectangle]$box) {
    $bounds = [PropReviewBounds]::Of($bitmap)
    $scale = [Math]::Min($box.Width / $bounds.Width, $box.Height / $bounds.Height)
    $width = [Math]::Max(1, [int][Math]::Round($bounds.Width * $scale))
    $height = [Math]::Max(1, [int][Math]::Round($bounds.Height * $scale))
    $dest = [System.Drawing.Rectangle]::new($box.X + [int](($box.Width-$width)/2), $box.Y + [int](($box.Height-$height)/2), $width, $height)
    $graphics.DrawImage($bitmap, $dest, $bounds, [System.Drawing.GraphicsUnit]::Pixel)
}

foreach ($layer in $layers) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($layer.path)
    $sourcePath = Join-Path $reviewDir "raw/$name.png"
    if (-not (Test-Path -LiteralPath $sourcePath)) { throw "Missing restoration: $name" }
    $raw = [System.Drawing.Bitmap]::new($sourcePath)
    $width = [int]$layer.size_px[0]
    $height = [int]$layer.size_px[1]
    $gameSize = [System.Drawing.Bitmap]::new($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($gameSize)
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    Draw-Fit $graphics $raw ([System.Drawing.Rectangle]::new(1,1,$width-2,$height-2))
    $gameSize.Save((Join-Path $reviewDir "game_size/$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $metadata += [PSCustomObject]@{name=$name; logical_size=@($width,$height); source_size=@($raw.Width,$raw.Height); alpha_corner=$raw.GetPixel(0,0).A; original_restored_pixels=$layer.restored_pixels; status=$(if($previousStatus.ContainsKey($name)){$previousStatus[$name]}elseif($name -eq 'arch_left'){'approved_reference'}else{'pending_approval'})}
    $graphics.Dispose()
    $gameSize.Dispose()
    $raw.Dispose()
}

$groups = @(
    @{file='01_arches_columns'; title='아치·기둥 — 기존 구조의 가림 영역 복원'; names=@('arch_left','arch_high','arch_right_rear','arch_right_front','column_center')},
    @{file='02_large_stones'; title='큰 석재 — 누락된 면과 파손 구조 복원'; names=@('rock_back_left','rock_left_tilted','rock_left_block','rock_rear_moss')},
    @{file='03_small_stones'; title='작은 석재 — 면·두께·모서리 복원'; names=@('rock_column_foot','rock_right_hidden','rock_right_edge','chip_rear_slab')},
    @{file='04_chips_banner'; title='파편·깃발 — 기존 묘사 밀도를 유지한 보완'; names=@('chip_left','chip_center_left','chip_center_right','star_banner')}
)
foreach ($group in $groups) {
    $rows = [int][Math]::Ceiling($group.names.Count / 2.0)
    $sheet = [System.Drawing.Bitmap]::new(1200, 90 + $rows * 355)
    $graphics = [System.Drawing.Graphics]::FromImage($sheet)
    $graphics.Clear([System.Drawing.Color]::FromArgb(35,30,46))
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.DrawString($group.title, $font, $brush, 24, 14)
    $stateLabel = if (@($metadata | Where-Object { $_.status -eq 'approved_and_applied' }).Count -eq 17) { '승인 후 게임 적용 완료' } else { '검토용, 게임 미적용' }
    $graphics.DrawString(('각 쌍의 왼쪽: 원본 / 오른쪽: 복원본 · ' + $stateLabel), $smallFont, $faintBrush, 24, 44)
    for ($i = 0; $i -lt $group.names.Count; $i++) {
        $name = $group.names[$i]
        $x = 18 + ($i % 2) * 590
        $y = 83 + [int][Math]::Floor($i / 2.0) * 355
        $graphics.FillRectangle($cardBrush, [System.Drawing.Rectangle]::new($x,$y,574,338))
        $label = $name
        if ($name -eq 'arch_left') { $label += ' (승인된 기준)' }
        $graphics.DrawString($label, $smallFont, $brush, $x+12, $y+8)
        $originalPath = Join-Path $projectDir "assets/void_defense_original/background/props/$name.png"
        $backupPath = Join-Path $reviewDir "originals_before_apply/$name.png"
        if (Test-Path -LiteralPath $backupPath) { $originalPath = $backupPath }
        $original = [System.Drawing.Bitmap]::new($originalPath)
        $restored = [System.Drawing.Bitmap]::new((Join-Path $reviewDir "raw/$name.png"))
        Draw-Fit $graphics $original ([System.Drawing.Rectangle]::new($x+14,$y+40,260,280))
        Draw-Fit $graphics $restored ([System.Drawing.Rectangle]::new($x+300,$y+40,260,280))
        $original.Dispose()
        $restored.Dispose()
    }
    $sheet.Save((Join-Path $reviewDir "comparisons/$($group.file).png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $sheet.Dispose()
    Write-Output "Saved $($group.file).png"
}
$metadata | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $reviewDir 'manifest.json') -Encoding utf8
$font.Dispose()
$smallFont.Dispose()
$brush.Dispose()
$faintBrush.Dispose()
$cardBrush.Dispose()
Write-Output "Prepared $($metadata.Count) review assets, game files unchanged."
