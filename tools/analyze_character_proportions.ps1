param(
    [string]$OutputDir = 'docs/character_style_reference/proportions',
    [string]$CandidateJson = '',
    [switch]$WidthChecks
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = (Get-Location).Path
$out = Join-Path $root $OutputDir
New-Item -ItemType Directory -Path $out -Force | Out-Null
$rows = @(
    @{name='Group 22';file='docs/character_style_reference/그룹 22.png';crown=200;chin=747;shoulder=785;waist=1010;crotch=1280;knee=1490;sole=1730;cx=720},
    @{name='Group 30';file='docs/character_style_reference/그룹 30.png';crown=145;chin=745;shoulder=790;waist=1000;crotch=1280;knee=1490;sole=1750;cx=620},
    @{name='Group 32';file='docs/character_style_reference/그룹 32.png';crown=155;chin=780;shoulder=835;waist=950;crotch=1215;knee=1460;sole=1835;cx=620},
    @{name='Layer 193';file='docs/character_style_reference/레이어 193.png';crown=8;chin=600;shoulder=650;waist=880;crotch=1155;knee=1390;sole=1622;cx=550}
)
if ($CandidateJson) {
    $candidate = Get-Content -LiteralPath $CandidateJson -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable
    foreach ($key in @('name','file','crown','chin','shoulder','waist','crotch','knee','sole','cx')) {
        if (-not $candidate.ContainsKey($key)) { throw "Missing candidate landmark: $key" }
    }
    if ($candidate.chin -le $candidate.crown -or $candidate.sole -le $candidate.chin) { throw 'Invalid crown/chin/sole ordering' }
    $rows += $candidate
} else {
    $rows += @{name='Pink v3';file='docs/pink_twin_hoodie_character_v3/pink_twin_hoodie_character_v3.png';crown=120;chin=655;shoulder=710;waist=885;crotch=1050;knee=1210;sole=1552;cx=520}
}
$referenceRatios = $rows[0..3] | ForEach-Object { ($_.sole-$_.crown)/($_.chin-$_.crown) }
$limits = $referenceRatios | Measure-Object -Minimum -Maximum
$candidateRatio = ($rows[4].sole-$rows[4].crown)/($rows[4].chin-$rows[4].crown)
if ($candidateRatio -lt $limits.Minimum -or $candidateRatio -gt $limits.Maximum) {
    throw ('Candidate ratio {0:F3}H is outside reference range {1:F3}..{2:F3}H' -f $candidateRatio,$limits.Minimum,$limits.Maximum)
}
# Width probe: manually distinguish primary head silhouette from independent
# ponytails/ornaments at crown + 0.55H. These are visual estimates, not skull scans.
$widthBounds = @(@(350,1160),@(169,920),@(185,973),@(138,898))
for ($j=0;$j -lt 4;$j++) {
    $rows[$j].head_left = $widthBounds[$j][0]
    $rows[$j].head_right = $widthBounds[$j][1]
}
if ($WidthChecks) {
    foreach ($key in @('head_left','head_right')) {
        if (-not $rows[4].ContainsKey($key)) { throw "Missing candidate width bound: $key" }
    }
    $referenceWidths = $rows[0..3] | ForEach-Object { ($_.head_right-$_.head_left)/($_.chin-$_.crown) }
    $widthLimits = $referenceWidths | Measure-Object -Minimum -Maximum
    $candidateWidth = ($rows[4].head_right-$rows[4].head_left)/($rows[4].chin-$rows[4].crown)
    if ($candidateWidth -lt $widthLimits.Minimum -or $candidateWidth -gt $widthLimits.Maximum) {
        throw ('Candidate head width {0:F3}H is outside manually observed range {1:F3}..{2:F3}H' -f $candidateWidth,$widthLimits.Minimum,$widthLimits.Maximum)
    }
}
$bmp = [Drawing.Bitmap]::new(2400,1050)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.Clear([Drawing.Color]::White)
$g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font = [Drawing.Font]::new('Arial',15)
$small = [Drawing.Font]::new('Arial',10)
$pen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(190,40,110,220),1.5)
$bodyPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(110,100,100,100),1)
$records = @()
for ($i=0;$i -lt $rows.Count;$i++) {
    $r=$rows[$i]; $im=[Drawing.Image]::FromFile((Join-Path $root $r.file))
    $h=$r.chin-$r.crown; $scale=220.0/$h; $x=$i*480+240-$r.cx*$scale; $y=170-$r.crown*$scale
    $g.SetClip([Drawing.Rectangle]::new($i*480,60,480,880))
    $g.DrawImage($im,[single]$x,[single]$y,[single]($im.Width*$scale),[single]($im.Height*$scale))
    $g.ResetClip()
    $g.DrawString($r.name,$font,[Drawing.Brushes]::Black,[single]($i*480+12),[single]15)
    foreach ($key in @('crown','chin','shoulder','waist','crotch','knee','sole')) {
        $yy=170+($r[$key]-$r.crown)*$scale
        $linePen = if ($key -in @('crown','chin','sole')) {$pen} else {$bodyPen}
        $g.DrawLine($linePen,[single]($i*480+8),[single]$yy,[single]($i*480+472),[single]$yy)
        $ratio=($r[$key]-$r.crown)/$h
        $g.DrawString(('{0} {1:F2}H' -f $key,$ratio),$small,[Drawing.Brushes]::Blue,[single]($i*480+8),[single]($yy+2))
    }
    $record=[ordered]@{name=$r.name;file=$r.file;width=$im.Width;height=$im.Height;crown_y=$r.crown;chin_y=$r.chin;head_unit_px=$h;shoulder_y=$r.shoulder;waist_y=$r.waist;crotch_y=$r.crotch;knee_y=$r.knee;sole_y=$r.sole;standing_head_units=[Math]::Round(($r.sole-$r.crown)/$h,3);landmarks_source='Manual visual landmarks; concealed waist/crotch/knee estimated, not anatomical ground truth.'}
    if ($WidthChecks) {
        $widthY = 170+0.55*220
        $leftX = $x+$r.head_left*$scale
        $rightX = $x+$r.head_right*$scale
        $widthPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(230,0,140,65),2)
        $g.DrawLine($widthPen,[single]$leftX,[single]$widthY,[single]$rightX,[single]$widthY)
        $g.DrawLine($widthPen,[single]$leftX,[single]($widthY-15),[single]$leftX,[single]($widthY+15))
        $g.DrawLine($widthPen,[single]$rightX,[single]($widthY-15),[single]$rightX,[single]($widthY+15))
        $widthH = ($r.head_right-$r.head_left)/$h
        $g.DrawString(('Head W: {0:F2}H' -f $widthH),$small,[Drawing.Brushes]::DarkGreen,[single]($i*480+12),[single]($widthY-24))
        $record.head_width_probe_y = [Math]::Round($r.crown+0.55*$h,1)
        $record.head_left_x = $r.head_left
        $record.head_right_x = $r.head_right
        $record.head_width_h = [Math]::Round($widthH,3)
        $widthPen.Dispose()
    }
    $records += [pscustomobject]$record
    $g.DrawString(('Height: {0:F2}H' -f (($r.sole-$r.crown)/$h)),$font,[Drawing.Brushes]::Black,[single]($i*480+12),[single]965)
    $im.Dispose()
}
$g.DrawString('H = visible main head crown to chin; excludes headpieces, ahoge and separate ponytails. Manual projected landmarks.',$small,[Drawing.Brushes]::Black,12,1015)
$bmp.Save((Join-Path $out 'reference_comparison.png'),[Drawing.Imaging.ImageFormat]::Png)
$records | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'landmarks.json') -Encoding utf8
$g.Dispose();$bmp.Dispose()
$records | Select-Object name,width,height,head_unit_px,standing_head_units | Format-Table

