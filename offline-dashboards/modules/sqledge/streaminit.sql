SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
if exists(select 1 from sys.server_triggers where name=N'ddl_trig_telemetrydb')
    drop trigger ddl_trig_telemetrydb ON ALL SERVER
go
CREATE TRIGGER ddl_trig_telemetrydb 
ON ALL SERVER 
FOR CREATE_DATABASE 
AS 
    declare @dbname SYSNAME 
    SELECT @dbname=EVENTDATA().value('(/EVENT_INSTANCE/DatabaseName)[1]','nvarchar(max)') 

if (@dbname=N'telemetry') 
begin 
exec('
    use ' + @dbname + '

    if not exists(select 1 from sys.external_file_formats where name = ''dashboardsInputFileFormat'')
        Create External file format dashboardsInputFileFormat WITH (format_type = JSON)

    if not exists(select 1 from sys.external_data_sources where name = ''dashboardsInput'')
        CREATE EXTERNAL DATA SOURCE dashboardsInput WITH (LOCATION = ''edgehub://'')

    if not exists(select 1 from sys.external_streams where name = ''dashboardsOPCUAInputStream'')
        CREATE EXTERNAL STREAM dashboardsOPCUAInputStream WITH ( DATA_SOURCE = dashboardsInput, FILE_FORMAT = dashboardsInputFileFormat, LOCATION = N''OPCUAData'', INPUT_OPTIONS = N'''', OUTPUT_OPTIONS = N'''')

    if not exists(select 1 from sys.symmetric_keys)
        CREATE MASTER KEY ENCRYPTION BY PASSWORD = ''Password_54321'';

    if not exists(select 1 from sys.database_scoped_credentials where name = ''dashboardsSQLCredential'')
        CREATE DATABASE SCOPED CREDENTIAL dashboardsSQLCredential WITH IDENTITY = ''sa'', SECRET = ''Password_54321''
    else
        ALTER DATABASE SCOPED CREDENTIAL dashboardsSQLCredential WITH IDENTITY = ''sa'', SECRET = ''Password_54321''

    if not exists(select 1 from sys.external_data_sources where name = ''telemetryDbServer'')
        CREATE EXTERNAL DATA SOURCE telemetryDbServer WITH (LOCATION = ''sqlserver://tcp:.,1433'',CREDENTIAL = dashboardsSQLCredential)

    if not exists(select 1 from sys.external_streams where name = ''DeviceDataTable'')
        CREATE EXTERNAL STREAM DeviceDataTable WITH (DATA_SOURCE = telemetryDbServer,LOCATION = N''telemetry.dbo.DeviceData'',INPUT_OPTIONS = N'''',OUTPUT_OPTIONS = N'''')

    if not exists(select 1 from sys.external_streaming_jobs where name = ''dashboardsStreamFromHubIntoTable'')
        EXEC sys.sp_create_streaming_job @name=N''dashboardsStreamFromHubIntoTable'',
        @statement= N''Select ContentMask, NodeId, ServerTimestamp, SourceTimestamp, StatusCode, Status, ApplicationUri, Timestamp, Value.Type as [ValueType], Value.Body as Value, substring(NodeId,regexmatch(NodeId,''''=(?:.(?!=))+$'''')+1,len(NodeId)-regexmatch(NodeId,''''=(?:.(?!=))+$'''')) as DataPoint, substring(NodeId,1, regexmatch(NodeId,''''\#(?:.(?!\#))+$'''')-1) as Asset, SourceTimestamp as [time] into DeviceDataTable from dashboardsOPCUAInputStream''

    if (select status from sys.external_streaming_jobs where name = ''dashboardsStreamFromHubIntoTable'') in (0,4)
        exec sys.sp_start_streaming_job @name=N''dashboardsStreamFromHubIntoTable''
') 
end
GO  