SFTPBRIDGE_CONFIG_PREFIX=
SFTPBRIDGE_USER_PREFIX=

AWS=aws

need-config-prefix:
	@[ -n "$(SFTPBRIDGE_CONFIG_PREFIX)" ] || { echo "Please set SFTPBRIDGE_CONFIG_PREFIX to s3://..." ; exit 1 ; }

need-user-prefix:
	@[ -n "$(SFTPBRIDGE_USER_PREFIX)" ] || { echo "Please set SFTPBRIDGE_USER_PREFIX to s3://..." ; exit 1 ; }

ssh-host-keys:
	install -d $@

ssh-host-keys/ssh_host_rsa_key: ssh-host-keys
	ssh-keygen -f $@ -N '' -t rsa

ssh-host-keys/ssh_host_ecdsa_key:
	ssh-keygen -f $@ -N '' -t ecdsa

ssh-host-keys/ssh_host_ed25519_key:
	ssh-keygen -f $@ -N '' -t ed25519

hostkeys: need-config-prefix \
		ssh-host-keys/ssh_host_rsa_key \
		ssh-host-keys/ssh_host_ecdsa_key \
		ssh-host-keys/ssh_host_ed25519_key
	$(AWS) s3 sync ssh-host-keys/ $(SFTPBRIDGE_CONFIG_PREFIX)/ssh-host-keys/

userkeys: need-user-prefix
	$(AWS) s3 sync ssh-user-keys/ $(SFTPBRIDGE_USER_PREFIX)

install: need-config-prefix
	$(AWS) s3 sync config/ $(SFTPBRIDGE_CONFIG_PREFIX)

.PHONY: hostkeys install
