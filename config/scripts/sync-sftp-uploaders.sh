#!/bin/bash

set -e

. /etc/sftp-bridge-environment

list-userkeys() {
  aws s3 ls ${SFTPBRIDGE_USER_PREFIX}/ | awk '{ print $4 }'
}

upload-user() {
  local username=$1
  install -o root -g root -m 0755 -d /srv/sshd-chroot/${username}
  useradd -s /sbin/nologin -K UMASK=007 -m -k none \
    -G upload-users -d /${username} ${username}
  install -o ${username} -g ${username} -m 0770 -d /srv/sshd-chroot/${username}/${username}
}

list-userkeys | while read userkey ; do
  username=$(basename ${userkey} .pub)
  id ${username} &> /dev/null || upload-user ${username}
  usermod -a -G ${username} forwarder
  echo "/srv/sshd-chroot/${username}/${username}/ IN_CLOSE_WRITE /usr/local/bin/forward-to-s3 -b ${SFTPBRIDGE_UPLOAD_PREFIX} -p" '$@/$#' | incrontab -u forwarder -
  install -o ${username} -g ${username} -m 0600 /dev/null \
      /etc/ssh/authorized_keys/${username}
  aws s3 cp ${SFTPBRIDGE_USER_PREFIX}/${userkey} - \
      > /etc/ssh/authorized_keys/${username}
done
