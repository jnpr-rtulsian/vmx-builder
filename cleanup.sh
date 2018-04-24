#!/bin/bash

VMX_DIR=/root/vmx
if [ $# != 1 ]; then
  echo "Usage: cleanup.sh <vcp_ip>"
  exit 1
fi

files=$(cd $VMX_DIR/config &>/dev/null && grep -R "$1\$" * 2>/dev/null)
if [ $? -eq 0 ]; then
  index=$(echo $files | cut -d : -f 1 | grep -o '[0-9]\+')
else
  echo "ERROR: No config found with vcp ip $1"
  exit 1
fi

vmx_file=$VMX_DIR/config/vmx$index.conf
(cd $VMX_DIR && ./vmx.sh --cfg $vmx_file -lv --cleanup)
rm $vmx_file
echo "Cleaned vMX: vmx$index"
