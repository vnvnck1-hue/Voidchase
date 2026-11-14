$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$bioRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$bioRuntimeDir=Join-Path $bioRoot 'assets/void_defense_bio/terrain'
$bioPropDir=Join-Path $bioRoot 'assets/void_defense_bio/props'
$bioReviewDir=Join-Path $bioRoot 'docs/bio_lab_runtime_v2'
foreach($dir in @($bioRuntimeDir,$bioPropDir,$bioReviewDir)){New-Item -ItemType Directory -Force -Path $dir | Out-Null}
Add-Type -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
public static class BioFaces {
    public const double W=166.4,H=83.2,D=66.56,S=4.0;
    static double Clamp(double n){return Math.Max(0,Math.Min(1,n));}
    static double[] Mix(double[] a,double[] b,double t){return new double[]{a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t};}
    static double[] Quad(double[][] q,double u,double v){return Mix(Mix(q[0],q[1],u),Mix(q[3],q[2],u),v);}
    public static Color Sample(Bitmap b,double x,double y) {
        x=Math.Max(0,Math.Min(b.Width-1.001,x));y=Math.Max(0,Math.Min(b.Height-1.001,y));
        int x0=(int)x,y0=(int)y;double fx=x-x0,fy=y-y0;
        Color[] p={b.GetPixel(x0,y0),b.GetPixel(x0+1,y0),b.GetPixel(x0,y0+1),b.GetPixel(x0+1,y0+1)};
        double[] k={(1-fx)*(1-fy),fx*(1-fy),(1-fx)*fy,fx*fy};double r=0,g=0,bl=0;
        for(int i=0;i<4;i++){r+=p[i].R*k[i];g+=p[i].G*k[i];bl+=p[i].B*k[i];}
        return Color.FromArgb(255,(int)Math.Round(r),(int)Math.Round(g),(int)Math.Round(bl));
    }
    static double[][] Top={new double[]{768,104},new double[]{1421,432},new double[]{768,771},new double[]{112,433}};
    static double[][] Left={new double[]{112,433},new double[]{768,771},new double[]{768,948},new double[]{114,612}};
    static double[][] Right={new double[]{768,771},new double[]{1421,432},new double[]{1421,612},new double[]{768,948}};
    public static Bitmap Bake(Bitmap source,int face,bool masked) {
        int w=(int)Math.Ceiling((face==0?W:W/2)*S)+8;
        int h=(int)Math.Ceiling((face==0?H:H/2+D)*S)+8;
        var output=new Bitmap(w,h,PixelFormat.Format32bppArgb);
        for(int y=0;y<h;y++)for(int x=0;x<w;x++){
            double px=(x+.5-4)/S,py=(y+.5-4)/S,u,v;
            if(face==0){u=py/H+px/W-.5;v=py/H-px/W+.5;}
            else {
                u=px/(W/2);
                double slope=face==1?u*H/2:(1-u)*H/2;
                v=(py-slope)/D;
            }
            bool inside=u>=0&&u<=1&&v>=0&&v<=1;
            if(masked&&!inside)continue;
            u=Clamp(u);v=Clamp(v);
            double[] point;
            if(face==0){point=Quad(Top,u,v);}
            else {
                // Keep original pipe/root-window strip and footer at their natural scale.
                // Insert only a plain teal structural wall band below the decorative strip.
                double nativeDepth=22.65,footer=1.8,t=v*D;
                double sourceV;
                if(t<nativeDepth-footer)sourceV=t/nativeDepth;
                else if(t>D-footer)sourceV=(nativeDepth-footer+t-(D-footer))/nativeDepth;
                else {
                    // Sample an undecorated structural pillar patch, with subtle native texture.
                    double pu=.93+.025*((u*11)%1),pv=.50+.24*((t/9)%1);
                    point=Quad(Left,pu,pv);
                    output.SetPixel(x,y,Sample(source,point[0],point[1]));
                    continue;
                }
                point=Quad(face==1?Left:Right,u,Clamp(sourceV));
            }
            output.SetPixel(x,y,Sample(source,point[0],point[1]));
        }
        return output;
    }
    public static void Blit(Bitmap a,Bitmap b,int x,int y){
        var s=a.LockBits(new Rectangle(0,0,a.Width,a.Height),ImageLockMode.ReadOnly,PixelFormat.Format32bppArgb);
        var d=b.LockBits(new Rectangle(0,0,b.Width,b.Height),ImageLockMode.WriteOnly,PixelFormat.Format32bppArgb);
        var row=new byte[a.Width*4];
        for(int j=0;j<a.Height;j++){Marshal.Copy(IntPtr.Add(s.Scan0,j*s.Stride),row,0,row.Length);Marshal.Copy(row,0,IntPtr.Add(d.Scan0,(y+j)*d.Stride+x*4),row.Length);}
        a.UnlockBits(s);b.UnlockBits(d);
    }
    public static void Prop(string src,string dst){
        using(var a=new Bitmap(src)){
            int w=(int)Math.Round(a.Width*.65),h=(int)Math.Round(a.Height*.65);
            using(var b=new Bitmap(w,h,PixelFormat.Format32bppArgb))
            using(var g=Graphics.FromImage(b)){
                g.CompositingMode=CompositingMode.SourceCopy;
                g.InterpolationMode=InterpolationMode.HighQualityBicubic;
                g.DrawImage(a,new Rectangle(0,0,w,h),0,0,a.Width,a.Height,GraphicsUnit.Pixel);
                b.Save(dst,ImageFormat.Png);
            }
        }
    }
}
'@ -ReferencedAssemblies System.Drawing.Common,System.Drawing.Primitives,System.Runtime,System.Runtime.InteropServices,System.Private.Windows.GdiPlus,System.Private.Windows.Core
$bioAtlas=[Drawing.Bitmap]::new(1536,1536,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
$bioVariants=@('block_01_mint','block_02_sprout','block_03_drain')
$bioPatches=@()
for($i=0;$i -lt 3;$i++){
    $bioMasterPath=Join-Path $bioRoot ('docs/bio_lab_assets_2026-11-13/masters/'+$bioVariants[$i]+'.png')
    $bioMaster=[Drawing.Bitmap]::new($bioMasterPath)
    for($face=0;$face -lt 3;$face++){
        $faceName=@('top','side_left','side_right')[$face]+'_'+('{0:00}' -f ($i+1))
        $raw=[BioFaces]::Bake($bioMaster,$face,$false)
        $masked=[BioFaces]::Bake($bioMaster,$face,$true)
        $masked.Save((Join-Path $bioRuntimeDir ($faceName+'.png')),[Drawing.Imaging.ImageFormat]::Png)
        $ax=@(8,696,1048)[$face];$ay=8+$i*480
        [BioFaces]::Blit($raw,$bioAtlas,$ax,$ay)
        if($face -eq 0){
            $points=@(@(83.2,0),@(166.4,41.6),@(83.2,83.2),@(0,41.6))
            $local=@(@(83.2,0),@(166.4,41.6),@(83.2,83.2),@(0,41.6))
        }elseif($face -eq 1){
            $points=@(@(0,41.6),@(83.2,83.2),@(83.2,149.76),@(0,108.16))
            $local=@(@(0,0),@(83.2,41.6),@(83.2,108.16),@(0,66.56))
        }else{
            $points=@(@(83.2,83.2),@(166.4,41.6),@(166.4,108.16),@(83.2,149.76))
            $local=@(@(0,41.6),@(83.2,0),@(83.2,66.56),@(0,108.16))
        }
        $uv=@($local | ForEach-Object {,@(($ax+4+$_[0]*4),($ay+4+$_[1]*4))})
        $origin=@(@(0,0),@(0,41.6),@(83.2,41.6))[$face]
        $bioPatches+=[ordered]@{name=$faceName;variant=($i+1);face=@('top','left','right')[$face];file=($faceName+'.png');atlas_rect=@($ax,$ay,$raw.Width,$raw.Height);atlas_points=$uv;geometry_points=$points;standalone_texture_scale=0.25;standalone_sprite_offset=@(($origin[0]-1),($origin[1]-1));source=$bioVariants[$i];source_sha256=(Get-FileHash -LiteralPath $bioMasterPath -Algorithm SHA256).Hash}
        $raw.Dispose();$masked.Dispose()
    }
    $bioMaster.Dispose()
}
$bioAtlas.Save((Join-Path $bioRuntimeDir 'bio-lab-atlas.png'),[Drawing.Imaging.ImageFormat]::Png)
$bioAtlas.Dispose()
$bioDefinition=[ordered]@{version=2;atlas='bio-lab-atlas.png';atlas_size=@(1536,1536);tile_size=@(166.4,83.2);face_height=66.56;top_center=@(83.2,41.6);bake_scale=4;bleed=4;variant_count=3;method='Geometric face reprojection from approved asset masters. Original side ornament strip retained at natural scale; plain structural wall inserted below. No new image generation, no recoloring, no vertical stretching of pipe or root ornament.';patches=$bioPatches}
$bioDefinition | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath (Join-Path $bioRuntimeDir 'bio-lab.json') -Encoding utf8
foreach($p in @('prop_01_cultivation_chamber','prop_02_hydroponic_rack','prop_03_sample_cooler')){
    [BioFaces]::Prop((Join-Path $bioRoot ('docs/bio_lab_assets_2026-11-13/png/'+$p+'.png')),(Join-Path $bioPropDir ($p+'.png')))
}
Write-Output ('Baked '+$bioPatches.Count+' runtime faces; W=166.4 H=83.2 side=66.56, atlas1536, 3 props normalized to game scale.')

