#!/usr/bin/env bash

#TODO2: Document default settings for the optional flags.

#TODO2: clean up all the echos ..way to many with confusing titles. Maybe add verbose flag?

function show_help() {
   # Display Help
   echo "Run this script to simulate in Azure: a Purdue Network, PLCs, IoT Edge devices sending data to IoT Hub."
   echo
   echo "Syntax: ./install.sh [-flag=value]"
   echo ""
   echo "List of mandatory flags:"
   echo "-hubrg            Azure Resource Group with the Azure IoT Hub."
   echo "-hubname          Name of the Azure IoT Hub controlling the IoT Edge devices."
   echo ""
   echo "List of optional flags:"
   echo "-h         Print this help."
   echo "-c         Path to configuration file with IIOT assets and IoT Edge VMs information. Default: ./config.txt."
   echo "-s         Azure subscription ID to use to deploy resources. Default: use current subscription of Azure CLI."
   echo "-l         Azure region to deploy resources to. Default: eastus."
   echo "-rg        Prefix used for all new Azure Resource Groups created by this script. Default: iotedge4iiot."
   echo "-vmSize   Size of the Azure VMs to deploy. Default: Standard_B1ms."
   echo
}

# Default settings / Initializing all option variables to avoid contamination by variables from the environment.
iotHubResourceGroup=""
iotHubName=""
configFilePath="./config.txt"
location="eastus"
resourceGroupPrefix="iotedge4iiot"
vmSize="Standard_B1ms" #"Standard_D3_v2"

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
        -l=?*)
            location=${1#*=}
            ;;
        -l=)
            echo "Missing location. Exiting."
            exit;;
        -s=?*)
            subscription=${1#*=}
            ;;
        -s=)
            echo "Missing subscription. Exiting."
            exit;;
        -rg=?*)
            resourceGroupPrefix=${1#*=}
            ;;
        -rg=)
            echo "Missing resource group prefix. Exiting."
            exit;;
        -vmSize=?*)
            vmSize=${1#*=}
            ;;
        -vmSize=)
            echo "Missing vmSize. Exiting."
            exit;;
        --)
            shift
            break;;
        *)
            break
    esac
    shift
done

# Derived default settings
networkResourceGroupName="${resourceGroupPrefix}-RG-network"
iotedgeResourceGroupName="${resourceGroupPrefix}-RG-iotedge"

#Verifying that mandatory parameters are there
if [ -z ${configFilePath} ]; then
    echo "Missing configuration file path. Exiting."
    exit 1
fi
if [ -z $iotHubResourceGroup ]; then
    echo "Missing IoT Hub resource group. Exiting."
    exit 1
fi
if [ -z $iotHubName ]; then
    echo "Missing IoT Hub name. Exiting."
    exit 1
fi

echo "==========================================================="
echo "==	              Azure Subscription          	 =="
echo "==========================================================="
echo ""
if [ ! -z $subscription ]; then
  az account set --subscription $subscription
fi
subscription=$(az account show --query 'name' -o tsv)
echo "Executing script with Azure Subscription: ${subscription}" 
echo ""
echo "==========================================================="
echo "==	              Configuration file          	 =="
echo "==========================================================="
echo ""
echo "Using configuration file located at: ${configFilePath}" 
echo ""


./scripts/deploy_purdue.sh -s=$subscription -l=$location -rg=$resourceGroupPrefix -vmSize=$vmSize
#./scripts/deploy_iiotassets.sh -s=$subscription -l=$location -rg=$resourceGroupPrefix -vmSize=$vmSize 
./scripts/deploy_iotedge_vms.sh -s=$subscription -l=$location -rg=$resourceGroupPrefix -vmSize=$vmSize
./scripts/provision_iotedge_iothub.sh -s=$subscription -hubrg=$iotHubResourceGroup -hubname=$iotHubName
./scripts/configure_iotedge_vms.sh -s=$subscription -edgerg=$iotedgeResourceGroupName -hubrg=$iotHubResourceGroup -hubname=$iotHubName
#./scripts/lockdown_purdue.sh -s=$subscription -nrg=$networkResourceGroupName
./scripts/import_acr.sh -s=$subscription
./scripts/deploy_iotedge_iothub.sh -s=$subscription -hubrg=$iotHubResourceGroup -hubname=$iotHubName

echo "==========================================================="
echo "==	              End of deployment script        	 =="
echo "==========================================================="


