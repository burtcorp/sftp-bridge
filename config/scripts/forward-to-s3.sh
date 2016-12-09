#!/bin/bash

# TODO: Ensure that our stdout/err ends up in log file
# TODO: If there is already an upload of this file ongoing, kill it and restart

die() { echo "$1" ; exit 1 ; }

while getopts "b:p:" opt ; do
  case "$opt" in
    b) S3_BUCKET="$OPTARG" ;;
    p) UPLOADED_PATH="$OPTARG" ;;
    *) die "Unknown parameter $opt" ;;
  esac
done

[ -n "$S3_BUCKET" ] || die "Missing parameter -b <bucket>"
[ -n "$UPLOADED_PATH" ] || die "Missing parameter -p <uploaded file>"

uploadfile="$(basename $UPLOADED_PATH)"
uploadfile="$(echo $uploadfile | tr -dC 'A-Za-z0-9_')"

sleep 1

# aws s3 cp $UPLOADED_PATH "$SFTPBRIDGE_UPLOAD_PREFIX/$prefix/$uploadfile"
rm -f $UPLOADED_PATH

logger -t sftp-bridge-forward "Uploaded ${uploadfile}"
