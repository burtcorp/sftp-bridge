SFTPBRIDGE_CONFIG_PREFIX=s3://bittrance-test-bucket/config/
SFTPBRIDGE_USER_PREFIX=s3://bittrance-test-bucket/ssh-user-keys/

AWS=aws

ssh-host-keys:
	install -d $@

ssh-host-keys/ssh_host_rsa_key: ssh-host-keys
	ssh-keygen -f $@ -N '' -t rsa

ssh-host-keys/ssh_host_ecdsa_key:
	ssh-keygen -f $@ -N '' -t ecdsa

ssh-host-keys/ssh_host_ed25519_key:
	ssh-keygen -f $@ -N '' -t ed25519

hostkeys: \
		ssh-host-keys/ssh_host_rsa_key \
		ssh-host-keys/ssh_host_ecdsa_key \
		ssh-host-keys/ssh_host_ed25519_key
	$(AWS) s3 sync ssh-host-keys/ $(SFTPBRIDGE_CONFIG_PREFIX)/ssh-host-keys/

userkeys:
	$(AWS) s3 sync ssh-user-keys/ $(SFTPBRIDGE_USER_PREFIX)

install:
	$(AWS) s3 sync config/ $(SFTPBRIDGE_CONFIG_PREFIX)

.PHONY: hostkeys install
