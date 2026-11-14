$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$taskDir = $PSScriptRoot
$keys = @('01_quiet_dreamer','02_playful_punk','03_regal_romantic')
$labels = @('조용한 몽상가형','장난스러운 펑크형','도도한 고딕형')
$rows = foreach ($key in $keys) {
    Get-Content -LiteralPath (Join-Path $taskDir "audit/$key.json") -Raw -Encoding UTF8 | ConvertFrom-Json
}
# Only the review contact sheet is scaled uniformly. PNG deliverables remain unchanged.
$preview = [Drawing.Bitmap]::new(1800,1040)
$g = [Drawing.Graphics]::FromImage($preview)
$g.Clear([Drawing.Color]::FromArgb(233,229,238))
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
Compress-Archive -LiteralPath $files -DestinationPath (Join-Path $taskDir 'goth_trio_pngs.zip') -Force
