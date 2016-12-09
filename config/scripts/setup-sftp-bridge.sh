#!/bin/bash

set -e

die() { echo "$1" ; exit 1 ; }

[ -n "${SFTPBRIDGE_CONFIG_PREFIX}" ] || die "Please export SFTPBRIDGE_CONFIG_PREFIX"
[ -n "${SFTPBRIDGE_USER_PREFIX}" ] || die "Please export SFTPBRIDGE_USER_PREFIX"
[ -n "${SFTPBRIDGE_UPLOAD_PREFIX}" ] || die "Please export SFTPBRIDGE_UPLOAD_PREFIX"

yum -q install -y epel-release
yum -q install -y --enablerepo=epel jq incron nrpe openssh-server \
  yum-cron-security nagios-plugins-users nagios-plugins-disk
chkconfig sshd on
chkconfig incrond on
chkconfig nrpe on
mkdir -p /etc/ssh/authorized_keys
id forwarder &> /dev/null || useradd -s /sbin/nologin forwarder
groupadd -f upload-users
echo "allowed_users = /etc/incron.allow" > /etc/incron.conf
echo forwarder > /etc/incron.allow
rm -f /etc/ssh_host_* /etc/sshd_config
aws s3 cp ${SFTPBRIDGE_CONFIG_PREFIX}/sshd_config /etc/ssh/
aws s3 sync ${SFTPBRIDGE_CONFIG_PREFIX}/ssh-host-keys/ /etc/ssh/
aws s3 cp ${SFTPBRIDGE_CONFIG_PREFIX}/scripts/forward-to-s3.sh /usr/local/bin/forward-to-s3
chmod 0755 /usr/local/bin/forward-to-s3
aws s3 cp ${SFTPBRIDGE_CONFIG_PREFIX}/scripts/sync-sftp-uploaders.sh /usr/local/bin/sync-sftp-uploaders
chmod 0755 /usr/local/bin/sync-sftp-uploaders
echo "SFTPBRIDGE_USER_PREFIX=${SFTPBRIDGE_USER_PREFIX}
SFTPBRIDGE_CONFIG_PREFIX=${SFTPBRIDGE_CONFIG_PREFIX}
SFTPBRIDGE_UPLOAD_PREFIX=${SFTPBRIDGE_UPLOAD_PREFIX}
" > /etc/sftp-bridge-environment
chmod 0755 /etc/sftp-bridge-environment

/usr/local/bin/sync-sftp-uploaders

service nrpe restart
service incrond restart
service sshd restart

logger -t sftp-bridge-setup -s 'Done'
