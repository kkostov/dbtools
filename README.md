## dbtools

A set of powershell scripts designed to facilitate some database versioning workflows.

The tool wraps around SQL Server's sqlpackage (to extract and publish DAC schema packages) and flyway by FuseBox to manage schema versions.

## Usage

```
.\dbtools.ps1 -serverName localhost -dbname UltraGendaPro -userName ugdbm -password ebm4589 -action validate -version 8.0.2
```

## Command reference

### Extract

The `extract` action creates a schema snapshot (DAC).

### Publish

The `publish` action imports a schema snapshot by incrementally updating the database schema to match the package.
If the database doesn't exist, it will be created.


### Baseline

Initialializes a database schema version system. This allows an existing database to be put under schema version control.

(FlyWay info)[https://flywaydb.org/documentation/commandline/baseline]

### Info

Prints information regarding the database schema version.

(FlyWay info)[https://flywaydb.org/documentation/commandline/info]


### Migrate

Migrates the schema to the latest version. The database will be baselined if it was not already done in the past by creating the schema_version table.

(FlyWay info)[https://flywaydb.org/documentation/commandline/migrate]


### Validate

Validates the applied migrations against the available ones by checking the state of the "migrations" folder against the state of the database.

(FlyWay info)[https://flywaydb.org/documentation/commandline/validate]


### Repair

Repairs the schema version metadata of the database.

(FlyWay info)[https://flywaydb.org/documentation/commandline/repair]






