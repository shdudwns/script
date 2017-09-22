$POCKETMINE_BRANCH = "master"

function downloadFile($url, $targetFile)
{ 
    "Downloading $url"
    $uri = New-Object "System.Uri" "$url"
    $request = [System.Net.HttpWebRequest]::Create($uri) 
    $request.set_Timeout(15000) #15 second timeout 
    $response = $request.GetResponse() 
    $totalLength = [System.Math]::Floor($response.get_ContentLength()/1024) 
    $responseStream = $response.GetResponseStream() 
    $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $targetFile, Create 
    $buffer = new-object byte[] 10KB 
    $count = $responseStream.Read($buffer,0,$buffer.length) 
    $downloadedBytes = $count 
    while ($count -gt 0) 
    { 
        [System.Console]::CursorLeft = 0 
        [System.Console]::Write("Downloaded {0}K of {1}K", [System.Math]::Floor($downloadedBytes/1024), $totalLength) 
        $targetStream.Write($buffer, 0, $count) 
        $count = $responseStream.Read($buffer,0,$buffer.length) 
        $downloadedBytes = $downloadedBytes + $count 
    } 
    "`nFinished Download"
    $targetStream.Flush()
    $targetStream.Close() 
    $targetStream.Dispose() 
    $responseStream.Dispose() 
}

function Extract-File {
    param (
        [string]$file,
        [string]$target
    )

    [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem') | Out-Null
    [System.IO.Compression.ZipFile]::ExtractToDirectory($file, $target)
}

function New-Zip
{
  param([string]$zipfilename)
  set-content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
  (dir $zipfilename).IsReadOnly = $false
}

Function New-ZipArchive {

<#
.Synopsis
Create a zip archive from a folder.
.Description
This command will create a zip file from the specified path. The path will be a top level folder in the archive.
.Parameter Path
The top level folder to be archived. This parameter has aliases of PSPath and Source.
.Parameter OutputPath
The filename for the zip file to be created. If it already exists, the command will not run, unless you use -Force. This parameter has aliases of Zip and Target.
.Parameter Force
Delete the existing zip file and create a new one.
.Example
PS C:\> New-ZipArchive -path c:\work -outputpath e:\workback.zip 
Create a new zip file called WorkBack.zip. The top level folder in the archive will be Work.
.Example
PS C:\> $dscres = Get-DSCResource | Select -expandproperty Module -unique | where {$_.path -notmatch "windows\\system32"}
PS C:\> $dscres | foreach {
 $out = "{0}_{1}.zip" -f $_.Name,$_.Version
 $zip = Join-Path -path "E:\DSC\ZipResource" -ChildPath $out
 New-ZipArchive -path $_.ModuleBase -OutputPath $zip -Passthru -force
 }
 The first command gets a unique list of modules for all DSC resources filtering out anything under System32. The second command creates a zip file for each module using the naming format modulename_version.zip.
.Notes
Version      : 1.0
Last Updated : February 2, 2015
Learn more about PowerShell:
http://jdhitsolutions.com/blog/essential-powershell-resources/
  ****************************************************************
  * DO NOT USE IN A PRODUCTION ENVIRONMENT UNTIL YOU HAVE TESTED *
  * THOROUGHLY IN A LAB ENVIRONMENT. USE AT YOUR OWN RISK.  IF   *
  * YOU DO NOT UNDERSTAND WHAT THIS SCRIPT DOES OR HOW IT WORKS, *
  * DO NOT USE IT OUTSIDE OF A SECURE, TEST SETTING.             *
  ****************************************************************
#>

[cmdletbinding(SupportsShouldProcess)]
param(
[Parameter(Position=0,Mandatory,
HelpMessage="Enter the folder path to be archived.")]
[Alias("PSPath","Source")]
[String]$Path,
[Parameter(Position=1,Mandatory,
HelpMessage="Enter the path and filename for the zip file")]
[Alias("zip","Target")]
[ValidateNotNullorEmpty()]
[String]$OutputPath,
[Switch]$Force,
[switch]$Passthru
)

Write-Verbose "Starting $($MyInvocation.Mycommand)"  
Write-Verbose "Using bound parameters:"
Write-verbose  ($MyInvocation.BoundParameters| Out-String).Trim()

if ($Force -AND (Test-Path -path $OutputPath)) {
    Write-Verbose "Testing for existing file and deleting it"
    Remove-Item -Path $OutputPath
}
     
if(-NOT (Test-Path $OutputPath)) {
    Write-Verbose "Creating $OutputPath" 
    Try {
        #create an empty zip file
        Set-Content -path $OutputPath -value ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18)) -ErrorAction Stop
        
        #get the zip file object
        $zipfile = $OutputPath | Get-Item -ErrorAction Stop

        #make sure it is not set to ReadOnly
        write-verbose "Setting isReadOnly to False"
        $zipfile.IsReadOnly = $false  
    }
    Catch {
        Write-Warning "Failed to create $outputpath"
        write-Warning $_.exception.message
        #bail out
        Return
    }
} #if not test zip file path
else {
    Write-Warning "The file $OutputPath already exists. Please delete or use -Force and try again."
    
    #bail out
    Return
}

