$ModuleName   = "TSDProvider"
$ModulePath   = "C:\Program Files\WindowsPowerShell\Modules"
$ProviderPath = "$($ModulePath)\$($ModuleName)"

if(!(Test-Path $ProviderPath)) { md $ProviderPath | out-null}

$FilesToCopy = echo TSDProvider.psd1 TSDProvider.psm1 

$FilesToCopy | ForEach {
	Copy-Item -Verbose -Path $_ -Destination "$($ProviderPath)\$($_)"
}