# Monitor your IoT Edge devices from the cloud
###### Part 3 - 30 mins

In this third part, we'll remotely deploy an additional workload to your IoT Edge devices and deploy an additional cloud workflow in order to 1/collect metrics from your IoT Edge devices independently from the network layer that they are in and 2/visualize these metrics from a single cloud dashboard and 3/setup alerts in the cloud. This capability comes in addition to the ability to remotely collect logs from all your IoT Edge devices as already seen in [part 1 - Collect logs](1-SimulatePurdueNetwork.md#collect-logs).

//TODO: Need PIC

## Solution architecture

This solution uses IoT Edge as the deployment and messaging infrastructure described in the first part and Azure Monitoring. The[ IoT Edge metrics collector module](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/microsoft_iot_edge.metrics-collector?tab=Overview) is first added to all IoT Edge devices to collect metrics. Second a Log Analytics workspace is created to store these metrics.  Third a cloud workflow is setup to forward all metrics mesages received by IoT Hub to Log Analytics. Finally, these metrics are visualized in a cloud dashboard. To learn more about this architecture, please visit [this documentation](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-collect-and-transport-metrics?view=iotedge-2020-11) and [this sample](https://github.com/Azure-Samples/iotedge-logging-and-monitoring-solution).

//TODO: Add picture

## Pre-requisites

- **[Part 1 completed](1-SimulatePurdueNetwork.md)** with resources still available.

 
## Create a Log Analytics workspace

[Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/) is a set of services to monitor Azure and on-prem services. [Log Analytics](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-overview) is a tool in the Azure portal used to query data in Azure Monitor. We'll create a Logs Analytics workspace to store and query all the metrics collected by IoT Edge devices (To read the full tutorial, please see t[his documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/logs/quick-create-workspace)).

 From the [Azure Portal](http://portal.azure.com):
- In the search bar, type `Log Analytics`
- Select `Log Anlaytics workspaces` service
- Fill in the create template details:
    - Use the same subscription as in part 1
    - Use the resource group of your choice
    - Use the name and region of your choice
- Select `Review + Create`

## Deploy the metrics collector module

### Import the metrics collector module in your ACR

```
az acr import --name <acr_name> --force --source mcr.microsoft.com/azureiotedge-metrics-collector:1.0 --image azureiotedge-metrics-collector:1.0
```

### Create layered deployments

We'll create two [layered deployment](https://docs.microsoft.com/en-us/azure/iot-edge/module-deployment-monitoring?view=iotedge-2020-11#layered-deployment) to have a long running job that will deploy the metrics collector module to all IoT Edge devices that have the tag `metricsCollector` if in the top network layer or the tag `metricsCollectorNested` if in a nested network layer. Tagging of IoT Edge devices is done in the next section. To create the first layered deployment, from the [Azure Cloud Shell](https://shell.azure.com/):

- Go to the cloned repo folder:

    ```bash
    cd ~/iot-edge-for-iiot/
	```

//TODO: CAN WE AVOID CREATING 2 LAYERED DEPLOYMENTS AND JUST CREATE ONE - only the container registry name change. ideally, we can use $upstream everywhere, including in the top layer.

- Update the values in the `monitor/metricsCollector-top.layered.deployment.json` file (for more details on these fields, see [this documentation](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-collect-and-transport-metrics?view=iotedge-2020-11#metrics-collector-configuration)):
    - `ResourceID`: Resource id of your IoT Hub. See [this documentation](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-collect-and-transport-metrics?view=iotedge-2020-11#resource-id) for more info.
    - `LogAnalyticsWorkspaceId`: Workspace Id of your Log Analytics workspace. You can find it under your Log Analytics > Agents Management. See [this documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/log-analytics-agent?view=iotedge-2020-11#workspace-id-and-key) for more info.
    - `LogAnalyticsSharedKey`: Primary key of your Log Analytics. You can find it under your Log Analytics > Agents Management. See [this documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/log-analytics-agent?view=iotedge-2020-11#workspace-id-and-key) for more info.

- Replace the IoT Hub name with yours and run this command to create the layered deployment with the metrics collector module

    ```bash
    az iot edge deployment create --hub-name <iothub_name> --deployment-id metrics-collector --content ./monitor/metricsCollector-top.layered.deployment.json --target-condition "tags.metricsCollector=true" --priority 9 --layered true
    ```

To create the second layered deployment, from the [Azure Cloud Shell](https://shell.azure.com/):

- Update the values in the `monitor/metricsCollector-nested.layered.deployment.json` file (for more details on these fields, see [this documentation](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-collect-and-transport-metrics?view=iotedge-2020-11#metrics-collector-configuration)):
    - `ResourceID`: Resource id of your IoT Hub. See [this documentation](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-collect-and-transport-metrics?view=iotedge-2020-11#resource-id) for more info.
    - `LogAnalyticsWorkspaceId`: Workspace Id of your Log Analytics workspace. You can find it under your Log Analytics > Agents Management. See [this documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/log-analytics-agent?view=iotedge-2020-11#workspace-id-and-key) for more info.
    - `LogAnalyticsSharedKey`: Primary key of your Log Analytics. You can find it under your Log Analytics > Agents Management. See [this documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/agents/log-analytics-agent?view=iotedge-2020-11#workspace-id-and-key) for more info.

- Replace the IoT Hub name with yours and run this command to create the layered deployment with the metrics collector module

    ```bash
    az iot edge deployment create --hub-name <iothub_name> --deployment-id metrics-collector-nested --content ./monitor/metricsCollector-nested.layered.deployment.json --target-condition "tags.metricsCollectorNested=true" --priority 9 --layered true
    ```

To verify that the layered deployments were successfully created, navigate to your IoT Hub instance in the [Azure Portal](https://portal.azure.com/), select `Automatic Device Management`>`IoT Edge` from left navigation, select `IoT Edge deployments` and verify that the following the `metrics-collector` and `metrics-collector-nested` layered deployments exists.

### Tag all your IoT Edge devices

In order to deploy the metrics collector module to your IoT Edge devices, you need to set relevant tags on these devices so that this layered deployment gets applied to them. To tag your devices to get the metrics collector module, replace the IoT Hub name with yours and run the following Azure CLI commands in the [Azure Cloud Shell](https://shell.azure.com/):

```bash
az iot hub device-twin update --device-id L5-edge --hub-name <iothub_name> --set tags='{"metricsCollector": true}'
az iot hub device-twin update --device-id L4-edge --hub-name <iothub_name> --set tags='{"metricsCollectorNested": true}'
az iot hub device-twin update --device-id L3-edge --hub-name <iothub_name> --set tags='{"metricsCollectorNested": true}'
```

To verify that the layered deployments have been properly picked up, go to the [Azure Portal](https://portal.azure.com/), navigate to "Automatic Device Management">"IoT Edge">"IoT Edge Deployments" and make sure both deployments show "1 Targeted" and "1 applied" under "System Metrics" column. You can also verified the module deployment status of each device by running the CLI command provided in [this section in part 1](1-SimulatePurdueNetwork.md#twin-reported-properties).

## Build a cloud workflow to forward metrics data to your Log Analytics workspace

Because in a nested environment, IoT Edge devices do not have direct connectivity to Azure, metrics data cannot be sent directly to Azure Monitor. Instead, metrics data is sent as telemetry messages to IoT Hub and from there messages needs to be routed to an Event Hub, retrived by an Azure Function which pushes them to Log Analytics. We thus need to 1/ set up an Event hub and 2/ 

### Create a route for your metrics data

To get the connection string, go to IoT Hub / Built-in Endpoints > EventHub

```bash
az iot hub routing-endpoint create --resource-group <iothub_resource_group> --hub-name <iothub_name> --endpoint-type eventhub --endpoint-name "metricscollector" --endpoint-resource-group <endpoint_resource_group> --endpoint-subscription-id $(az account show --query id -o tsv) --connection-string <eventHub_builtin_connection_string>
```

To verify it, go to IoT Hub > Messaging > Message routing > Custom Endpoints and verify that the `metricscollector` endpoint is there.

Create a route:
```bash
az iot hub route create --resource-group <iothub_resource_group> --hub-name <iothub_name> --endpoint-name "metricscollector" --source-type DeviceMessages --route-name "metricscollector" --condition "id = 'origin-iotedge-metrics-collector'" --enabled true
```

//TODO: create a fallback route

To verify it, go to IoT Hub > Messaging > Message routing > Routes and verify that the `metricscollector` route is there.

### Create an Azure Function to ingest your metrics data

#### Create a Function App

Choose your resource group
Give your function a name like `CollectMetrics`
Publish it as a `Code`
Select `.Net` as a runtime stack
Select `3.1` as a runtime version
Select your region

#### Create a Function

Once the function app is created, navigate to it and go to the `Functions` page under the `Functions` tab

```bash
cd ./monitor/CollectMetricsFunction/zip
az functionapp deployment source config-zip -g <resource_group> -n <app_name> --src <zip_file_path>
```

#### Configure your Azure Function

##### Application settings

To configure your Azure Function, from the Azure portal go to your Function > Settings > Configuration and add the following application settings by clicking on `New application setting` for each of the following one:


|Application setting name  | Application setting value  |
|---------|---------|
|metricsEncoding     |    gzip     |
|workspaceAPIVersion     |    2016-04-01     |
|hubResourceId     |    Your IoT Hub Resource Id (IoT Hub > Properties > ResourceId)     |
|workspaceId     |    Your LogAnalytics Agent Id (Log Analytics > Agent Configuration > Id)     |
|workspaceKey     |   Your LogAnalytics Agent Key (Log Analytics > Agent Configuration > Key)        |

##### Integration settings

Navigate to your Azure function app in the portal:
- Click on Functions and select your function.
- Click on Integration
- Click on `Azure Event Hubs` Trigger
- Create a new Event Hub connection by clicking on `New`
- Select IoT Hub
- Select your IoT Hub and its built-in Events endpoint
- `Save`

//TODO: Check that this is the correct route dedicated to metrics and not the fallback one

To make sure that your Azure function is running properly, go to your function app in the portal and select `Log stream`. 

TODO: May also need to delete the projects.assets.json file and edit (add a whitespace) to function.json to force the restoring of the nugget packages...dont know how to do otherwise...

## Visualize your metrics

To visualize the metrics sent by your IoT Edge device, we'll use pre-built workbooks. Go to your IoT Hub > Monitoring > Workbooks and select the `IoT Edge Fleet View (preview)` one. From there, drill down to one of your devices by clicking on one of your IoT Edge device name in the right column. Explore all the health details collected on this IoT Edge device. For more information about these workbooks, please see [this documentation](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-explore-curated-visualizations?view=iotedge-2020-11&tabs=devices%2Cmessaging). As a next step, you can also explore [this documentation](https://docs.microsoft.com/en-us/azure/iot-edge/how-to-create-alerts?view=iotedge-2020-11) to learn how to create alerts based on these metrics.

//TODO: Add picture