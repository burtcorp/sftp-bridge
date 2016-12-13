#!/bin/bash

set -e

# TODO: If there is already an upload of this file ongoing, kill it and restart

die() { logger -st sftp-bridge-forward "$1" ; exit 1 ; }

LOCKDIR=/var/lock/forward-to-s3

while getopts "b:p:" opt ; do
  case "$opt" in
    b) S3_PREFIX="$OPTARG" ;;
    p) UPLOADED_PATH="$OPTARG" ;;
    *) die "Unknown parameter $opt" ;;
  esac
done

[ -n "$S3_PREFIX" ] || die "Missing parameter -b <s3_prefix>"
[ -n "$UPLOADED_PATH" ] || die "Missing parameter -p <uploaded file>"

uploadfile=$(basename "$UPLOADED_PATH")
uploadfile=$(echo "$uploadfile" | tr -dC 'A-Za-z0-9_.')
target=${S3_PREFIX}/${uploadfile}
lock=${LOCKDIR}/$(echo "$target" | base64)

sleep 1

if [ -f $lock ] ; then
  pid=$(cat $lock)
  kill $pid || true
  rm $lock
fi
trap "rm $lock" SIGTERM EXIT
echo $$ > $lock

retries=10
until aws s3 cp "$UPLOADED_PATH" "$target" ; do
  if (( retries == 0 )) ; then die "Failed to upload $UPLOADED_PATH to $target" ; fi
  retries=$(( retries - 1 ))
  sleep 60
done
rm -f "$UPLOADED_PATH"

logger -t sftp-bridge-forward "Uploaded ${uploadfile}"
