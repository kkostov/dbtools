## dbtools

A set of powershell scripts designed to facilitate some database versioning workflows.

The tool wraps around SQL Server's sqlpackage (to extract and publish DAC schema packages) and flyway by FuseBox to manage schema versions.

## Usage

```
.\dbtools.ps1 -serverName localhost -dbname MyDatabase -userName usr -password pass -action validate -version 8.0.2
```

* serverName: the hostname of the sql server to connect to
* dbname: name of the database to be maintained or created
* userName: username for SQL authentication
* password: password for SQL authentication
* action: the action to perform
* version: the schema version to target for the specified action
* snapshotsFolder: the folder where snapshots will be created or read from
* migrationsFolder: the folder where migrations will be read from

Available actions

* extract - creates a DAC package with the schema of a database. (read more)[https://msdn.microsoft.com/en-us/library/hh550080(v=vs.103).aspx]
* publish - incrementally updates a database schema to match the schema of a source .dacpac file; if the database doesn't exist, it will be created.
* info - attempts to read the migrations metadata (schema_version table) of the target database. (FlyWay info)[https://flywaydb.org/documentation/commandline/info]
* baseline - Initialializes a database schema version system. This allows an existing database to be put under schema version control. (FlyWay info)[https://flywaydb.org/documentation/commandline/baseline]
* migrate - Migrates the schema to the latest version. The database will be baselined if it was not already done in the past by creating the schema_version table. (FlyWay info)[https://flywaydb.org/documentation/commandline/migrate] 
* validate - Validates the applied migrations against the available ones by checking the state of the "migrations" folder against the state of the database. (FlyWay info)[https://flywaydb.org/documentation/commandline/validate] 
* repair - Repairs the schema version metadata of the database. (FlyWay info)[https://flywaydb.org/documentation/commandline/repair]