param(
    [Parameter(Mandatory=$true)][string[]]$Paths,
    [string]$ReportPath = ''
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if (-not ('PngAlphaStats' -as [type])) {
    Add-Type -TypeDefinition @'
public static class PngAlphaStats {
    public static long[] Scan(byte[] data, int width, int height, int stride) {
        long transparent=0, partial=0, opaque=0, edge=0;
        int minX=width, minY=height, maxX=-1, maxY=-1;
        int minStrongX=width, minStrongY=height, maxStrongX=-1, maxStrongY=-1;
        for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
            int a=data[y*stride+x*4+3];
            if(a==0) transparent++; else if(a==255) opaque++; else partial++;
            if(a>0) {
                if(x<minX)minX=x;if(x>maxX)maxX=x;
                if(y<minY)minY=y;if(y>maxY)maxY=y;
                if(x==0||y==0||x==width-1||y==height-1)edge++;
            }
            if(a>=128) {
                if(x<minStrongX)minStrongX=x;if(x>maxStrongX)maxStrongX=x;
                if(y<minStrongY)minStrongY=y;if(y>maxStrongY)maxStrongY=y;
            }
        }
        return new long[]{transparent,partial,opaque,minX,minY,maxX,maxY,edge,minStrongX,minStrongY,maxStrongX,maxStrongY};
    }
}
'@
}
$report = foreach ($path in $Paths) {
    $image=[Drawing.Bitmap]::new((Resolve-Path -LiteralPath $path).Path)
    $rect=[Drawing.Rectangle]::new(0,0,$image.Width,$image.Height)
    $data=$image.LockBits($rect,[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        if($data.Stride -lt 0){throw 'Negative bitmap stride is not supported'}
        $buffer=[byte[]]::new($data.Stride*$image.Height)
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0,$buffer,0,$buffer.Length)
        $stats=[PngAlphaStats]::Scan($buffer,$image.Width,$image.Height,$data.Stride)
    } finally {$image.UnlockBits($data)}
    [pscustomobject]@{
        file=(Resolve-Path -LiteralPath $path).Path
        width=$image.Width;height=$image.Height;pixel_format=[string]$image.PixelFormat
        transparent_pixels=$stats[0];partial_alpha_pixels=$stats[1];opaque_pixels=$stats[2]
        content_bounds=@($stats[3],$stats[4],$stats[5],$stats[6])
        edge_nontransparent_pixels=$stats[7]
        strong_alpha_bounds=@($stats[8],$stats[9],$stats[10],$stats[11])
        has_transparency=($stats[0] -gt 0)
    }
    $image.Dispose()
}
$json=$report | ConvertTo-Json -Depth 4
if($ReportPath){$json | Set-Content -LiteralPath $ReportPath -Encoding utf8}
$json
