param ($installPath, $toolsPath, $package, $project)

$TargetFileName = 'NuGetReferenceHintPathRewrite.targets'

Add-Type -AssemblyName 'Microsoft.Build, Version=4.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a'

$ProjectCollection = [Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection

$BuildProject = $ProjectCollection.GetLoadedProjects($Project.FullName) |
    Select-Object -First 1

$TargetPattern = '(^|\\)' + [Regex]::Escape($TargetFileName) + '$'

$Dirty = $false

$TargetImports = @(
    $BuildProject.Xml.Imports | 
        Where-Object { $_.Project -match $TargetPattern }
)

if ($TargetImports.Length -gt 1) {
    Write-Warning "File '$TargetFileName' is imported multiple times."
}

if ($TargetImports.Length -eq 0) {
    $Import = $BuildProject.Xml.CreateImportElement($TargetFileName)
    $BuildProject.Xml.AppendChild($Import)
    $Dirty = $true
}

$prjBuildActionNone = 0 # http://msdn.microsoft.com/en-us/library/aa983962.aspx
$ProjectItem = $Project.ProjectItems.Item($TargetFileName)
$Property = $ProjectItem.Properties.Item('BuildAction')
if ($Property.Value -ne $prjBuildActionNone) {
	$Property.Value = $prjBuildActionNone
	$Dirty = $true
}

if ($Dirty) {
	$Project.Save()
}

# mark dependency as development

$PackagesConfigPath = Join-Path -Path (Split-Path $Project.FullName) -ChildPath packages.config
$XPath = "packages/package[@id='$($package.id)' and not(@developmentDependency='true')]"
$PackageReference = Select-Xml -Path $PackagesConfigPath -XPath $XPath |
    Select-Object -First 1

if ($PackageReference) {
    $PackageReference.Node.SetAttribute('developmentDependency', 'true')
    $PackageReference.Node.OwnerDocument.Save($PackageReference.Path)
}
