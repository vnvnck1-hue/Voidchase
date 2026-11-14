param()
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$bioPackageRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../docs/bio_lab_assets_2026-11-13'))
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class BioSpritePack {
    public static Rectangle Bounds(Bitmap b, int cutoff) {
        int x0=b.Width, y0=b.Height, x1=-1, y1=-1;
        var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
        var row=new byte[b.Width*4];
        for(int y=0;y<b.Height;y++) {
            Marshal.Copy(IntPtr.Add(d.Scan0,y*d.Stride),row,0,row.Length);
            for(int x=0;x<b.Width;x++) if(row[x*4+3]>=cutoff) {
                x0=Math.Min(x0,x);y0=Math.Min(y0,y);x1=Math.Max(x1,x);y1=Math.Max(y1,y);
            }
        }
        b.UnlockBits(d);
        return Rectangle.FromLTRB(x0,y0,x1+1,y1+1);
    }
    public static long[] AlphaStats(Bitmap b) {
        long[] stats=new long[3];
        var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
        var row=new byte[b.Width*4];
        for(int y=0;y<b.Height;y++) {
            Marshal.Copy(IntPtr.Add(d.Scan0,y*d.Stride),row,0,row.Length);
            for(int x=0;x<b.Width;x++) {
                int a=row[x*4+3]; stats[a==0?0:(a==255?2:1)]++;
            }
        }
        b.UnlockBits(d);return stats;
    }
    public static void NormalizeAlpha(Bitmap b) {
        var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.ReadWrite,PixelFormat.Format32bppArgb);
        var row=new byte[b.Width*4];
        for(int y=0;y<b.Height;y++) {
            Marshal.Copy(IntPtr.Add(d.Scan0,y*d.Stride),row,0,row.Length);
            for(int x=0;x<b.Width;x++) {
                int k=x*4;int a=row[k+3];
                if(a<8) { row[k]=row[k+1]=row[k+2]=row[k+3]=0; }
                else if(a>=250) row[k+3]=255;
            }
            Marshal.Copy(row,0,IntPtr.Add(d.Scan0,y*d.Stride),row.Length);
        }
        b.UnlockBits(d);
    }
    public static Bitmap Resize(Bitmap source, Rectangle crop, int w, int h, RectangleF target) {
        Bitmap result=new Bitmap(w,h,PixelFormat.Format32bppArgb);
        using(var g=Graphics.FromImage(result)) {
            g.Clear(Color.Transparent);
            g.CompositingMode=CompositingMode.SourceCopy;
            g.InterpolationMode=InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode=PixelOffsetMode.HighQuality;
            using(var attr=new ImageAttributes()) {
                attr.SetWrapMode(WrapMode.TileFlipXY);
                g.DrawImage(source,Rectangle.Round(target),crop.X,crop.Y,crop.Width,crop.Height,GraphicsUnit.Pixel,attr);
            }
        }
        return result;
    }
    public static void CopyRGBA(Bitmap source, Bitmap target, int left, int top) {
        var s=source.LockBits(new Rectangle(0,0,source.Width,source.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
        var t=target.LockBits(new Rectangle(0,0,target.Width,target.Height),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);
        var row=new byte[source.Width*4];
        for(int y=0;y<source.Height;y++) {
            Marshal.Copy(IntPtr.Add(s.Scan0,y*s.Stride),row,0,row.Length);
            Marshal.Copy(row,0,IntPtr.Add(t.Scan0,(top+y)*t.Stride+left*4),row.Length);
        }
        source.UnlockBits(s);target.UnlockBits(t);
    }
    public static void Preview(string root,string[] names) {
        using(var sheet=new Bitmap(1500,1120,PixelFormat.Format32bppArgb))
        using(var g=Graphics.FromImage(sheet))
        using(var font=new Font("Malgun Gothic",24,FontStyle.Bold))
        using(var small=new Font("Malgun Gothic",16))
        using(var pen=new Pen(Color.FromArgb(75,104,111),1)) {
            g.Clear(Color.FromArgb(24,34,42));
            g.SmoothingMode=SmoothingMode.AntiAlias;
            g.InterpolationMode=InterpolationMode.HighQualityBicubic;
            g.DrawString("BIO LAB / 블록 3종 + 프랍 3종",font,Brushes.White,42,24);
            g.DrawString("원화 기준 색 · 형태 / 개별 투명 PNG / 동일 블록 규격",small,Brushes.LightGray,44,70);
            string[] labels={"01 기본 민트 블록","02 새싹 마크 블록","03 배수구 · 뿌리 관찰창","04 식물 배양기","05 수경재배대","06 샘플 냉장 박스"};
            for(int i=0;i<6;i++) {
                int col=i%3,row=i/3;int x=30+col*490,y=122+row*470;
                using(var panel=new SolidBrush(Color.FromArgb(37,49,58)))
                    g.FillRectangle(panel,x,y,470,450);
                g.DrawRectangle(pen,x,y,470,450);
                g.DrawString(labels[i],small,Brushes.White,x+18,y+15);
                using(var b=new Bitmap(Path.Combine(root,"png",names[i]+".png"))) {
                    float scale=i<3?1.42f:Math.Min(1.0f,Math.Min(414f/b.Width,376f/b.Height));
                    float w=b.Width*scale,h=b.Height*scale;
                    g.DrawImage(b,x+(470-w)/2,y+65+(365-h)/2,w,h);
                }
            }
            g.DrawString("투명 영역 확인용 배경이며 PNG에는 배경이 포함되지 않습니다.",small,Brushes.LightGray,44,1080);
            sheet.Save(Path.Combine(root,"preview.png"),ImageFormat.Png);
        }
    }
}
'@ -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Runtime,System.Runtime.InteropServices,System.Private.Windows.GdiPlus,System.Private.Windows.Core
$bioPngDir=Join-Path $bioPackageRoot 'png'
New-Item -ItemType Directory -Force -Path $bioPngDir | Out-Null
$bioNames=@('block_01_mint','block_02_sprout','block_03_drain','prop_01_cultivation_chamber','prop_02_hydroponic_rack','prop_03_sample_cooler')
$bioAssetRecords=@()
$bioAtlas=[Drawing.Bitmap]::new(1024,1024,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bioAtlasLocations=@(@(8,8),@(312,8),@(616,8),@(8,240),@(400,240),@(800,240))
for($i=0;$i -lt $bioNames.Count;$i++) {
    $name=$bioNames[$i]
    $master=[Drawing.Bitmap]::new((Join-Path $bioPackageRoot ('masters/'+$name+'.png')))
    $masterSize=@($master.Width,$master.Height)
    [BioSpritePack]::NormalizeAlpha($master)
    if($i -lt 3) {
        # One common rectangle and uniform scale: no independent X/Y deformation.
        $crop=[Drawing.Rectangle]::new(104,96,1328,864)
        $sprite=[BioSpritePack]::Resize($master,$crop,288,208,[Drawing.RectangleF]::new(16,12,256,166.5542))
        $pivot=@(144,76)
        $top=@(@(144,13),@(270,77),@(144,142),@(17,77))
    } else {
        $crop=[BioSpritePack]::Bounds($master,16)
        $targetWidth=352
        if($i -eq 5){$targetWidth=176}
        $targetHeight=[int][Math]::Round($targetWidth*$crop.Height/[double]$crop.Width)
        $sprite=[BioSpritePack]::Resize($master,$crop,($targetWidth+16),($targetHeight+16),[Drawing.RectangleF]::new(8,8,$targetWidth,$targetHeight))
        $pivot=@([int][Math]::Round($sprite.Width/2.0),($sprite.Height-8))
        $top=$null
    }
    $spritePath=Join-Path $bioPngDir ($name+'.png')
    $sprite.Save($spritePath,[Drawing.Imaging.ImageFormat]::Png)
    $stats=[BioSpritePack]::AlphaStats($sprite)
    $bounds=[BioSpritePack]::Bounds($sprite,16)
    $atlasX=$bioAtlasLocations[$i][0];$atlasY=$bioAtlasLocations[$i][1]
    [BioSpritePack]::CopyRGBA($sprite,$bioAtlas,$atlasX,$atlasY)
    $record=[ordered]@{
        name=$name; file=('png/'+$name+'.png'); master=('masters/'+$name+'.png')
        size=@($sprite.Width,$sprite.Height); source_master_size=$masterSize
        master_crop=@($crop.X,$crop.Y,$crop.Width,$crop.Height)
        anchor_px=$pivot; anchor_kind=$(if($i -lt 3){'top_surface_center'}else{'bottom_center_initial_placement'})
        alpha_bounds=@($bounds.X,$bounds.Y,$bounds.Width,$bounds.Height)
        transparent_pixels=$stats[0]; partial_alpha_pixels=$stats[1]; opaque_pixels=$stats[2]
        atlas_rect=@($atlasX,$atlasY,$sprite.Width,$sprite.Height)
        sha256=(Get-FileHash -LiteralPath $spritePath -Algorithm SHA256).Hash
    }
    if($null -ne $top){$record.top_quad_px=$top;$record.tile_step_x=@(126,64);$record.tile_step_y=@(-127,64)}
    if($stats[0] -eq 0 -or $stats[2] -eq 0){throw ('Invalid alpha: '+$name)}
    $bioAssetRecords+=$record
    $sprite.Dispose();$master.Dispose()
}
$bioAtlas.Save((Join-Path $bioPackageRoot 'bio_lab_atlas.png'),[Drawing.Imaging.ImageFormat]::Png)
$bioAtlas.Dispose()
$bioManifest=[ordered]@{
    version=1; source='../field_diorama_concepts_2026-11-13/03_bio_greenhouse.png'
    method='Built-in image_gen reference-guided extraction/reconstruction; uniform resampling and alpha normalization for export. Not native pixel-identical cuts.'
    block_canvas=@(288,208); atlas='bio_lab_atlas.png'; atlas_size=@(1024,1024)
    filtering='linear'; mipmaps=$false; texture_repeat=$false
    notes=@('Block landmarks are manually read visual guides, not measured collision geometry.','Block anchor is top surface center; prop anchor is a starting bottom-center placement guide.','Alpha >=250 set to255; alpha<8 set to0; RGB retained elsewhere.','Master images are unchanged generator outputs; packed sprites are uniformly scaled.')
    assets=$bioAssetRecords
}
$bioManifest | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $bioPackageRoot 'bio_lab_assets.json') -Encoding utf8
[BioSpritePack]::Preview($bioPackageRoot,$bioNames)
$bioAssetRecords | ForEach-Object { Write-Output ('{0}: {1}x{2}, alpha0={3}, alpha255={4}' -f $_.name,$_.size[0],$_.size[1],$_.transparent_pixels,$_.opaque_pixels) }

