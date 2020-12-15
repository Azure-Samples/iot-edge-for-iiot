#!/bin/bash

deviceId=$1

echo "Setting up test nested edge configuration for IoT Edge device $deviceId"

i=0
dpkg -s iotedge &> /dev/null
while [ $? -ne 0 ]
do
   echo "waiting 10s for IoT Edge to complete its installation"
   sleep 10
   ((i++))
   dpkg -s iotedge &> /dev/null
   if [ $i -gt 30 ]; then
        dpkg -s iotedge
        echo "IoT Edge is not installed. Please install it first. Exiting."
        exit 1
   fi
done


if [ -z $1 ]; then
        echo "Missing deviceId. Please pass a deviceId as a parameter. Exiting."
        exit 1
fi

#TODO2: erase certs folder first

echo "Installing test root certificate bundle. NOT TO BE USED FOR PRODUCTION."
mkdir /certs
cd /certs
sudo wget -O test-certs.tar.bz2 "https://iotedgeforiiot.blob.core.windows.net/test-certificates/test-certs.tar.bz2"
sudo tar -xjvf test-certs.tar.bz2
cd ./certs

echo "Generating edge device certificate"
./certGen.sh create_edge_device_certificate $deviceId
cd ./certs
sudo cp azure-iot-test-only.root.ca.cert.pem /usr/local/share/ca-certificates/azure-iot-test-only.root.ca.cert.pem.crt
sudo update-ca-certificates

echo "Updating IoT Edge configuration file to use the newly installed certificcates"
device_ca_cert_path="/certs/certs/certs/iot-edge-device-$deviceId-full-chain.cert.pem"
device_ca_pk_path="/certs/certs/private/iot-edge-device-$deviceId.key.pem"
trusted_ca_certs_path="/certs/certs/certs/azure-iot-test-only.root.ca.cert.pem"
sudo sed -i "165s|.*|certificates:|" /etc/iotedge/config.yaml
sudo sed -i "166s|.*|  device_ca_cert: \""$device_ca_cert_path"\"|" /etc/iotedge/config.yaml
sudo sed -i "167s|.*|  device_ca_pk: \""$device_ca_pk_path"\"|" /etc/iotedge/config.yaml
sudo sed -i "168s|.*|  trusted_ca_certs: \""$trusted_ca_certs_path"\"|" /etc/iotedge/config.yaml

echo "Done."