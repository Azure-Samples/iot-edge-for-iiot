#!/bin/bash

deviceId=$1

# Validating parameters
if [ -z $1 ]; then
        echo "Missing deviceId. Please pass a deviceId as a parameter. Exiting."
        exit 1
fi
echo "Setting up test nested edge configuration for IoT Edge device $deviceId"
echo ""

# Waiting for IoT Edge installation to be complete
i=0
iotedgeConfigFile="/etc/iotedge/config.yaml"
while [[ ! -f "$iotedgeConfigFile" ]]; do
    echo "Waiting 10s for IoT Edge to complete its installation"
    sleep 10
    ((i++))
    if [ $i -gt 30 ]; then
        echo "Something went wrong in the installation of IoT Edge. Please install IoT Edge first. Exiting."
        exit 1
   fi
done
echo "Installation of IoT Edge is complete. Starting its configuration."
echo ""

# Installing certificates
#TODO2: erase certs folder first
echo "Installing test root certificate bundle. NOT TO BE USED FOR PRODUCTION."
mkdir /certs
cd /certs
sudo wget -O test-certs.tar.bz2 "https://raw.githubusercontent.com/ebertrams/iotedge4iiot-e2e/master/scripts/assets/test-certs.tar.bz2"
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