#r "Newtonsoft.Json"

using Newtonsoft.Json;

public class LaMetricList
{
    public string DataType => Constants.MetricUploadDataType;
    public string IPName => Constants.MetricUploadIPName;
    public IEnumerable<LaMetric> DataItems { get; set; }

    public LaMetricList(IEnumerable<LaMetric> items)
    {
        DataItems = items;
    }
}

public class LaMetric
{
    public string Origin { get; set; }
    public string Namespace { get; set; }
    public string Name { get; set; }
    public double Value { get; set; }
    public DateTime CollectionTime { get; set; }
    public string Tags { get; set; }
    public string Computer { get; set; }
    public LaMetric(IoTHubMetric metric, string hostname)
    {
        // forms DB key
        this.Name = metric.Name;
        this.Tags = JsonConvert.SerializeObject(metric.Labels);

        // value
        this.Value = metric.Value;

        // optional 
        this.CollectionTime = metric.TimeGeneratedUtc;
        this.Computer = Constants.MetricComputer;
        this.Origin = Constants.MetricOrigin;
        this.Namespace = Constants.MetricNamespace;

        //TODO: what to do with origin?
    }
}

public class IoTHubMetric
{
    [JsonProperty("TimeGeneratedUtc")]
    public DateTime TimeGeneratedUtc { get; set; }
    [JsonProperty("Name")]
    public string Name { get; set; }
    [JsonProperty("Value")]
    public double Value { get; set; }
    [JsonProperty("Labels")]
    public IReadOnlyDictionary<string, string> Labels { get; set; }
}