# A geometric construction sheet, not substitute character artwork.
# Uses the range of the four reference poses; all dimensions use the same H.
$guide=[Drawing.Bitmap]::new(1100,1600)
$gg=[Drawing.Graphics]::FromImage($guide);$gg.Clear([Drawing.Color]::White)
$gg.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias
$H=500.0;$top=100.0;$center=550.0
$ink=[Drawing.Pen]::new([Drawing.Color]::FromArgb(200,80,80,80),6)
$blue=[Drawing.Pen]::new([Drawing.Color]::FromArgb(170,25,100,215),2)
$red=[Drawing.Pen]::new([Drawing.Color]::FromArgb(170,210,80,90),2)
$gg.DrawEllipse($ink,225,100,650,500)
$gg.DrawLine($ink,550,600,550,1025)
$gg.DrawLine($ink,335,645,765,645)
$gg.DrawLine($ink,375,815,725,815)
$gg.DrawLine($ink,370,1025,730,1025)
$gg.DrawLines($ink,[Drawing.Point[]]@([Drawing.Point]::new(335,645),[Drawing.Point]::new(270,830),[Drawing.Point]::new(240,1000)))
$gg.DrawLines($ink,[Drawing.Point[]]@([Drawing.Point]::new(765,645),[Drawing.Point]::new(830,830),[Drawing.Point]::new(860,1000)))
$gg.DrawLines($ink,[Drawing.Point[]]@([Drawing.Point]::new(430,1025),[Drawing.Point]::new(390,1230),[Drawing.Point]::new(360,1430)))
$gg.DrawLines($ink,[Drawing.Point[]]@([Drawing.Point]::new(670,1025),[Drawing.Point]::new(710,1230),[Drawing.Point]::new(740,1430)))
$gg.DrawEllipse($ink,270,1400,180,60);$gg.DrawEllipse($ink,650,1400,180,60)
$guideMarks=@(@('CROWN',0),@('CHIN',1),@('SHOULDER',1.09),@('WAIST',1.43),@('CROTCH',1.85),@('KNEE',2.26),@('SOLE',2.72))
foreach($m in $guideMarks){$yy=$top+$H*$m[1];$gg.DrawLine($blue,80,[single]$yy,1020,[single]$yy);$gg.DrawString(('{0} {1:F2}H' -f $m[0],$m[1]),$small,[Drawing.Brushes]::Blue,12,[single]($yy+3))}
$gg.DrawString('ROSTER PROPORTION CONSTRUCTION - 2.72H crown to sole',$font,[Drawing.Brushes]::Black,100,20)
$gg.DrawString('No costume or hair ornaments represented. Follow landmark spacing, not guide line appearance.',$small,[Drawing.Brushes]::Black,100,1540)
$guide.Save((Join-Path $out 'construction_guide.png'),[Drawing.Imaging.ImageFormat]::Png)
$gg.Dispose();$guide.Dispose()
