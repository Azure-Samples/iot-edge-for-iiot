# Deploy  Offline Dashboards via Azure Devops pipelines

This document describes how to set up an Azure DevOps pipeline to deploy the IoT Offline Dashboards in a nested edge environment. Azure Devops is used to enable a continuous, repeatable development, build, and deployment process, as well as having the ability to test the deployment to multiple IoT Edge devices at scale.

**Table of contents**
* [Forking the repository](#forking-the-repository)
* [Setting up an Azure DevOps organization and project](#setting-up-an-azure-devops-organization-and-project)
* [Creating the DevOps pipeline](#creating-the-devops-pipeline)
* [Executing the pipeline](#executing-the-pipeline)
* [Verify successfull pipeline execution](#Verify-successfull-pipeline-execution)
* [Deploy modules](#Deploy-modules)
* [Verify Deployment on edge nodes](#Verify-Deployment-on-edge-nodes)
* [View Dashboards](#View-Dashboards)
* [For more information](#For-more-information)

## Forking the repository

The DevOps pipeline details for the sample are included in [the github repository](https://github.com/AzureIoTGBB/iot-edge-offline-dashboarding).

 Do a GitHub [fork](https://help.github.com/en/github/getting-started-with-github/fork-a-repo) of the repository to your own workspace. After that, continue making changes to the pipeline configuration, for example changing the target conditions.

## Setting up an Azure DevOps organization and project

An Azure DevOps pipeline is always part of a [project](https://docs.microsoft.com/en-us/azure/devops/organizations/projects/create-project?view=azure-devops&tabs=preview-page), which is part of an [organization](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/create-organization?view=azure-devops). Follow the instructions on the given websites, but skip the 'Add a Repository to your Project' part since this is managed on GitHub.

Before adding the pipeline there are two project-level preliminary tasks.

### Install the GitVersion add-in

[GitVersion](https://marketplace.visualstudio.com/items?itemName=gittools.usegitversion) can be used to automatically derive image version tags from a repository. Use the "Get it free" button on the link above to install the add-in into the organization.

### Create a service connection to Azure

A service connection to Azure allows DevOps to push images and create deployments for an Azure subscription.

* In the lower left corner of the pipelin settings, choose "Project Settings"
* From the left navigation, choose "Service Connections"
* Click "New Service Connection"
* Choose "Azure Resource Manager" and hit "next"
* Choose "Service Principal (automatic)" then "next"
* Choose an Azure subscription from the dropdown
  * (For environments where you may not have subscription-level permissions, you may have to also select the specific Resource Group where you deployed your IoT Hub and ACR instance)
* Add a name for the service connection and hit Save

## Creating the DevOps pipeline

Click on Pipelines from the left-nav and then select "Create Pipeline".

* From the "Where is your code?" screen, choose Github
  * You may see a screen asking for authentication: "Authenticate to authorize access"
* From the "Select a repository" screen, select the fork created above
  * Select "Approve & Install Azure Pipelines" if required
* From the "review your pipeline" screen, click the down-arrow next to Run and click "Save" - note that a number of variables need to be added before the first run

### Set the pipeline environment variables

To make the pipeline as generic as possible, much of the config is supplied in the form of environment variables. To add these variables, click on "Variables" in the upper right hand corner of the "Edit Pipeline" screen. Add the following variables and values:

* ACR_NAME: This is the 'short name' of our Azure Container Registry (the part before .azurecr.io)
* ACR_USERNAME: User name to connect to ACR_NAME above
* ACR_PASSWORD: Password to connect to ACR_NAME above
* ACR_RESOURCE_GROUP: The name of the resource group in Azure that contains the Azure Container Registry
* AZURE_SERVICE_CONNECTION: The name of the Azure service connection created above
* AZURE_SUBSCRIPTION_ID: The ID of the used Azure subscription
* GRAFANA_ADMIN_PASSWORD: The desired administrator password for the Grafana dashboard web app when deployed
* SQLEDGE_ADMIN_PASSWORD: The desired administrator (sa) password for SQL Edge instance
* IOT_HUB_NAME: The name of the connected Azure IoT Hub (short name, without the .azure-devices.net)
* IIOT_ASSETS_RG: Name of resource group where IIOT Assets (OPC Servers reside)  (e.g. iotedge4iiot-RG-iiot-assets)
* Click "Save"

## Executing the pipeline

The pipeline is set to trigger on commits to the master branch's offline-dashboards folder of the GitHub repository. However for testing it can be run manually.

Click on "Run" in the upper right hand corner to start the manual execution of the pipeline. The pipeline has "Build" and "Release" stages. Click on the "Build" stage to open the detail view while running.

## Verify successfull pipeline execution

When pipeline is executed, it builds Docker images for following modules and uploads them to <ACR_NAME>.azurecr.io/offline-dashboards/
* grafana
* sqledge
* opcpublisher
* opcsimulator

To verify images built   
* Navigate to your Azure Container Registry instance <ACR_NAME> from Azure Portal 
* Select "Reporitories" from left
* Verify images under following repos
  * offline-dashboards/grafana
  * offline-dashboards/opcpublisher
  * offline-dashboards/opcsimulator
  * offline-dashboards/sqledge

Pipeline also creates two layered deployments for IoT Edge
* dashboard-node: contains modules for edge node which will run the main database and dashboards
* publisher-node: contains modules for edge node which will run OPC Publisher, collect data from OPC Servers and send data up to dashboard node

To verify deployments
* Navigate to your IoT Hub instance <IOT_HUB_NAME> from Azure Portal 
* Select "Automatic Device Management">"IoT Edge" from left
* Select "IoT Edge Deployments"
* Verify two layered deployments exist
  * dashboard-node
  * publisher-node

## Deploy modules

In order to deploy modules you need to set relevant tags on the edge device or devices.

### Dashboard Node:
Dashboard node collects all data from  publishers, stores it in the SQL Edge database and displays data in dashboards. Normally dashboard node should be the topmost node (the edge node that connects directly to IOT Hub) in an IOT Edge hierarchy.

Run following code in Azure CLI to set 'dashboardNode' tag value for <DEVICE_ID> to apply layered deployment 'dashboard-node'. Here <DEVICE_ID> is the id of the edge node (e.g.L5-edge) 

```CLI
az iot hub device-twin update --device-id <DEVICE_ID> --hub-name <IOT_HUB_NAME> --set tags='{"dashboardNode": true}'
```

### Publisher Node:
Publisher node(s) connects to OPC Servers (IIOT Assets in L2), collect data points from them and send data up to the dashboard node. Normally publisher nodes are leaf levels of nested IoT Edge hierarchy.

Run following code in Azure CLI to set 'publisherNode' tag value for <DEVICE_ID> to apply layered deployment 'publisher-node'. Here <DEVICE_ID> is the id of the edge node (e.g.L3-edge) 

```CLI
az iot hub device-twin update --device-id <DEVICE_ID> --hub-name <IOT_HUB_NAME> --set tags='{"publisherNode": true}'
```

Note: After updating tags navigate to "Automatic Device Management">"IoT Edge">"IoT Edge Deployments" and make sure both deployments show "1 Targeted" and "1 applied" under "System Metrics" column.

Note: Pipeline builds a publishedNodes.json file that defines all VMs in L2 level as OPC Publishers. It then embeds this file in to opcpublisher module image, whic is the same image to be used in all publisher nodes. Therefore if you have more than one publisher node, all of them will collect same data. To set which publisher connects to which OPC Server follow those steps:
* Access to published nodes file at /app/pn.json path in the OPC Publisher image. You may run below docker command to copy file from module image into Edge VM
    ```bash
    sudo docker cp opcpublisher:/app/pn.json ./publishedNodes.json
    ```
* Copy/modify relevant portions top create your own published nodes file (e.g pn1.json)
* Create a directory (/iiotedge)
* Copy you published nodes file (pn1.json) into /iiotedge
* Repeat above for every publisher node
* Modify layered deployment template as following 

```json
{
  "Hostname": "publisher",
  "Cmd": [
    "--pf=/appdata/pn1.json",
    "--aa",
    "--loglevel=verbose"
  ],
  "HostConfig": {
    "Binds": [
      "/iiotedge:/appdata"
    ]
  }
}
```
Note: You will notice that opcsimulator image is not deployed automatically. If you update opcsimulator module, you will need to do following to deploy it on IIOT Assets
* Allow internet connectivity from L2 network by modifying PurdueNetwork-L2-nsg Network security group
* Pull new image for each IIOT Asset by running docker pull
* Shutdown internet connectivity from L2 network


## Verify Deployment on edge nodes

* Navigate to Edge devices where deployment is targeted (e.g. L5-edge, L3-edge) and make sure all modules listed report healthy status

* SSH into your IoT Edge boxes (e.g. L5-edge, L3-edge) and run:

```bash
sudo iotedge list
```

## View Dashboards
* If everything is healthy, wait for 10 minutes and navigate to following address to view dashboards

```hyperlink
http://{ip-address-of-dashboard-node}:3000/
```

## For more information 

* [View Grafana Dashboard](https://github.com/AzureIoTGBB/iot-edge-offline-dashboarding/blob/master/documentation/dashboarding-sample.md#view-the-grafana-dashboard) to see and customize the dashboard.
* [Customize OEE Dashboards](https://github.com/AzureIoTGBB/iot-edge-offline-dashboarding/blob/master/documentation/customize-sample-oee.md)
* [Offline Dashboards for IoT Edge main repo](https://github.com/AzureIoTGBB/iot-edge-offline-dashboarding/)

