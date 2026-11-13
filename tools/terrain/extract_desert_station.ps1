# Native-pixel extraction only. No painting, generative fill, color adjustment or resizing.
param([string]$Source = 'docs/background_concepts_v1/battle_desert_station_v3.png')
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$sourcePath = Join-Path $projectRoot $Source
$assetDir = Join-Path $projectRoot 'assets/void_defense_desert/terrain'
$reviewDir = Join-Path $projectRoot 'docs/desert_station_tiles'
[System.IO.Directory]::CreateDirectory($assetDir) | Out-Null
[System.IO.Directory]::CreateDirectory($reviewDir) | Out-Null
$image = [System.Drawing.Bitmap]::new($sourcePath)
# Locate the actual ink stroke centers, rather than using rounded visual picks.
# Only polygon/UV coordinates change; sampled image colors are never modified.
function Find-InkLine($a,$b) {
    $dx=$b[0]-$a[0];$dy=$b[1]-$a[1];$length=[Math]::Sqrt($dx*$dx+$dy*$dy)
    $nx=-$dy/$length;$ny=$dx/$length
    $measurements=@()
    for($step=2;$step -le 18;$step++) {
        $t=$step/20.0;$lumas=@();$distances=@()
        for($k=-16;$k -le 16;$k++) {
            $offset=$k/4.0
            $sx=[int][Math]::Floor($a[0]+$dx*$t+$nx*$offset)
            $sy=[int][Math]::Floor($a[1]+$dy*$t+$ny*$offset)
            $p=$image.GetPixel($sx,$sy)
            $lumas+=0.2126*$p.R+0.7152*$p.G+0.0722*$p.B
            $distances+=$offset
        }
        $background=($lumas | Measure-Object -Maximum).Maximum
        $total=0.0;$weighted=0.0
        for($k=0;$k -lt $lumas.Count;$k++) {
            $weight=[Math]::Pow([Math]::Max(0.0,$background-12.0-$lumas[$k]),2)
            $weighted+=$distances[$k]*$weight;$total+=$weight
        }
        if($total -gt 0.0){$measurements+=,@($t,($weighted/$total))}
    }
    $meanT=($measurements | ForEach-Object {$_[0]} | Measure-Object -Average).Average
    $meanO=($measurements | ForEach-Object {$_[1]} | Measure-Object -Average).Average
    $num=0.0;$den=0.0
    foreach($m in $measurements){$num+=($m[0]-$meanT)*($m[1]-$meanO);$den+=($m[0]-$meanT)*($m[0]-$meanT)}
    $slope=$num/$den;$intercept=$meanO-$slope*$meanT
    return @{a=@(($a[0]+$nx*$intercept),($a[1]+$ny*$intercept));d=@(($dx+$nx*$slope),($dy+$ny*$slope))}
}
function Intersect-Lines($first,$second) {
    $ax=$second.a[0]-$first.a[0];$ay=$second.a[1]-$first.a[1]
    $cross=$first.d[0]*$second.d[1]-$first.d[1]*$second.d[0]
    $t=($ax*$second.d[1]-$ay*$second.d[0])/$cross
    return ,@([Math]::Round($first.a[0]+$first.d[0]*$t,4),[Math]::Round($first.a[1]+$first.d[1]*$t,4))
}
$patches = @(
    @{name='top_01'; points=@(@(738,92),@(819,132),@(738,171),@(658,131))},
    @{name='top_02'; points=@(@(658,131),@(738,171),@(657,211),@(577,172))},
    @{name='top_03'; points=@(@(819,132),@(899,171),@(818,211),@(738,171))},
    @{name='top_04'; points=@(@(738,171),@(818,211),@(738,251),@(657,211))},
    @{name='top_05'; points=@(@(577,172),@(657,211),@(577,252),@(497,212))},
    @{name='top_06'; points=@(@(497,212),@(577,252),@(497,293),@(416,253))},
    @{name='top_07'; points=@(@(416,253),@(497,293),@(416,333),@(335,293))},
    @{name='top_08'; points=@(@(335,293),@(416,333),@(335,374),@(254,334))},
    @{name='side_left'; points=@(@(85,419),@(167,460),@(167,526),@(85,485))},
    @{name='side_right'; points=@(@(1298,621),@(1380,579),@(1380,644),@(1298,686))}
)
$slotWidth=192; $slotHeight=144; $columns=4
$atlas = [System.Drawing.Bitmap]::new($columns*$slotWidth,432,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$atlasGraphics = [System.Drawing.Graphics]::FromImage($atlas)
$atlasGraphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$guide = [System.Drawing.Bitmap]::new($sourcePath)
$guideGraphics = [System.Drawing.Graphics]::FromImage($guide)
$guidePen = [System.Drawing.Pen]::new([System.Drawing.Color]::Cyan,2)
$font = [System.Drawing.Font]::new('Consolas',12)
$manifest = [ordered]@{source=$Source; source_size=@($image.Width,$image.Height); atlas='desert-station-atlas.png'; atlas_size=@($atlas.Width,$atlas.Height); tile_size=@(166.4,83.2); face_height=66.56; patches=@()}
$checked=0; $different=0
for($i=0;$i -lt $patches.Count;$i++) {
    $patch=$patches[$i]
    if($patch.name.StartsWith('top_')) {
        $lines=@()
        for($edge=0;$edge -lt 4;$edge++){$lines+=Find-InkLine $patch.points[$edge] $patch.points[(($edge+1)%4)]}
        $fitted=@()
        for($edge=0;$edge -lt 4;$edge++){$point=Intersect-Lines $lines[(($edge+3)%4)] $lines[$edge];$fitted+=,$point}
        $patch.points=$fitted
    }
    $xs=@($patch.points | ForEach-Object {$_[0]}); $ys=@($patch.points | ForEach-Object {$_[1]})
    $x0=[int][Math]::Floor(($xs | Measure-Object -Minimum).Minimum)-2
    $y0=[int][Math]::Floor(($ys | Measure-Object -Minimum).Minimum)-2
    $width=[int][Math]::Ceiling(($xs | Measure-Object -Maximum).Maximum)-$x0+3
    $height=[int][Math]::Ceiling(($ys | Measure-Object -Maximum).Maximum)-$y0+3
    $rect=[System.Drawing.Rectangle]::new($x0,$y0,$width,$height)
    $raw=$image.Clone($rect,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $cut=[System.Drawing.Bitmap]::new($width,$height,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $polygon=[System.Drawing.Drawing2D.GraphicsPath]::new()
    $local=[System.Drawing.PointF[]]@($patch.points | ForEach-Object {[System.Drawing.PointF]::new($_[0]-$x0,$_[1]-$y0)})
    $polygon.AddPolygon($local)
    for($y=0;$y -lt $height;$y++) {
        for($x=0;$x -lt $width;$x++) {
            if($polygon.IsVisible([single]($x+0.5),[single]($y+0.5))) {
                $pixel=$raw.GetPixel($x,$y)
                $cut.SetPixel($x,$y,$pixel)
                $checked++
                if($cut.GetPixel($x,$y).ToArgb() -ne $image.GetPixel($x0+$x,$y0+$y).ToArgb()) {$different++}
            }
        }
    }
    $cut.Save((Join-Path $assetDir ($patch.name+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
    # Atlas stores the unmasked native rectangle, including two pixels of source bleed.
    # GPU polygons provide the silhouette; no UV inset or alpha fringe can crop the drawing.
    $ax=($i % $columns)*$slotWidth+4; $ay=[int][Math]::Floor($i/$columns)*$slotHeight+4
    $atlasGraphics.DrawImageUnscaled($raw,$ax,$ay)
    $atlasPoints=@($patch.points | ForEach-Object {,@(($_[0]-$x0+$ax),($_[1]-$y0+$ay))})
    $manifest.patches += [ordered]@{name=$patch.name; source_points=$patch.points; source_rect=@($x0,$y0,$width,$height); atlas_points=$atlasPoints; atlas_rect=@($ax,$ay,$width,$height); native_file=($patch.name+'.png')}
    $globalPoints=[System.Drawing.PointF[]]@($patch.points | ForEach-Object {[System.Drawing.PointF]::new($_[0],$_[1])})
    $guideGraphics.DrawPolygon($guidePen,$globalPoints)
    $guideGraphics.DrawString($patch.name,$font,[System.Drawing.Brushes]::Cyan,$x0,$y0-17)
    $polygon.Dispose();$raw.Dispose();$cut.Dispose()
}
$atlas.Save((Join-Path $assetDir 'desert-station-atlas.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$manifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $assetDir 'desert-station.json') -Encoding utf8
$guide.Save((Join-Path $reviewDir 'source_patches.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$report=[ordered]@{source_sha256=(Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash; method='Native source RGBA copy; alpha mask only outside face; no resizing, recoloring, repainting or generation'; compared_native_pixels=$checked; different_native_pixels=$different; runtime_note='Native crop PNGs are pixel-identical inside the masks. Runtime uses those native atlas pixels as polygon UVs; existing game projection and camera scale cause normal texture filtering.'}
$report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $reviewDir 'pixel_check.json') -Encoding utf8
$atlasGraphics.Dispose();$atlas.Dispose();$guideGraphics.Dispose();$guidePen.Dispose();$font.Dispose();$guide.Dispose();$image.Dispose()
if($different -ne 0){throw "Native pixels changed: $different"}
Write-Output ("Extracted {0} native patches; {1} pixels checked; differences: {2}" -f $patches.Count,$checked,$different)
