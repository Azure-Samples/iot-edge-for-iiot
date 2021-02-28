use telemetry
DROP EXTERNAL STREAM DeviceDataTable
DROP EXTERNAL STREAM dashboardsOPCUAInputStream
DROP DATABASE SCOPED CREDENTIAL dashboardsSQLCredential
DROP EXTERNAL DATA SOURCE telemetryDbServer
DROP EXTERNAL DATA SOURCE dashboardsInput
DROP External file format dashboardsInputFileFormat
DROP MASTER KEY  
EXEC sys.sp_drop_streaming_job @name=N'dashboardsStreamFromHubIntoTable'
drop trigger ddl_trig_telemetrydb ON ALL SERVER