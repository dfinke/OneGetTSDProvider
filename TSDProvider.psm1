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
    	$Location = "https://api.github.com/repos/borisyankov/DefinitelyTyped/contents"
    	
    	write-debug "In $($ProviderName)- Resolve-PackageSources TSD: {0}" $Location

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
				summary              = "TypeScript Definition for $($targetItem.name)"
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
	write-debug "Options - {0}" $request.Options.Destination
	write-debug "Creds - {0}" $request.Credential
	
	$OutPath = Resolve-Path $request.Options.Destination
	md -ErrorAction Ignore $TSDPath | out-null
	
	if($request.Credential) { $Header = (Get-AuthHeader $request.Credential) }
	
	foreach($TSD in ( (Invoke-RestMethod $rawUrl -Header $Header) | Where {$_.name -match '\.d\.'})) {	
	
	    $details = Invoke-RestMethod $TSD.url -Header $Header
	    
	    Write-Debug "{0}" $details.name
	    Write-Debug "{0}" $details.download_url
	    
	    $outfile = Join-Path $OutPath $details.name
	    
	    Invoke-RestMethod $details.download_url -outfile $outfile -Header $Header
	    
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

function Get-DynamicOptions { 
    param(
        [Microsoft.PackageManagement.MetaProvider.PowerShell.OptionCategory] $category
    )
    
        write-debug "In TSDProvider - Get-DynamicOption for category $category"

	switch( $category ) {
		Package {
			# options when the user is trying to specify a package 
			#write-Output (New-DynamicOption $category "SS" SecureString $false )
		}

		Source {
			#options when the user is trying to specify a source
		}
		
		Install {
			#options for installation/uninstallation 
			#write-Output (New-DynamicOption $category "Destination" Path $true)
			New-DynamicOption $category "Destination" Path $true
		}
	}
}
