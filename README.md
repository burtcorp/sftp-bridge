# Sftp-to-S3 upload bridge

Sftp-to-S3 allows you to support scenarios where files should be uploaded to S3 but the uploader cannot support S3 natively. This project provides scripts to build an upload host that provides a special OpenSSH config that provides a group (upload-users) whose members can only do chrooted SFTP.

## Operation

The SFTP session is chrooted to `/srv/sshd-chroot/<username>` and lands the user in `/<username>` (thus resulting in an absolute path `/srv/sshd-chroot/<username>/<username>` because openssh chroot logic). User upload directories are watched by [incron](http://inotify.aiken.cz/?section=incron). When openssh closes (inotify `IN_CLOSE_WRITE`) an uploaded file, incron immediately launches a script that uploads the file to a specified S3 path (overwriting any previous versions of the same S3 object) and then deletes the local copy.

## Upload users

Upload users are ordinary system users with no password set. openssh public keys are uploaded to `SFTPBRIDGE_USER_PREFIX` and can then be synced to the upload bridge by running `/usr/local/bin/sync-sftp-uploaders` on the bridge instance. For new keys, an upload user is created with the same username as the ssh key file. This setup does run user sync on initial setup (to allow it to be used in auto-scaling scenarios), but does not add it to cron.

## Setup

### Preparation

The provided Makefile creates sshd host keys and stores them on S3 so that you can recreate the sftp-bridge instance and create auto-scaling groups where all members look identical.

1. Create upload user SSH keys as necessary:
```
ssh-keygen -t rsa -b 4096 -f <username>
mv <username>.pub ssh-user-keys/
```
... or even better, ask the uploading party to generate one themselves and only send you the public part.

1. Create S3 buckets
Config is read from and files are uploaded to S3 buckets. If you do not already have buckets, you will need to create some and make sure the Sftp bridge instance has access to the buckets.

1. Setup your S3 buckets:
```
make install hostkeys userkeys AWS='aws --region us-east-1' \
  SFTPBRIDGE_CONFIG_PREFIX=s3://config-bucket/sftp-bridge/config/ \
  SFTPBRIDGE_USER_PREFIX=s3://config-bucket/sftp-bridge/ssh-user-keys/
```

### Manual setup

1. Launch an Amazon EC2 instance from the console or with awscli.
1. Configure the instance:
```
ssh ec2-user@<ec2-public-ipv4> cat config/scripts/setup-sftp-bridge.sh | ec2-user@<ip> bash -
```

### CloudFormation setup

1. Setup your S3 buckets:
```
make install hostkeys AWS='aws --region us-east-1' \
  SFTPBRIDGE_CONFIG_PREFIX=s3://config-bucket/sftp-bridge/config/
```

1. Build a stack including an instance (or a launch configuration) with a good userdata section:
```
"SftpBridge": {
  "Type": "AWS::EC2::Instance",
  "Properties": {
    "ImageId": "...",
    "KeyName": "...",
    "SecurityGroups": [ { "Ref": "..." } ],
    "UserData": {
      "Fn::Base64": {
        "Fn::Join": [
          "\n",
          [ "#!/bin/bash",
            "set -e",
            "export SFTPBRIDGE_CONFIG_PREFIX=s3://<ze-bucket>/config",
            "export SFTPBRIDGE_USER_PREFIX=s3://<ze-bucket>/ssh-user-keys",
            "export SFTPBRIDGE_UPLOAD_PREFIX=s3://<ze-bucket>/uploads",
            "aws s3 cp ${SFTPBRIDGE_CONFIG_PREFIX}/scripts/setup-sftp-bridge.sh - | bash" ] ]
      }
    }
  }
}
```

## Not implemented

- sync-sftp-uploaders does not deactivate users that are removed from ssh-user-keys.
