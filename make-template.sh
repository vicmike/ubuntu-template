#!/bin/bash

# Set DISK_EXPANSION to 0 if you want keep the Ubuntu cloud-image default of 10GB
UBUNTU_RELEASE=${UBUNTU_RELEASE:-lunar}
DISK_EXPANSION=${DISK_EXPANSION:-40}
VM_NETWORK=${VM_NETWORK:-"VM Network"}

# Check for necessary tools
command -v qemu-img >/dev/null 2>&1 || { echo >&2 "qemu-img is required but it's not installed. Aborting."; exit 1; }
command -v govc >/dev/null 2>&1 || { echo >&2 "govc is required but it's not installed. Aborting."; exit 1; }

# Check govc configuration
govc about >/dev/null 2>&1 || { echo >&2 "govc is not configured correctly. Aborting."; exit 1; }

# Download the cloud image
curl -s https://cloud-images.ubuntu.com/${UBUNTU_RELEASE}/current/${UBUNTU_RELEASE}-server-cloudimg-amd64.vmdk -o ${UBUNTU_RELEASE}-template.vmdk

# Only process with qemu-img if disk expansion is required
if [ "$DISK_EXPANSION" -gt 0 ]; then
  # Check for necessary tools
  command -v qemu-img >/dev/null 2>&1 || { echo >&2 "qemu-img is required but it's not installed. Aborting."; exit 1; }

  # Convert to qcow2
  qemu-img convert -f vmdk -O qcow2 ${UBUNTU_RELEASE}-template.vmdk ${UBUNTU_RELEASE}-template.qcow2 > /dev/null
  rm ${UBUNTU_RELEASE}-template.vmdk

  # Disk expansion
  qemu-img resize ${UBUNTU_RELEASE}-template.qcow2 +${DISK_EXPANSION}G > /dev/null

  # Convert back to vmdk
  qemu-img convert -f qcow2 -o subformat=streamOptimized -O vmdk ${UBUNTU_RELEASE}-template.qcow2 ${UBUNTU_RELEASE}-template.vmdk > /dev/null
  rm ${UBUNTU_RELEASE}-template.qcow2
fi

# Encode user data
USER_DATA=$(base64 -w0 user-data.yml)

# Import to VMware
govc import.vmdk ${UBUNTU_RELEASE}-template.vmdk 

# Create VM
govc vm.create -net "$VM_NETWORK" -net.adapter vmxnet3 -on=false -g ubuntu64Guest -m 4096 -c 2 -g ubuntu64Guest -disk=${UBUNTU_RELEASE}-template/${UBUNTU_RELEASE}-template.vmdk  ${UBUNTU_RELEASE}-template

# Change VM settings
govc vm.change -vm ${UBUNTU_RELEASE}-template -e "guestinfo.userdata.encoding=base64"
govc vm.change -vm ${UBUNTU_RELEASE}-template -e "guestinfo.userdata=\"${USER_DATA}\""

# Mark as template
govc vm.markastemplate ${UBUNTU_RELEASE}-template