if ($PSCmdlet.ShouldProcess($Path)) {
    Write-Verbose "Creating Shell.Application"
    $shellApp = New-Object -com shell.application

    Write-Verbose "Using namespace $($zipfile.fullname)" 
    $zipPackage = $shellApp.NameSpace($zipfile.fullname)

    write-verbose ($zipfile | Out-String)

    $target = Get-Item -Path $Path

    $zipPackage.CopyHere($target.FullName) 

    If ($passthru) {
        #Pause enough to give the zip file a chance to update
        Start-Sleep -Milliseconds 200
        Get-Item -Path $Outputpath
    }
} #should process

Write-Verbose "Ending $($MyInvocation.Mycommand)"

}

function copy_obj {
	Param(
	  [string]$Source = 'D:\AutomatedServices\Exchange-Skripte\',  
	  [string]$Destination = '\\bdr.de\daten\Medien\Software\Freigegeben\Lizenzpflichtig\microsoft\exchange\Scripts\',
	  [switch]$Overwrite
	)

	# ensure trailing \
	if(!($Source.EndsWith('\'))) {$Source = $Source +'\'}
	if(!($Destination.EndsWith('\'))) {$Destination = $Destination +'\'}

	Write-Output "Copy from: $($Source)"
	Write-Output "Copy to  : $($Destination)"

	# Copy files that have changed during the last 180 days
	$since = (Get-Date).AddDays(-180)

	# Fetch files that need to be copie
	$items = Get-ChildItem $Source -Recurse

	Write-Verbose "$($items.Count) files found"

	foreach ($item in $items) {
	    Write-Verbose "Working on: $($item.FullName)"
	    $dir = $item.DirectoryName.Replace($Source,$Destination)
	    $target = $item.FullName.Replace($Source,$Destination)

	    # Create target directory, if not exists
	    if (!(Test-Path($dir))) { 
		Write-Verbose "Creating destination folder: $($dir)"
		mkdir $dir | Out-Null
	    }

	    # Copy files
	    if (!(Test-Path($target))) {
		Write-Verbose "Copy: $($item.FullName)"
		Copy-Item -Path $item.FullName -Destination $target -Recurse -Force | Out-Null
	    }
	    else {
		if($Overwrite) {
		    Write-Verbose "Overwrite: $($item.FullName)"
		    Copy-Item -Path $item.FullName -Destination $target -Recurse -Force | Out-Null
		}
		else {
		    Write-Verbose "Skip: $($item.FullName)"
		}
	    }
	}
}

del .\*.phar
del .\*.zip

if (Test-Path(".\pmmp")) {
	Remove-Item .\pmmp -Recurse -Force
}
if (Test-Path(".\PocketMine-MP")) {
	Remove-Item .\PocketMine-MP -Recurse -Force
}
if (Test-Path(".\PocketMine")) {
	Remove-Item .\PocketMine -Recurse -Force
}
echo " "

echo "Downloading PocketMine-MP"
git clone https://github.com/pmmp/PocketMine-MP -b $POCKETMINE_BRANCH
ren "PocketMine-MP" "pmmp"

cd "pmmp"

cd .\src
echo " "
echo "Downloading PocketMine-SPL"
git clone https://github.com/pmmp/PocketMine-SPL
Remove-Item .\spl -Recurse -Force
ren "PocketMine-SPL" "spl"

echo " "
echo "Downloading RakLib"
git clone https://github.com/pmmp/RakLib
# ren "RakLib" "raklib"

cd .\pocketmine\lang
echo " "
echo "Downloading PocketMine-Language"
git clone https://github.com/pmmp/PocketMine-Language
Remove-Item .\locale -Recurse -Force
ren "PocketMine-Language" "locale"

cd ..\..\..
echo " "
echo "Downloading PHP Binary"
git clone https://github.com/CompilePhar/bin

echo " "
echo "Downloading DevTools"
$url = "https://jenkins.pmmp.io/job/PocketMine-MP/lastSuccessfulBuild/artifact/*zip*/archive.zip"
$dir = get-location
$targetFile = "$dir\jenkins.zip"
downloadFile $url $targetFile

# Extract Zip
md plugins
$dir = get-location
$dir = "$dir"
Extract-File $targetFile $dir

copy "$dir\archive\DevTools.phar" ".\plugins"

$dir = get-location

echo " "
echo "Downloading Compiler"
cd .\plugins
git clone https://github.com/CompilePhar/Compiler
cd ..

echo " "
echo "Installing Composer"
&.\bin\php\php.exe .\bin\composer.phar install


copy "$dir\src\pocketmine\resources\pocketmine.yml" "$dir\pocketmine.yml"

echo " "
echo "Writing server.properties"

New-Item "$dir\server.properties"
$pro = "$dir\server.properties"

function write_properties($line)
{
	$line | Out-File -filePath $pro -Append -Encoding ascii
}

write_properties "motd=Minecraft: PE Server
server-port=19132
white-list=off
announce-player-achievements=on
spawn-protection=16
max-players=20
allow-flight=off
spawn-animals=on
spawn-mobs=on
gamemode=0
force-gamemode=off
hardcore=off
pvp=on
difficulty=1
generator-settings=
level-name=world
level-seed=
level-type=DEFAULT
enable-query=on
enable-rcon=off
rcon.password=fqd5QIn4bp
auto-save=on
view-distance=8"

New-Item "$dir\server.cmd"
$pro = "$dir\server.cmd"
function write_start_server($line)
{
	$line | Out-File -filePath $pro -Append -Encoding ascii
}

write_start_server("@echo off
TITLE PocketMine-MP server software for Minecraft: Pocket Edition
cd /d %~dp0

if exist bin\php\php.exe (
	set PHPRC=""
	set PHP_BINARY=bin\php\php.exe
) else (
	set PHP_BINARY=php
)

if exist PocketMine-MP.phar (
	set POCKETMINE_FILE=PocketMine-MP.phar
) else (
	if exist src\pocketmine\PocketMine.php (
		set POCKETMINE_FILE=src\pocketmine\PocketMine.php
	) else (
		echo Couldn't find a valid PocketMine-MP installation
		pause
		exit 1
	)
)

%PHP_BINARY% -c bin\php %POCKETMINE_FILE% %*")

echo " "
echo "Starting PocketMine Server..."
echo " "


.\server.cmd

echo " "

cd ..
echo "Copying PocketMine Server Software For Windows"
$dir = get-location
md PocketMine
md PocketMine\bin
md PocketMine\vendor
<#copy "$dir\pmmp\bin\*" "$dir\PocketMine\bin\" -Force
copy "$dir\pmmp\bin\php\*" "$dir\PocketMine\bin\php" -Force
copy "$dir\pmmp\vendor\*" "$dir\PocketMine\vendor" -Force
copy "$dir\pmmp\vendor\composer\*" "$dir\PocketMine\vendor\composer" -Force#>
copy_obj "$dir\pmmp\bin\" "$dir\PocketMine\bin\"
copy_obj "$dir\pmmp\vendor\" "$dir\PocketMine\vendor\"
copy "$dir\pmmp\start.cmd" "$dir\PocketMine" -Force
copy "$dir\pmmp\start.ps1" "$dir\PocketMine" -Force
md "$dir\PocketMine\plugins"
copy "$dir\pmmp\plugins\DevTools\*.phar" "$dir\PocketMine\" -Force
copy "$dir\pmmp\archive\DevTools.phar" "$dir\PocketMine\plugins" -Force

Get-ChildItem "$dir\pmmp\plugins\DevTools\" -Filter *.phar |
% {
    foreach ($fileInfo in $_)
    {
		ren "$dir\PocketMine\$fileInfo" "PocketMine-MP.phar"
    } 
}

New-ZipArchive "$dir\PocketMine\" "$dir\PocketMine.zip"
echo "It will make zip..."
start-sleep 10

echo " "
echo "Copying Artifacts"
echo " "
copy "$dir\pmmp\plugins\DevTools\*.phar" "$dir\"

echo "Done?"
