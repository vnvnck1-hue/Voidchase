$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskDir = $PSScriptRoot
$keys = @('01_punk_rose','02_goth_silver')
$labels = @('펑크형','고딕형')
$rows = foreach ($key in $keys) {
    Get-Content -LiteralPath (Join-Path $taskDir "audit/$key.json") -Raw -Encoding UTF8 | ConvertFrom-Json
}
# The contact sheet is the only scaled image. Delivered PNGs remain unchanged.
$preview = [Drawing.Bitmap]::new(1440,1080)
$g = [Drawing.Graphics]::FromImage($preview)
$g.Clear([Drawing.Color]::FromArgb(237,233,240))
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = [Drawing.Font]::new('Malgun Gothic',29,[Drawing.FontStyle]::Bold)
$format = [Drawing.StringFormat]::new()
$format.Alignment = [Drawing.StringAlignment]::Center
for ($i=0; $i -lt 2; $i++) {
    $im = [Drawing.Image]::FromFile((Join-Path $taskDir "png/$($keys[$i]).png"))
    $r = $rows[$i]
    $scale = 270.0 / ($r.chin - $r.crown)
    $x = $i*720 + 360 - $r.cx*$scale
    $y = 170 - $r.crown*$scale
    $g.DrawImage($im,[single]$x,[single]$y,[single]($im.Width*$scale),[single]($im.Height*$scale))
    $g.DrawString($labels[$i],$font,[Drawing.Brushes]::Black,[Drawing.RectangleF]::new(($i*720),980,720,70),$format)
    $im.Dispose()
}
$preview.Save((Join-Path $taskDir 'preview.png'),[Drawing.Imaging.ImageFormat]::Png)
$format.Dispose();$font.Dispose();$g.Dispose();$preview.Dispose()
$files = $keys | ForEach-Object { Join-Path $taskDir "png/$_.png" }
Compress-Archive -LiteralPath $files -DestinationPath (Join-Path $taskDir 'goth_redesign_v2_pngs.zip') -Force
