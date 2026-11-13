$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
public static class SpritePackaging {
    public static byte[] Place(byte[] source,int sw,int sh,int ss,int dw,int dh,int ds,int dx,int dy) {
        byte[] output=new byte[ds*dh];
        for(int y=0;y<sh;y++) for(int x=0;x<sw;x++) {
            int si=y*ss+x*4, di=(y+dy)*ds+(x+dx)*4;
            output[di+3]=source[si+3];
            // Hidden RGB is irrelevant to the visible image; zero it to prevent
            // false RGB-only previews from showing a background glow.
            if(source[si+3]!=0) {
                output[di]=source[si];output[di+1]=source[si+1];output[di+2]=source[si+2];
            }
        }
        return output;
    }
    public static long[] Compare(byte[] src,int sw,int sh,int ss,byte[] dst,int ds,int dx,int dy) {
        long alphaDiff=0,visibleRgbDiff=0;
        for(int y=0;y<sh;y++) for(int x=0;x<sw;x++) {
            int si=y*ss+x*4, di=(y+dy)*ds+(x+dx)*4;
            if(src[si+3]!=dst[di+3])alphaDiff++;
            if(src[si+3]!=0 && (src[si]!=dst[di]||src[si+1]!=dst[di+1]||src[si+2]!=dst[di+2]))visibleRgbDiff++;
        }
        return new long[]{alphaDiff,visibleRgbDiff};
    }
}
'@
function Read-Pixels([Drawing.Bitmap]$image) {
    $rect=[Drawing.Rectangle]::new(0,0,$image.Width,$image.Height)
    $bits=$image.LockBits($rect,[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        if($bits.Stride -lt 0){throw 'Negative stride'}
        $buffer=[byte[]]::new($bits.Stride*$image.Height)
        [Runtime.InteropServices.Marshal]::Copy($bits.Scan0,$buffer,0,$buffer.Length)
        return @{bytes=$buffer;stride=$bits.Stride}
    } finally {$image.UnlockBits($bits)}
}
$root=(Get-Location).Path
$taskDir=Join-Path $root 'docs/silver_trio_pose_restoration_v1'
$outputDir=Join-Path $taskDir 'png'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$inputs=Get-Content -LiteralPath (Join-Path $taskDir 'initial_alpha_report.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$names=@('01_left_pose.png','02_middle_pose.png','03_right_pose.png')
$manifest=@()
for($i=0;$i -lt 3;$i++) {
    $entry=$inputs[$i]
    $src=[Drawing.Bitmap]::new($entry.file)
    $srcData=Read-Pixels $src
    $dst=[Drawing.Bitmap]::new(1280,1792,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $dx=[int][Math]::Round(640-($entry.strong_alpha_bounds[0]+$entry.strong_alpha_bounds[2])/2)
    $dy=1728-[int]$entry.strong_alpha_bounds[3]
    if($dx -lt 0 -or $dy -lt 0 -or $dx+$src.Width -gt $dst.Width -or $dy+$src.Height -gt $dst.Height) {throw 'Packaging would crop source pixels'}
    $rect=[Drawing.Rectangle]::new(0,0,$dst.Width,$dst.Height)
    $bits=$dst.LockBits($rect,[Drawing.Imaging.ImageLockMode]::WriteOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $outPixels=[SpritePackaging]::Place($srcData.bytes,$src.Width,$src.Height,$srcData.stride,$dst.Width,$dst.Height,$bits.Stride,$dx,$dy)
        [Runtime.InteropServices.Marshal]::Copy($outPixels,0,$bits.Scan0,$outPixels.Length)
    } finally {$dst.UnlockBits($bits)}
    $outPath=Join-Path $outputDir $names[$i]
    $dst.Save($outPath,[Drawing.Imaging.ImageFormat]::Png)
    $dst.Dispose()
    $reloaded=[Drawing.Bitmap]::new($outPath)
    $reloadData=Read-Pixels $reloaded
    $diff=[SpritePackaging]::Compare($srcData.bytes,$src.Width,$src.Height,$srcData.stride,$reloadData.bytes,$reloadData.stride,$dx,$dy)
    if($diff[0] -ne 0 -or $diff[1] -ne 0){throw "Visible pixels changed while packaging $($names[$i])"}
    $manifest += [pscustomobject]@{
        output=$names[$i];source=$entry.file;source_size=@($src.Width,$src.Height)
        canvas_size=@(1280,1792);translation=@($dx,$dy);resized=$false
        alpha_different_pixels=$diff[0];visible_rgb_different_pixels=$diff[1]
        note='Only transparent canvas padding/translation and zeroing RGB at alpha=0; all alpha and all visible RGB preserved exactly.'
    }
    $src.Dispose();$reloaded.Dispose()
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $taskDir 'packaging_manifest.json') -Encoding utf8

# Review contact sheet only. The three delivered PNGs above are never resized.
$preview=[Drawing.Bitmap]::new(1440,780)
$g=[Drawing.Graphics]::FromImage($preview)
$g.Clear([Drawing.Color]::FromArgb(232,230,238))
$g.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$font=[Drawing.Font]::new('Malgun Gothic',22)
$labels=@('왼쪽 포즈','가운데 포즈','오른쪽 포즈')
for($i=0;$i -lt 3;$i++) {
    $im=[Drawing.Image]::FromFile((Join-Path $outputDir $names[$i]))
    $g.DrawImage($im,($i*480),25,480,672)
    $g.DrawString($labels[$i],$font,[Drawing.Brushes]::Black,($i*480+155),720)
    $im.Dispose()
}
$preview.Save((Join-Path $taskDir 'preview.png'),[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$preview.Dispose()
$archive=Join-Path $taskDir 'silver_trio_restored_pngs.zip'
Compress-Archive -LiteralPath ($names | ForEach-Object {Join-Path $outputDir $_}) -DestinationPath $archive -Force
$manifest | Select-Object output,canvas_size,resized,alpha_different_pixels,visible_rgb_different_pixels | Format-Table
