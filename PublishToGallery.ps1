
$p = @{
    Name = "TSDProvider"
    NuGetApiKey = $NuGetApiKey 
    LicenseUri = "https://github.com/dfinke/OneGetTSDProvider/blob/master/LICENSE" 
    Tag = "TSD","Github","OneGet","Provider","TypeScript"
    ReleaseNote = "-VERBOSE displays location of installed package"
    ProjectUri = "https://github.com/dfinke/OneGetTSDProvider"
}

Publish-Module @p