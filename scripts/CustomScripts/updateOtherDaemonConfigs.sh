#!/bin/bash

dcs=$1
fqdn=$2
if [ ! -z $4 ]; then
    parentFqdn=$3
    proxySettings=$4
else
    if [[ $3  = https_proxy=* ]]; then
        parentFqdn=""
        proxySettings=$3
    else
        parentFqdn=$3
        proxySettings=""
    fi
fi


echo "Executing script with parameters:"
echo "Device connection string: ${dcs}"
echo "FQDN: ${fqdn}"
echo "Parent FQDN: ${parentFqdn}"
echo "ProxySettings: ${proxySettings}"

if [ -z $1 ]; then
    echo "Missing device connection string. Please pass a device connection string as a primary parameter. Exiting."
    exit 1
fi

if [ -z $2 ]; then
    echo "Missing device Fully Domain Qualified Name (FQDN). Please pass a FQDN as a secondary parameter. Exiting."
    exit 1
fi


echo "Updating the device connection string"
sudo sed -i "s#\(device_connection_string: \).*#\1\"$dcs\"#g" /etc/iotedge/config.yaml

echo "Updating the device hostname"
sudo sed -i "224s/.*/hostname: \"$fqdn\"/" /etc/iotedge/config.yaml

if [ ! -z $parentFqdn ]; then
    echo "Updating the parent hostname"
    sudo sed -i "237s/.*/parent_hostname: \"$parentFqdn\"/" /etc/iotedge/config.yaml
fi

echo "Updating the version of the bootstrapping edgeAgent to be the public preview one"
if [ ! -z $parentFqdn ]; then
    edgeAgentImage="$parentFqdn:443/azureiotedge-agent:1.2.0-rc1-linux-amd64"
else
    edgeAgentImage="iotedgeforiiot.azurecr.io/azureiotedge-agent:1.2.0-rc1-linux-amd64"
fi
sudo sed -i "207s|.*|    image: \"${edgeAgentImage}\"|" /etc/iotedge/config.yaml

if [ -z $parentFqdn ]; then
    echo "Adding ACR credentials for IoT Edge daemon to download the bootstrapping edgeAgent"
    iotedgeforiiotACRServerAddress="iotedgeforiiot.azurecr.io"
    iotedgeforiiotACRUsername="2ad19b50-7a8a-45c4-8d11-20636732495f"
    iotedgeforiiotACRPassword="bNi_CoTYr.VNugCZn1wTd_v09AJ6NPIM0_"
    sudo sed -i "208s|.*|    auth:|" /etc/iotedge/config.yaml
    sed -i "209i\      serveraddress: \"${iotedgeforiiotACRServerAddress}\"" /etc/iotedge/config.yaml
    sed -i "210i\      username: \"${iotedgeforiiotACRUsername}\"" /etc/iotedge/config.yaml
    sed -i "211i\      password: \"${iotedgeforiiotACRPassword}\"" /etc/iotedge/config.yaml
fi

echo "Configuring the bootstrapping edgeAgent to use AMQP/WS"
#sudo sed -i "205s|.*|  env:|" /etc/iotedge/config.yaml
sudo sed -i "206i\#    UpstreamProtocol: \"AmqpWs\"" /etc/iotedge/config.yaml

if [ ! -z $proxySettings ]; then
    echo "Configuring the bootstrapping edgeAgent to use http proxy"
    sudo sed -i "205s|.*|  env:|" /etc/iotedge/config.yaml
    httpProxyAddress=$(echo $proxySettings | cut -d "=" -f2-)
    sudo sed -i "207i\    https_proxy: \"${httpProxyAddress}\"" /etc/iotedge/config.yaml

    echo "Adding proxy configuration to docker"
    sudo mkdir -p /etc/systemd/system/docker.service.d/
    { echo "[Service]";
    echo "Environment=${proxySettings}";
    } | sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf
    sudo systemctl daemon-reload
    sudo systemctl restart docker

    echo "Adding proxy configuration to IoT Edge daemon"
    sudo mkdir -p /etc/systemd/system/iotedge.service.d/
    { echo "[Service]";
    echo "Environment=${proxySettings}";
    } | sudo tee /etc/systemd/system/iotedge.service.d/proxy.conf
    sudo systemctl daemon-reload
fi

echo "Restarting IoT Edge to apply new configuration"
sudo systemctl unmask iotedge
sudo systemctl start iotedge

echo "Done."