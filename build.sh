#!/bin/bash

VMX_DIR=/root/vmx
if [ $# != 2 ]; then
  echo "Usage: build.sh <vcp_ip> <vfp_ip>"
  exit 1
fi

function get_port() {
  for (( port = $1 ; port <= $2 ; port++ )); do
    nc -z 127.0.0.1 $port
    if [ $? -ne 0 ]; then
      echo $port
      break
    fi
  done
}

function get_mac() {
  hexchars="0123456789ABCDEF"
  mac=$( for i in {1..4} ; do echo -n ${hexchars:$(( $RANDOM % 16 )):1} ; done | sed -e 's/\(..\)/:\1/g' )
  echo $mac
}

function replace() {
  sed -i "s/$1/$2/" $3
}

files=$(cd $VMX_DIR/config &>/dev/null && ls vmx[0-9]*.conf 2>/dev/null)
if [ $? -eq 0 ]; then
  index=$(echo $files | grep -o '[0-9]\+' | sort -rn | head -1 | awk '{printf "%03d", $1 + 1}')
else
  index=001
fi

cp_port=$(get_port 8601 9000)
fp_port=$(get_port $(($cp_port+1)) 9000)

cp_mac=$(get_mac)
fp_mac=$(get_mac)

vmx_file=$VMX_DIR/config/vmx$index.conf
cp vmx.conf $vmx_file
replace __NNN__ $index $vmx_file
replace __cp_port__ $cp_port $vmx_file
replace __fp_port__ $fp_port $vmx_file
replace __cp_mac__ $cp_mac $vmx_file
replace __fp_mac__ $fp_mac $vmx_file
replace __cp_ip__ $1 $vmx_file
replace __fp_ip__ $2 $vmx_file

(cd $VMX_DIR && ./vmx.sh --cfg $vmx_file -lv --install)

if [ $? -ne 0 ]; then
  echo "ERROR: Failed to create VMX, cleaning up..."
  (cd $VMX_DIR && ./vmx.sh --cfg $vmx_file -lv --cleanup)
  exit 1
fi

echo "VMX created... waiting for it to boot"
booted=0
for ((count = 0; count < 50; count++)); do
  ping -c1 $1 &>/dev/null
  if [ $? -eq 0 ]; then
    booted=1
    break
  fi
  echo -n "."
  sleep 10
done

if [ $booted -eq 0 ]; then
  echo "ERROR: Timed out waiting for VMX to boot up, cleaning up..."
  (cd $VMX_DIR && ./vmx.sh --cfg $vmx_file -lv --cleanup)
  exit 1
fi

echo "Enabling ssh for the VMX..."
cd $VMX_DIR
/usr/bin/expect << EOD
  spawn ./vmx.sh --console vcp vmx$index
  send "\r"
  expect "login: "
  send "root\r"
  expect -re "# ?$"
  send "cli\r"
  expect -re "> ?$"
  send "configure\r"
  expect "Entering configuration mode"
  expect -re "# ?$"
  send "delete chassis auto-image-upgrade\r"
  expect -re "# ?$"
  send "set system services ssh\r"
  expect -re "# ?$"
  send "set system host-name vmx$index\r"
  expect -re "# ?$"
  send "set system root-authentication plain-text-password\r"
  expect "New password:"
  send "Embe1mpls\r"
  expect "Retype new password:"
  send "Embe1mpls\r"
  expect -re "# ?$"
  send "commit\r"
  expect "commit complete"
  expect -re "# ?$"
  send "exit\r"
  expect "Exiting configuration mode"
  expect -re "> ?$"
  send "exit\r"
  expect -re "# ?$"
  send "exit\r"
  expect "logout"
EOD

echo "Created vMX: vmx$index"
