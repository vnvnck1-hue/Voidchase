$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = (Get-Location).Path
$out = Join-Path $root 'docs/cyber_squad_field_2026-11-13'
$references = @(
    @{name='Group 22';file='docs/character_style_reference/그룹 22.png';crown=200;chin=747;sole=1730;cx=720;head_left=350;head_right=1160},
    @{name='Group 30';file='docs/character_style_reference/그룹 30.png';crown=145;chin=745;sole=1750;cx=620;head_left=169;head_right=920},
    @{name='Group 32';file='docs/character_style_reference/그룹 32.png';crown=155;chin=780;sole=1835;cx=620;head_left=185;head_right=973},
    @{name='Layer 193';file='docs/character_style_reference/레이어 193.png';crown=8;chin=600;sole=1622;cx=550;head_left=138;head_right=898}
)
$candidates = (Get-Content -LiteralPath (Join-Path $out 'landmarks.json') -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable).characters
$rows = @($references) + @($candidates)
$sheet = [Drawing.Bitmap]::new(2880,650)
$g = [Drawing.Graphics]::FromImage($sheet)
$g.Clear([Drawing.Color]::White)
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = [Drawing.Font]::new('Arial',14)
$small = [Drawing.Font]::new('Arial',10)
$blue = [Drawing.Pen]::new([Drawing.Color]::FromArgb(170,30,105,215),1)
$green = [Drawing.Pen]::new([Drawing.Color]::FromArgb(230,0,155,70),2)
for ($i=0; $i -lt $rows.Count; $i++) {
    $row=$rows[$i]
    $h=$row.chin-$row.crown
    $scale=150.0/$h
    $x=$i*360+180-$row.cx*$scale
    $y=95-$row.crown*$scale
    $img=[Drawing.Bitmap]::FromFile((Join-Path $root $row.file))
    $g.SetClip([Drawing.Rectangle]::new($i*360,55,360,495))
    if ($row.ContainsKey('crop')) {
        $c=$row.crop
        $dest=[Drawing.RectangleF]::new(($x+$c[0]*$scale),($y+$c[1]*$scale),($c[2]*$scale),($c[3]*$scale))
        $src=[Drawing.RectangleF]::new($c[0],$c[1],$c[2],$c[3])
        $g.DrawImage($img,$dest,$src,[Drawing.GraphicsUnit]::Pixel)
    } else {
        $g.DrawImage($img,[single]$x,[single]$y,[single]($img.Width*$scale),[single]($img.Height*$scale))
    }
    $g.ResetClip()
    $g.DrawString($row.name,$font,[Drawing.Brushes]::Black,($i*360+12),14)
    foreach ($mark in @('crown','chin','sole')) {
        $yy=95+($row[$mark]-$row.crown)*$scale
        $g.DrawLine($blue,[single]($i*360+6),[single]$yy,[single]($i*360+354),[single]$yy)
    }
    $probe=95+0.55*150
    $g.DrawLine($green,[single]($x+$row.head_left*$scale),[single]$probe,[single]($x+$row.head_right*$scale),[single]$probe)
    $ratio=($row.sole-$row.crown)/$h
    $width=($row.head_right-$row.head_left)/$h
    $g.DrawString(('Crown to sole {0:F2}H' -f $ratio),$font,[Drawing.Brushes]::Black,($i*360+12),557)
    $g.DrawString(('Main head width {0:F2}H' -f $width),$small,[Drawing.Brushes]::DarkGreen,($i*360+12),586)
    $img.Dispose()
}
$g.DrawString('Same H, isotropic display scaling only. Manual projected landmarks; new field boundaries +/-2-3px. Exclude independent hair and equipment. See landmarks.json for face / body widths and occlusion notes.',$small,[Drawing.Brushes]::Black,12,623)
$sheet.Save((Join-Path $out 'reference_comparison.png'),[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $sheet.Dispose(); $font.Dispose(); $small.Dispose(); $blue.Dispose(); $green.Dispose()
