#!/bin/bash

set -e

die() { echo "$1" ; exit 1 ; }

[ -n "${SFTPBRIDGE_CONFIG_PREFIX}" ] || die "Please export SFTPBRIDGE_CONFIG_PREFIX"
[ -n "${SFTPBRIDGE_USER_PREFIX}" ] || die "Please export SFTPBRIDGE_USER_PREFIX"
[ -n "${SFTPBRIDGE_UPLOAD_PREFIX}" ] || die "Please export SFTPBRIDGE_UPLOAD_PREFIX"

yum -q install -y epel-release
yum -q install -y --enablerepo=epel incron nrpe openssh-server \
  yum-cron-security nagios-plugins-users nagios-plugins-disk
# Create forwarder user
id forwarder &> /dev/null || useradd -s /sbin/nologin forwarder
aws s3 cp ${SFTPBRIDGE_CONFIG_PREFIX}/scripts/forward-to-s3.sh /usr/local/bin/forward-to-s3
chmod 0755 /usr/local/bin/forward-to-s3
install -m 0755 -o forwarder -g forwarder -d /var/lock/forward-to-s3
# Allow (only) forwarder to use incron
echo "allowed_users = /etc/incron.allow" > /etc/incron.conf
echo forwarder > /etc/incron.allow
# Setup sshd
rm -f /etc/ssh_host_* /etc/sshd_config
aws s3 cp ${SFTPBRIDGE_CONFIG_PREFIX}/sshd_config /etc/ssh/
aws s3 sync ${SFTPBRIDGE_CONFIG_PREFIX}/ssh-host-keys/ /etc/ssh/
mkdir -p /etc/ssh/authorized_keys
# Environment vars for other scripts
echo "SFTPBRIDGE_USER_PREFIX=${SFTPBRIDGE_USER_PREFIX}
SFTPBRIDGE_CONFIG_PREFIX=${SFTPBRIDGE_CONFIG_PREFIX}
SFTPBRIDGE_UPLOAD_PREFIX=${SFTPBRIDGE_UPLOAD_PREFIX}
SFTPBRIDGE_UPLOAD_ROLEARN=${SFTPBRIDGE_UPLOAD_ROLEARN}
" > /etc/sftp-bridge-environment
chmod 0755 /etc/sftp-bridge-environment
# Group referenced in sshd_config that allows only chrooted sftp access
groupadd -f upload-users
# Script to create the individual upload users
aws s3 cp ${SFTPBRIDGE_CONFIG_PREFIX}/scripts/sync-sftp-uploaders.sh /usr/local/bin/sync-sftp-uploaders
chmod 0755 /usr/local/bin/sync-sftp-uploaders
/usr/local/bin/sync-sftp-uploaders
# Activate relevant services
chkconfig sshd on
chkconfig incrond on
chkconfig nrpe on
service nrpe restart
service incrond restart
service sshd restart

logger -t sftp-bridge-setup -s 'Done'
