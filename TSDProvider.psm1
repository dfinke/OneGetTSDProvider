$Providername = "TSD"
$TSDPath     = "$env:LOCALAPPDATA\OneGet\TSD"
$CSVFilename  = "$($TSDPath)\OneGetData.csv"

function Get-AuthHeader {
    param(
    	[pscredential]$Credential
    )    

    $authInfo = "{0}:{1}" -f $Credential.UserName, $Credential.GetNetworkCredential().Password
    $authInfo = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($authInfo))

    @{
        "Authorization" = "Basic " + $authInfo
        "Content-Type" = "application/json"
    }
}

function Initialize-Provider     { write-debug "In $($Providername) - Initialize-Provider" }
function Get-PackageProviderName { return $Providername }

function Resolve-PackageSource { 

    write-debug "In $($ProviderName)- Resolve-PackageSources"    
    
    $IsTrusted    = $false
    $IsRegistered = $false
    $IsValidated  = $true
    
    foreach($Name in @($request.PackageSources)) {
    	$Location = "https://api.github.com/users/$($Name)/gists"
    	
    	write-debug "In $($ProviderName)- Resolve-PackageSources gist: {0}" $Location

        New-PackageSource $Name $Location $IsTrusted $IsRegistered $IsValidated
    }        
}

function Find-Package { 
    param(
        [string[]] $names,
        [string] $requiredVersion,
        [string] $minimumVersion,
        [string] $maximumVersion
    )

	write-debug "In $($ProviderName) - Find-Package"

	#write-debug "In $($ProviderName) - Find-Package for user {0}" $Name

	if($request.Credential) { $Header = (Get-AuthHeader $request.Credential) }

	ForEach($targetItem in (Invoke-RestMethod "https://api.github.com/repos/borisyankov/DefinitelyTyped/contents" -Header $Header)) {	    
   	    if($request.IsCancelled){break}

		if($targetItem.type -eq 'dir' -and ($targetItem.Name -match $names)) {
		    write-debug "In $($ProviderName) - Find-Package item {0} {1}" $targetItem.Name $targetItem.url
			$SWID = @{
				version              = "1.0"
				versionScheme        = "semver"
				fastPackageReference = $targetItem.url
				name                 = $targetItem.name
				source               = "TypeScript"
				summary              = "TypeScript Definition"
				searchKey            = $targetItem.name
			}           

			$SWID.fastPackageReference = $SWID | ConvertTo-JSON -Compress
			New-SoftwareIdentity @SWID
		}
	}
}

function Install-Package { 
    param(
        [string] $fastPackageReference
    )
    
        $rawUrl = ($fastPackageReference|convertfrom-json).fastPackageReference
	
	write-debug "In $($ProviderName) - Install-Package - {0}" $rawUrl	
	
	md -ErrorAction Ignore $TSDPath | out-null
	
	foreach($TSD in ( (Invoke-RestMethod $rawUrl) | Where {$_.name -match '\.d\.'})) {	
	
	    $details = Invoke-RestMethod $TSD.url
	    
	    Write-Debug "{0}" $details.name
	    Write-Debug "{0}" $details.download_url
	    
	    $outfile = "$($TSDPath)\$($details.name)"
	    Invoke-RestMethod $details.download_url -outfile $outfile
	    
	    write-verbose "Package intstall location {0}" $outfile
	}
}

function ConvertTo-HashTable {
    param(
        [Parameter(ValueFromPipeline)]
        $Data
    )

    process {
        if(!$Fields) {            
            $Fields=($Data|Get-Member -MemberType NoteProperty ).Name
        }
        
        $h=[Ordered]@{}
        foreach ($Field in $Fields)
        {
            $h.$Field = $Data.$Field                        
        }
        $h
    }
}

function Get-InstalledPackage {
    param()

    if(Test-Path $CSVFilename) {
        $installedPackages = Import-Csv $CSVFilename
        
        write-debug "In $($ProviderName) - Get-InstalledPackage {0}" @($installedPackages).Count   
        
        foreach ($item in ($installedPackages | ConvertTo-HashTable))
        {    
            New-SoftwareIdentity @item
        }
    }
}