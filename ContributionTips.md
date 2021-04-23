# Contribution Tips

Below are a few tips that help to understand and debug the installation scripts.

## Cloud-init

### customData
All VMs deployed by the installation scripts run a [cloud-init](https://cloudinit.readthedocs.io/en/latest/) script after their deployments. These cloud-init scripts are stored in the `./cloud-inits` folder in this repository for readability, but the scripts that actually get run on the VMs are passed through the `customData` field of each ARM template. To generate the `customData` field from a cloud-init script, follow [these instructions](scripts/cloud-inits/README.md).

### schema validation
To validate the schema of a cloud-init script, you can run in an Azure VM the following command:

```bash
cloud-init devel schema --system --annotate
```

### logs
To debug a cloud-init script, look at its logs:

```bash
sudo nano /var/log/cloud-init-output.log
```

## Custom Scripts
VMs requiring further configuration after their deployment and after their cloud-init script, such as the IoT Edge VMs, get their extra configuration via [Azure VM Custom Script extension](https://docs.microsoft.com/en-us/azure/virtual-machines/extensions/custom-script-linux).

### script location
The scripts are downloaded by the VMs directly from GitHub. To make changes to their location, for instance to test an updated script, push your updated version in a GitHub branch and test it by update the script location to point to that branch in the `configure_iotedge_vms.sh` file.

### logs
To debug these custom scripts, look at their outputs and errors located at, where 0 below is your custom script number:

```bash
ls /var/lib/waagent/custom-script/download/0/
cat /var/lib/waagent/custom-script/download/0/stderr
cat /var/lib/waagent/custom-script/download/0/stdout
```

## SQUID Proxy

In case you need to troubleshoot an issue with the squid proxies, you can look at their logs:

```bash
sudo tail -f /var/log/squid/access.log
sudo tail -f /var/log/squid/cache.log
```
