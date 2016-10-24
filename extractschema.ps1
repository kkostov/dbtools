# Usage: -action "export" -version "8.0.0"  -serverName "SERVERNAME" -dbname "DATABASENAME" -userName "USERNAME" -password "PASSWORD"
# when userName and password are ommited, windows authentication is used


# Prerequisites: Set-ExecutionPolicy -ExecutionPolicy:Unrestricted -Scope:LocalMachine

Param(
[string]$serverName, 
[string]$dbname, 
[string]$userName, 
[string]$password,
[string]$version,
[string]$action
)


function GetExtractionFolder() {
  $t = Get-Date -Format "yyyymmddHHMMss"
  $foldername = "db_extract_$t"
  $dbextractfolder =  $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$foldername")
  Write-Host "using path $dbextractfolder"
  return $dbextractfolder
}

function GeVersionFolder() {
  $foldername = "db_extract_$version"
  $dbextractfolder =  $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$foldername")
  Write-Host "using path $dbextractfolder"
  return $dbextractfolder
}

function PrintInfo() {
    Write-Host "Using database $dbname on server $serverName"
}

function GetDbScript()
{
if($version -eq "") {
 throw "The version argument is mandatory when importing a database schema"
}

  PrintInfo
  [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | Out-Null
  [System.Reflection.Assembly]::LoadWithPartialName("System.Data") | Out-Null
  $srv = new-object "Microsoft.SqlServer.Management.SMO.Server" $serverName

  # if username and password are empty, use windows authentication
  if($userName -eq "" -and $password -eq "") {
    $srv.ConnectionContext.LoginSecure = $true
  } else {
    $srv.ConnectionContext.LoginSecure = $false
    $srv.ConnectionContext.set_Login($userName)
    $srv.ConnectionContext.set_Password($password)
  }
 
  $srv.SetDefaultInitFields([Microsoft.SqlServer.Management.SMO.View], "IsSystemObject")
  $db = New-Object "Microsoft.SqlServer.Management.SMO.Database"
  $db = $srv.Databases[$dbname]

  if($db -eq $null) {
    throw "The specified database name '$dbname' does not exist."
  }

  $scr = New-Object "Microsoft.SqlServer.Management.Smo.Scripter"
  $deptype = New-Object "Microsoft.SqlServer.Management.Smo.DependencyType"
  $scr.Server = $srv
  $options = New-Object "Microsoft.SqlServer.Management.SMO.ScriptingOptions"
  $options.AllowSystemObjects = $false
  $options.IncludeDatabaseContext = $true
  $options.IncludeIfNotExists = $false
  $options.ClusteredIndexes = $true
  $options.Default = $true
  $options.DriAll = $true
  $options.Indexes = $true
  $options.NonClusteredIndexes = $true
  $options.IncludeHeaders = $false
  $options.ToFileOnly = $true
  $options.AppendToFile = $true
  $options.ScriptDrops = $false

  # Set options for SMO.Scripter
  $scr.Options = $options

  # Set the extraction path
  $scriptpath = GeVersionFolder

  #=============
  # Tables
  #=============
  $options.FileName = $scriptpath + "\$($dbname)_tables.sql"
  New-Item $options.FileName -type file -force | Out-Null
  Foreach ($tb in $db.Tables)
  {
   If ($tb.IsSystemObject -eq $FALSE)
   {
    $smoObjects = New-Object Microsoft.SqlServer.Management.Smo.UrnCollection
    $smoObjects.Add($tb.Urn)
    $scr.Script($smoObjects)
   }
  }

  #=============
  # Views
  #=============
  $options.FileName = $scriptpath + "\$($dbname)_views.sql"
  New-Item $options.FileName -type file -force | Out-Null
  $views = $db.Views | where {$_.IsSystemObject -eq $false}
  Foreach ($view in $views)
  {
    if ($views -ne $null)
    {
     $scr.Script($view)
   }
  }

  #=============
  # StoredProcedures
  #=============
  $StoredProcedures = $db.StoredProcedures | where {$_.IsSystemObject -eq $false}
  $options.FileName = $scriptpath + "\$($dbname)_stored_procs.sql"
  New-Item $options.FileName -type file -force | Out-Null
  Foreach ($StoredProcedure in $StoredProcedures)
  {
    if ($StoredProcedures -ne $null)
    {
     $scr.Script($StoredProcedure)
   }
  }

  #=============
  # Functions
  #=============
  $UserDefinedFunctions = $db.UserDefinedFunctions | where {$_.IsSystemObject -eq $false}
  $options.FileName = $scriptpath + "\$($dbname)_functions.sql"
  New-Item $options.FileName -type file -force | Out-Null
  Foreach ($function in $UserDefinedFunctions)
  {
    if ($UserDefinedFunctions -ne $null)
    {
     $scr.Script($function)
   }
  }

  #=============
  # DBTriggers
  #=============
  $DBTriggers = $db.Triggers
  $options.FileName = $scriptpath + "\$($dbname)_db_triggers.sql"
  New-Item $options.FileName -type file -force | Out-Null
  foreach ($trigger in $db.triggers)
  {
    if ($DBTriggers -ne $null)
    {
      $scr.Script($DBTriggers)
    }
  }

  #=============
  # Table Triggers
  #=============
  $options.FileName = $scriptpath + "\$($dbname)_table_triggers.sql"
  New-Item $options.FileName -type file -force | Out-Null
  Foreach ($tb in $db.Tables)
  {
    if($tb.triggers -ne $null)
    {
      foreach ($trigger in $tb.triggers)
      {
        $scr.Script($trigger)
      }
    }
  }
}


function CreateDbDAC()
{
if($version -eq "") {
 throw "The version argument is mandatory when importing a database schema"
}

    PrintInfo
    # Find the latest sqlpackage.exe
    $last_version = 0;
    for($i = 100; $i -le 190; $i += 10)
    {
      $file_name = "C:\Program Files (x86)\Microsoft SQL Server\" + $i + "\DAC\bin\sqlpackage.exe";
      If (Test-Path $file_name) {
        $last_version = $i;
      }
    }

    #prepare the output folder
    $scriptpath = GeVersionFolder
    New-Item -ItemType Directory -Force -Path $scriptpath

    # Run sqlpackage to extract DACPAC
    If ($last_version -gt 0) {
      $msg = "SqlPackage version: " + $last_version;
      Write-Output $msg;
      # Set the extraction path
      $file_name = "C:\Program Files (x86)\Microsoft SQL Server\" + $last_version + "\DAC\bin\sqlpackage.exe";
      if($userName -eq "" -and $password -eq "") {
        & $file_name `/Action:Extract /OverwriteFiles:True /SourceServerName:$serverName /SourceDatabaseName:$dbname /TargetFile:$scriptpath\$dbname.dacpac /p:ExtractReferencedServerScopedElements=False`
      } else {
        & $file_name `/Action:Extract /OverwriteFiles:True /SourceServerName:$serverName /SourceDatabaseName:$dbname /SourceUser:$userName /SourcePassword:$password /TargetFile:$scriptpath\$dbname.dacpac /p:ExtractReferencedServerScopedElements=False`
      }
    }
}

function ImportDbFromDAC()
{

#a version to import must be specified
if($version -eq "") {
 throw "The version argument is mandatory when importing a database schema"
}

  PrintInfo
    # Find the latest sqlpackage.exe
    $last_version = 0;
    for($i = 100; $i -le 190; $i += 10)
    {
      $file_name = "C:\Program Files (x86)\Microsoft SQL Server\" + $i + "\DAC\bin\sqlpackage.exe";
      If (Test-Path $file_name) {
        $last_version = $i;
      }
    }

    #prepare the output folder
    $scriptpath = GeVersionFolder
    $dacFilePath = "$scriptpath\$dbname.dacpac"
    # Run sqlpackage to extract DACPAC
    If ($last_version -gt 0) {
      $msg = "SqlPackage version: " + $last_version + ", using DAC file $dacFilePath";
      Write-Output $msg;
      # Set the extraction path
      $file_name = "C:\Program Files (x86)\Microsoft SQL Server\" + $last_version + "\DAC\bin\sqlpackage.exe";
      if($userName -eq "" -and $password -eq "") {
        & $file_name `/Action:Publish /TargetServerName:$serverName /TargetDatabaseName:$dbname /SourceFile:$dacFilePath`
      } else {
        & $file_name `/Action:Publish /TargetServerName:$serverName /TargetDatabaseName:$dbname /TargetUser:$userName /TargetPassword:$password /SourceFile:$dacFilePath`
      }
    }
}


switch($action) {
  "export" { CreateDbDAC }
  "import" { ImportDbFromDAC }
  default {Write-Host "Invalid action. Please specify if you wish to import or export a database schema"}
}
