#load "GZipCompression.csx"
#load "AzureLogAnalytics.csx"
#load "CertGenerator.csx"
#load "Constants.csx"
#load "MetricsModel.csx"

#r "Newtonsoft.Json"

using System;
using System.Text;
using System.Linq;
using System.Collections.Generic;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.EventHubs;
using Microsoft.Extensions.Logging;

public static async Task Run([EventHubTrigger("%EventHubName%", Connection = "EventHubConnectionString", ConsumerGroup = "%EventHubConsumerGroup%")] EventData eventHubMessages, ILogger log)
{   
    string _hubResourceId = Environment.GetEnvironmentVariable("HubResourceId");
    string _workspaceId = Environment.GetEnvironmentVariable("WorkspaceId");
    string _workspaceKey = Environment.GetEnvironmentVariable("WorkspaceKey");
    string _workspaceApiVersion = Environment.GetEnvironmentVariable("WorkspaceApiVersion");
    bool _compressForUpload = Convert.ToBoolean(Environment.GetEnvironmentVariable("CompressForUpload"));
    string _metricsEncoding = Environment.GetEnvironmentVariable("MetricsEncoding");

    log.LogInformation($"hubResourceId: {_hubResourceId}");
    log.LogInformation($"workspaceId: {_workspaceId}");
    log.LogInformation($"workspaceKey: {_workspaceKey}");
    log.LogInformation($"workspaceApiVersion: {_workspaceApiVersion}");
    log.LogInformation($"compressForUpload: {_compressForUpload}");
    log.LogInformation($"metricsEncoding: {_metricsEncoding}");
    //log.LogInformation($"C# IoT Hub trigger function processed a message: {eventHubMessages.Body}");
    
    try
    {
        log.LogInformation("CollectMetrics function started.");

        // Decompress if encoding is gzip
        string metricsString = string.Empty;
        if (string.Equals(_metricsEncoding, "gzip", StringComparison.OrdinalIgnoreCase))
            metricsString = GZipCompression.Decompress(eventHubMessages.Body.ToArray());
        else
            metricsString = Encoding.UTF8.GetString(eventHubMessages.Body);
        
        //log.LogInformation($"metrics string: {metricsString}");

        IoTHubMetric[] iotHubMetrics = JsonConvert.DeserializeObject<IoTHubMetric[]>(metricsString);
        IEnumerable<LaMetric> metricsToUpload = iotHubMetrics.Select(m => new LaMetric(m, string.Empty));
        LaMetricList metricList = new LaMetricList(metricsToUpload);

        // initialize log analytics class
        AzureLogAnalytics logAnalytics = new AzureLogAnalytics(
            workspaceId: _workspaceId,
            workspaceKey: _workspaceKey,
            logger: log,
            apiVersion: _workspaceApiVersion);

        bool success = false;
        for (int i = 0; i < Constants.UploadMaxRetries && (!success); i++)
        {
            // TODO: split up metricList so that no individual post is greater than 1mb
            string retry = i.ToString();
            log.LogInformation($"retry {retry}");
            success = await logAnalytics.PostToInsightsMetricsAsync(JsonConvert.SerializeObject(metricList), _hubResourceId, _compressForUpload);
        }

        if (success)
            log.LogInformation($"Successfully sent {metricList.DataItems.Count()} metrics to fixed set table");
        else
            log.LogError($"Failed to send {metricList.DataItems.Count()} metrics to fixed set table after {Constants.UploadMaxRetries} retries");
    }
    catch (Exception e)
    {
        log.LogError($"CollectMetrics failed with the following exception: {e}");
    }
        
}