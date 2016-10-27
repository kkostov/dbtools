
# Prerequisites: Set-ExecutionPolicy -ExecutionPolicy:Unrestricted -Scope:LocalMachine

# The sqlpackage utility must be available on the host running this script (data tools)

Param(
[string]$serverName, 
[string]$dbname, 
[string]$userName, 
[string]$password,
[string]$version,
[string]$action,
[string]$snapshotsFolder = './snapshots',
[string]$migrationsFolder = './migrations'
)


function PrintInfo() {
    if($version -eq "") {
     throw "The version argument is mandatory when importing a database schema"
    }
    Write-Host "connecting to $serverName\$dbname for version: $version"
}

function GetSqlPackageExePath() {
    # Find the latest sqlpackage.exe
    $last_version = 0;
    for($i = 100; $i -le 190; $i += 10)
    {
      $file_name = "C:\Program Files (x86)\Microsoft SQL Server\" + $i + "\DAC\bin\sqlpackage.exe";
      If (Test-Path $file_name) {
        $last_version = $i;
      }
    }

    if($last_version -eq 0) {
      throw "The sqlpackage.exe was not found on the local machine. Install SQL Data Tools required to manage DACs."
    }
    $file_name = "C:\Program Files (x86)\Microsoft SQL Server\" + $last_version + "\DAC\bin\sqlpackage.exe";
    return $file_name
}

function GetFlyWayExePath() {
    # expecting flyway to be in the current folder
    # download version from https://flywaydb.org/getstarted/download
    $file_name = "flyway-4.0.3/flyway.cmd";
    return $file_name;
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
  $scriptpath = GetFullVersionFolder

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
    PrintInfo
    #prepare the output folder
    $scriptpath = $snapshotsFolder
    New-Item -ItemType Directory -Force -Path $scriptpath
    $dacFilePath = Join-Path $scriptpath "\$dbname-$version.dacpac"

    $sqlpackageExe = GetSqlPackageExePath
    # Assign the correct arguments depending if we are using sql server login
    $args
    if($userName -eq "" -and $password -eq "") {
     $args = "/Action:Extract", "/SourceServerName:$serverName", "/SourceDatabaseName:$dbname", "/TargetFile:$dacFilePath", "/p:ExtractReferencedServerScopedElements=False"
    } else {
     $args = "/Action:Extract", "/SourceServerName:$serverName", "/SourceDatabaseName:$dbname",  "/SourceUser:$userName", "/SourcePassword:$password", "/TargetFile:$dacFilePath", "/p:ExtractReferencedServerScopedElements=False"
    }

    & $sqlpackageExe $args
}


function PublishDbFromDAC()
{
    PrintInfo
    #prepare the output folder
    $scriptpath = $snapshotsFolder
    New-Item -ItemType Directory -Force -Path $scriptpath
    $dacFilePath = Join-Path $scriptpath "\$dbname-$version.dacpac"

    # Run sqlpackage to extract DACPAC  
    $sqlpackageExe = GetSqlPackageExePath
    # Assign the correct arguments depending if we are using sql server login
    $args
    if($userName -eq "" -and $password -eq "") {
     $args = "/Action:Publish", "/TargetServerName:$serverName", "/TargetDatabaseName:$dbname", "/SourceFile:$dacFilePath"
    } else {
     $args = "/Action:Publish", "/TargetServerName:$serverName", "/TargetDatabaseName:$dbname",  "/TargetUser:$userName", "/TargetPassword:$password", "/SourceFile:$dacFilePath"
    }

    & $sqlpackageExe $args
}


function FlyWayAction($flyWayAction)
{
  $exec = GetFlyWayExePath
  if($userName -eq "" -and $password -eq "") {
    throw "Migrations are not supported using Windows Authentication. Enable SQL Server authentication mode by passing username and a password"
  }

  if($serverName -eq ".") {
    #the flyway url doesnt support . so dirty tweaking to localhost if not set explicitly
    $serverName = "localhost"
  }

  #flyWayAction: migrate | info
    switch($flyWayAction) {
     "info" {
        $args = "-user=$userName", "-password=$password", "-url=jdbc:jtds:sqlserver://$serverName/$dbname", "-locations=filesystem:$migrationsFolder", "info"
        & $exec $args
     }
     "baseline" {
        $args = "-user=$userName", "-password=$password", "-url=jdbc:jtds:sqlserver://$serverName/$dbname", "-locations=filesystem:$migrationsFolder", "-baselineDescription=baseline", "baseline"
        if($version -ne "") {
            $args += "-baselineVersion=$version"
        }
        & $exec $args
     }
     "migrate" {
        $args = "-user=$userName", "-password=$password", "-url=jdbc:jtds:sqlserver://$serverName/$dbname", "-locations=filesystem:$migrationsFolder", "migrate"
        if($version -ne "") {
            $args += "-target=$version"
        }
        & $exec $args
     }
     "validate" {
        $args = "-user=$userName", "-password=$password", "-url=jdbc:jtds:sqlserver://$serverName/$dbname", "-locations=filesystem:$migrationsFolder", "validate"
        if($version -ne "") {
            $args += "-target=$version"
        }
        & $exec $args
     }
     "repair" {
        $args = "-user=$userName", "-password=$password", "-url=jdbc:jtds:sqlserver://$serverName/$dbname", "-locations=filesystem:$migrationsFolder", "repair"
        & $exec $args
     }
     default {throw "Unsupported flyWayAction! '$flyWayAction'"}
    }
}

switch($action) {
  "script" { GetDbScript }
  "extract" { CreateDbDAC } #  Creates a schema snapshot (.dacpac)
  "publish" { PublishDbFromDAC } # Incrementally updates a database schema to match the schema of a source .dacpac file
  "info" { FlyWayAction("info") }
  "baseline" { FlyWayAction("baseline") }
  "migrate" { FlyWayAction("migrate") }
  "validate" { FlyWayAction("validate") }
  "repair" { FlyWayAction("repair") }
  default {throw "Invalid action. Supported options are: script, export, import."}
}
