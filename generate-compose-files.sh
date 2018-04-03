#!/bin/bash

# Generate keys if necessary
if [ ! -f ./compose/cfssl-config/ca.pem ] || [ ! -f ./compose/cfssl-config/ca-key.pem ] ; then
	cd compose/cfssl-config/
	cfssl gencert -initca "csr_root_ca.json" | cfssljson -bare ca
	cd -
fi

# Generate housekeeping & pairing certificates
for f in "housekeeping" "pairing"; do
	if [ ! -f ./compose/astarte-certs/$f.crt ] ; then
		cd compose/astarte-certs/
		openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:2048 -keyout $f.key -out $f.crt -subj "/O=Astarte Internal/CN=$f"
		cd -
	fi
done

# Generate self-signed VerneMQ certificate if necessary
if [ ! -f ./compose/vernemq-certs/cert ] ; then
	cd compose/vernemq-certs/
	openssl req -x509 -sha256 -nodes -days 3650 -newkey rsa:2048 -keyout privkey -out cert -subj "/O=Astarte Internal/CN=vernemq"
	cd -
fi

# Generate secrets in environment if necessary
if [ ! -f ./compose_generated.env ] ; then
cat > compose_generated.env <<EOF
PAIRING_SECRET_KEY_BASE=$(openssl rand -base64 32)
EOF
fi
