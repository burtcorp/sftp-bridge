#!/bin/bash

set -e

die() { logger -st sftp-bridge-forward "$1" ; exit 1 ; }

LOCKDIR=/var/lock/forward-to-s3

. /etc/sftp-bridge-environment

while getopts "f:p:" opt ; do
  case "$opt" in
    f) FOLDER_PREFIX="$OPTARG" ;;
    p) UPLOADED_PATH="$OPTARG" ;;
    *) die "Unknown parameter $opt" ;;
  esac
done

[ -n "$UPLOADED_PATH" ] || die "Missing parameter -p <uploaded file>"

uploadfile=$(basename "$UPLOADED_PATH")
uploadfile=$(echo "$uploadfile" | tr -dC '-A-Za-z0-9_.')
target=${SFTPBRIDGE_UPLOAD_PREFIX}/${FOLDER_PREFIX}/${uploadfile}
lock=${LOCKDIR}/$(echo "$target" | base64 -w0)

if  [ -n "$SFTPBRIDGE_UPLOAD_ROLEARN" ] ; then
  assume_args="--role-arn $SFTPBRIDGE_UPLOAD_ROLEARN --role-session-name forward-to-s3 --query Credentials --output text"
  credentials=($(aws sts assume-role $assume_args))
  export AWS_ACCESS_KEY_ID="${credentials[0]}"
  export AWS_SECRET_ACCESS_KEY="${credentials[2]}"
  export AWS_SESSION_TOKEN="${credentials[3]}"
fi

if [ -f $lock ] ; then
  pid=$(cat $lock)
  kill $pid || true
  rm $lock
fi
trap "rm -f $lock" SIGTERM SIGINT EXIT
echo $$ > $lock

retries=10
until aws s3 cp --quiet "$UPLOADED_PATH" "$target" ; do
  if (( retries == 0 )) ; then die "Failed to upload $UPLOADED_PATH to $target" ; fi
  retries=$(( retries - 1 ))
  sleep 60
done
rm -f "$UPLOADED_PATH"

logger -t sftp-bridge-forward "Uploaded ${uploadfile}"
