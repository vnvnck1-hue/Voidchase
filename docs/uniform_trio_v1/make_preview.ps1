$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskDir = $PSScriptRoot
$keys = @('01_energetic_leader','02_shy_bookworm','03_cool_rebel')
$labels = @('활발한 리더형','수줍은 문학소녀형','무심한 반항아형')
$rows = foreach ($key in $keys) {
    Get-Content -LiteralPath (Join-Path $taskDir "audit/$key.json") -Raw -Encoding UTF8 | ConvertFrom-Json
}
# Presentation only: scale uniformly to the same main-head height.
# Individual PNG deliverables are copied generation outputs and are not resized.
$preview = [Drawing.Bitmap]::new(1800,1040)
$g = [Drawing.Graphics]::FromImage($preview)
$g.Clear([Drawing.Color]::FromArgb(239,237,242))
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = [Drawing.Font]::new('Malgun Gothic',27,[Drawing.FontStyle]::Bold)
$format = [Drawing.StringFormat]::new()
$format.Alignment = [Drawing.StringAlignment]::Center
for ($i=0; $i -lt 3; $i++) {
    $im = [Drawing.Image]::FromFile((Join-Path $taskDir "png/$($keys[$i]).png"))
    $r = $rows[$i]
    $scale = 260.0 / ($r.chin - $r.crown)
    $x = $i*600 + 300 - $r.cx*$scale
    $y = 160 - $r.crown*$scale
    $g.DrawImage($im,[single]$x,[single]$y,[single]($im.Width*$scale),[single]($im.Height*$scale))
    $g.DrawString($labels[$i],$font,[Drawing.Brushes]::Black,[Drawing.RectangleF]::new(($i*600),950,600,70),$format)
    $im.Dispose()
}
$preview.Save((Join-Path $taskDir 'preview.png'),[Drawing.Imaging.ImageFormat]::Png)
$format.Dispose(); $font.Dispose(); $g.Dispose(); $preview.Dispose()
$files = $keys | ForEach-Object { Join-Path $taskDir "png/$_.png" }
Compress-Archive -LiteralPath $files -DestinationPath (Join-Path $taskDir 'uniform_trio_pngs.zip') -Force
