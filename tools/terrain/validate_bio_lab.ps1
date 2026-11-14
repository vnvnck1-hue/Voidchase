$ErrorActionPreference='Stop'
$bioAssetRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../docs/bio_lab_assets_2026-11-13'))
Add-Type -AssemblyName System.Drawing
$bioDef = Get-Content -Raw -LiteralPath (Join-Path $bioAssetRoot 'bio_lab_assets.json') | ConvertFrom-Json
$bioAtlasCheck = [Drawing.Bitmap]::new((Join-Path $bioAssetRoot 'bio_lab_atlas.png'))
$bioPixelChecks=@()
foreach($bioAsset in $bioDef.assets){
    $bioSpriteCheck=[Drawing.Bitmap]::new((Join-Path $bioAssetRoot $bioAsset.file))
    $bioMismatches=0
    for($checkY=0;$checkY -lt $bioSpriteCheck.Height;$checkY++){
        for($checkX=0;$checkX -lt $bioSpriteCheck.Width;$checkX++){
            if($bioSpriteCheck.GetPixel($checkX,$checkY).ToArgb() -ne $bioAtlasCheck.GetPixel(($bioAsset.atlas_rect[0]+$checkX),($bioAsset.atlas_rect[1]+$checkY)).ToArgb()){$bioMismatches++}
        }
    }
    $corners=@($bioSpriteCheck.GetPixel(0,0).A,$bioSpriteCheck.GetPixel(($bioSpriteCheck.Width-1),0).A,$bioSpriteCheck.GetPixel(0,($bioSpriteCheck.Height-1)).A,$bioSpriteCheck.GetPixel(($bioSpriteCheck.Width-1),($bioSpriteCheck.Height-1)).A)
    $bioPixelChecks += [ordered]@{name=$bioAsset.name;compared_pixels=($bioSpriteCheck.Width*$bioSpriteCheck.Height);atlas_rgba_mismatches=$bioMismatches;corner_alpha=$corners}
    $bioSpriteCheck.Dispose()
    if($bioMismatches -gt 0){throw ('Atlas RGBA mismatch: '+$bioAsset.name+' '+$bioMismatches)}
    if(@($corners | Where-Object {$_ -ne 0}).Count -gt 0){throw ('Nontransparent corner: '+$bioAsset.name)}
}
$bioAtlasCheck.Dispose()
$bioSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../docs/field_diorama_concepts_2026-11-13/03_bio_greenhouse.png'))
[ordered]@{
    date='2026-11-13'
    source_sha256=(Get-FileHash -LiteralPath $bioSource -Algorithm SHA256).Hash
    asset_count=$bioDef.assets.Count
    alpha_checked=$true
    atlas_pixel_checks=$bioPixelChecks
    visual_review='All six assets inspected on a contrasting flat background. Original source and reference crops inspected. No characters/UI/background retained. Source-guided reconstruction, not native pixel identity.'
} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $bioAssetRoot 'validation.json') -Encoding utf8
$bioZipInputs=@(
    (Join-Path $bioAssetRoot 'png'),(Join-Path $bioAssetRoot 'masters'),(Join-Path $bioAssetRoot 'references'),
    (Join-Path $bioAssetRoot 'bio_lab_atlas.png'),(Join-Path $bioAssetRoot 'bio_lab_assets.json'),
    (Join-Path $bioAssetRoot 'preview.png'),(Join-Path $bioAssetRoot 'README.md'),
    (Join-Path $bioAssetRoot 'validation.json'),(Join-Path $bioAssetRoot 'prompts.md')
)
Compress-Archive -LiteralPath $bioZipInputs -DestinationPath (Join-Path $bioAssetRoot 'bio_lab_assets_v1.zip') -Force
$bioPixelChecks | ForEach-Object {Write-Output ('{0}: {1} checked, {2} RGBA mismatches' -f $_.name,$_.compared_pixels,$_.atlas_rgba_mismatches)}
Get-Item -LiteralPath (Join-Path $bioAssetRoot 'bio_lab_assets_v1.zip') | Select-Object Name,Length

