# Usage: -serverName "SERVERNAME" -dbname "DATABASENAME" -userName "USERNAME" -password "PASSWORD"
# when userName and password are ommited, windows authentication is used


# Prerequisites: Set-ExecutionPolicy -ExecutionPolicy:Unrestricted -Scope:LocalMachine

Param(
[string]$serverName, 
[string]$dbname, 
[string]$userName, 
[string]$password
)


function GetExtractionFolder() {
  $t = Get-Date -Format "yyyymmddHHMMss"
  $foldername = "db_extract_$t"
  $dbextractfolder =  $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath("$foldername")
  Write-Host "using path $dbextractfolder"
  return $dbextractfolder
}


function GetDbScript()
{
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
  $scriptpath = GetExtractionFolder

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

GetDbScript