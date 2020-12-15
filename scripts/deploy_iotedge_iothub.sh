#!/usr/bin/env bash

function show_help() {
   # Display Help
   echo "Run this script to deploy baseline workloads on IoT Edge devices"
   echo
   echo "Syntax: ./deploy_iotedge_iothub.sh [-flag parameter]"
   echo ""
   echo "List of mandatory flags:"
   echo "-hubrg            Azure Resource Group with the Azure IoT Hub controlling IoT Edge devices"
   echo "-hubname          Name of the Azure IoT Hub controlling the IoT Edge devices"
   echo ""
   echo "List of optional flags:"
   echo "-h                Print this help."
   echo "-c                Path to configuration file with IoT Edge VMs information."
   echo "-s                Azure subscription where resources have been deployed"
   echo
}

function getLowestSubnet() {
    deviceSubnets=($@)
    lowestSubnetInt=10
    lowestSubnet=""
    for deviceSubnet in "${deviceSubnets[@]}"
    do
        deviceSubnetInt=$(echo $deviceSubnet | cut -d "-" -f1)
        if [[ $deviceSubnetInt -lt $lowestSubnetInt ]]; then
            lowestSubnetInt=$deviceSubnetInt
            lowestSubnet=$deviceSubnet
        fi
    done
    echo "${lowestSubnet}"
}


#global variable
scriptFolder=$(dirname "$(readlink -f "$0")")

# Default settings
configFilePath="${scriptFolder}/../config.txt"

# Get arguments
while :; do
    case $1 in
        -h|-\?|--help)
            show_help
            exit;;
        -c=?*)
            configFilePath=${1#*=}
            if [ ! -f "${configFilePath}" ]; then
              echo "Configuration file not found. Exiting."
              exit 1
            fi;;
        -s=?*)
            subscription=${1#*=}
            ;;
        -s=)
            echo "Missing subscription id. Exiting."
            exit;;
        -c=)
            echo "Missing configuration file path. Exiting."
            exit;;
        -hubrg=?*)
            iotHubResourceGroup=${1#*=}
            ;;
        -hubrg=)
            echo "Missing IoT Hub resource group. Exiting."
            exit;;
        -hubname=?*)
            iotHubName=${1#*=}
            ;;
        -hubname=)
            echo "Missing IoT Hub name. Exiting."
            exit;;
        --)
            shift
            break;;
        *)
            break
    esac
    shift
done

#Verifying that mandatory parameters are there
if [ -z $iotHubResourceGroup ]; then
    echo "Missing IoT Hub resource group. Exiting."
    exit 1
fi
if [ -z $iotHubName ]; then
    echo "Missing IoT Hub name. Exiting."
    exit 1
fi

# Prepare CLI
if [ ! -z $subscription ]; then
  az account set --subscription $subscription
fi
# subscriptionName=$(az account show --query 'name' -o tsv)
# echo "Executing script with Azure Subscription: ${subscriptionName}" 

# Parse the configuration file
source ${scriptFolder}/parseConfigFile.sh $configFilePath

topLayerBaseDeploymentFilePath="${scriptFolder}/$topLayerBaseDeploymentFilePath"
middleLayerBaseDeploymentFilePath="${scriptFolder}/$middleLayerBaseDeploymentFilePath"
bottomLayerBaseDeploymentFilePath="${scriptFolder}/$bottomLayerBaseDeploymentFilePath"

echo "==========================================================="
echo "==   Pushing base deployment to all IoT Edge devices     =="
echo "==========================================================="
echo ""

#Verifying that the deployment manifest files are here
if [ -z $topLayerBaseDeploymentFilePath ]; then
    echo "TopLayerBaseDeploymentFilePath is missing from the configuration file. Please verify your configuration file. Exiting."
    exit 1
fi
if [ -z $bottomLayerBaseDeploymentFilePath ]; then
    echo "BottomLayerBaseDeploymentFilePath is missing from the configuration file. Please verify your configuration file. Exiting."
    exit 1
fi
if [ ! -f $topLayerBaseDeploymentFilePath ]; then
    echo "topLayerBaseDeployment manifest file not found. Make sure that the reference from the configuration file is correct. Exiting."
    exit 1
fi
if [ ! -f $bottomLayerBaseDeploymentFilePath ]; then
    echo "bottomLayerBaseDeployment manifest file not found. Make sure that the reference from the configuration file is correct. Exiting."
    exit 1
fi

# Set modules
bottomLayer=$(getLowestSubnet "${iotEdgeDevicesSubnets[@]}")
i=0
for iotEdgeDevice in "${iotEdgeDevices[@]}"
do
    echo "${iotEdgeDevice}..."
    if [[ ${iotEdgeParentDevices[i]} == "IoTHub" ]]; then
        az iot edge set-modules --device-id $iotEdgeDevice --hub-name $iotHubName --content $topLayerBaseDeploymentFilePath --output none
    elif [[ ${iotEdgeDevicesSubnets[i]} == $bottomLayer ]]; then
        az iot edge set-modules --device-id $iotEdgeDevice --hub-name $iotHubName --content $bottomLayerBaseDeploymentFilePath --output none
    else
        az iot edge set-modules --device-id $iotEdgeDevice --hub-name $iotHubName --content $middleLayerBaseDeploymentFilePath --output none
    fi
    ((i++))
done
echo "done"
echo ""