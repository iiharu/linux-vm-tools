#!/bin/bash

#
# This script is for Debian 10 Buster to install XRDP+XORGXRDP.
#

###############################################################################
# Update our machine to the latest code if we need to.
#

if [ "$(id -u)" -ne 0 ]; then
    echo 'This script must be run with root privileges' >&2
    exit 1
fi

apt update && apt upgrade -y

if [ -f /var/run/reboot-required ]; then
    echo "A reboot is required in order to proceed with the install." >&2
    echo "Please reboot and re-run this script to finish the install." >&2
    exit 1
fi

###############################################################################
# Install XRDP
#

# Install hyperv-daemons
apt install -y hyperv-daemons

# Install xrdp
apt install -y xrdp

###############################################################################
# Configure XRDP
#

systemctl enable xrdp
systemctl enable xrdp-sesman

cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.orig
# use vsock transport.
sed -i -e 's/use_vsock=false/use_vsock=true/g' /etc/xrdp/xrdp.ini
# use rdp security.
sed -i -e 's/security_layer=negotiate/security_layer=rdp/g' /etc/xrdp/xrdp.ini
# remove encryption validation.
sed -i -e 's/crypt_level=high/crypt_level=none/g' /etc/xrdp/xrdp.ini
# disable bitmap compression since its local its much faster
sed -i -e 's/bitmap_compression=true/bitmap_compression=false/g' /etc/xrdp/xrdp.ini
sed -i -e 's/max_bpp=32/max_bpp=24/g' /etc/xrdp/xrdp.ini

cp /etc/xrdp/sesman.ini /etc/xrdp/sesman.ini.orig
# rename the redirected drives to 'shared-drives'
sed -i -e 's/FuseMountName=thinclient_drives/FuseMountName=shared-drives/g' /etc/xrdp/sesman.ini

# Changed the allowed_users
cp /etc/X11/Xwrapper.config /etc/X11/Xwrapper.config.orig
sed -i -e 's/allowed_users=console/allowed_users=anybody/g' /etc/X11/Xwrapper.config

# Blacklist the vmw module
if [ ! -e /etc/modprobe.d/blacklist_vmw_vsock_vmci_transport.conf ]; then
cat >> /etc/modprobe.d/blacklist_vmw_vsock_vmci_transport.conf <<EOF
blacklist vmw_vsock_vmci_transport
EOF
fi

# Ensure hv_sock gets loaded
if [ ! -e /etc/modules-load.d/hv_sock.conf ]; then
	echo "hv_sock" > /etc/modules-load.d/hv_sock.conf
fi

# Configure the policy xrdp session
cat > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla <<EOF
[Allow Colord all Users]cr
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# reconfigure the service
systemctl daemon-reload

#
# End XRDP
###############################################################################

echo "Install is complete."
echo "Poweroff your machine."
echo "Launch powershell with Administrator privilege "
echo "and run 'Set-VM –VMName <YOUR_VM_NAME> -EnhancedSessionTransportType HvSocket' to enable enhanced session."
