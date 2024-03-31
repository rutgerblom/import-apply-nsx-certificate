# import-apply-nsx-certificate
A shell script that imports and applies a TLS certificate to the NSX Manager API/UI.

## Preparations
On a Ubuntu 22.04 machine.

1. Install the required packages:
    ```
    sudo apt update && sudo apt install git curl jq
    ```
2. Clone this repository to your local machine:
    ```
    git clone https://github.com/rutgerblom/import-apply-nsx-certificate.git ~/git/import-apply-nsx-certificate
    ```
3. Make the shell script executable:
    ```
    chmod +x ~/git/import-apply-nsx-certificate/import-apply-nsx-certificate.sh
    ```

## Usage

### Example workflow where signed certificate and key are provided beforehand
Tested on Ubuntu 22.04.

1. Before exporting these variables make sure that the values match your environment:
   ```
   export NSX_MANAGER_FQDN="pod-240-nsxt-lm.sddc.lab"
   export NSX_USER="admin"
   export NSX_PASSWORD='VMware1!VMware1!'
   export CERTIFICATE_CRT=/tmp/certificate_chain.pem
   export CERTIFICATE_KEY=/tmp/key.pem
   ```
2. Copy the signed certificate (chain) and key to the location and name as specified by the```$CERTIFICATE_CRT``` and ```$CERTIFICATE_KEY``` variables.
3. Run the script to import and apply the TLS certificate to the NSX Manager(s).
   ```
   ~/git/import-apply-nsx-certificate/import-apply-nsx-certificate.sh
   ```

### Example workflow where certificate chain and key are created using Easy-RSA
Tested on Ubuntu 22.04.

1. Before exporting these variables make sure that the values match your environment:
   ```
   export NSX_MANAGER_HOST_NAME="pod-240-nsxt-lm"
   export NSX_MANAGER_DOMAIN_NAME="sddc.lab"
   export NSX_MANAGER_FQDN=$NSX_MANAGER_HOST_NAME.$NSX_MANAGER_DOMAIN_NAME
   export NSX_USER="admin"
   export NSX_PASSWORD='VMware1!VMware1!'
   export EASY_RSA_PKI_DIR=~/ea
   export CERTIFICATE_COUNTRY="SE"
   export CERTIFICATE_STATE="Lund"
   export CERTIFICATE_LOCALITY="Lund"
   export CERTIFICATE_ORGANIZATION="HomeLab"
   export CERTIFICATE_EMAIL="pki-admin@$NSX_MANAGER_DOMAIN_NAME"
   export CERTIFICATE_CNF_FILE=~/$NSX_MANAGER_FQDN.cnf
   export CERTIFICATE_WORKING_DIR="/tmp/"
   export CERTIFICATE_CRT=$CERTIFICATE_WORKING_DIR$NSX_MANAGER_FQDN.crt
   export CERTIFICATE_KEY=$CERTIFICATE_WORKING_DIR$NSX_MANAGER_FQDN.key
   ```
2. Install the [Easy-RSA](https://github.com/OpenVPN/easy-rsa) package:
   ```
   sudo apt install easy-rsa
   ```
3. Create a PKI directory:
   ```
   mkdir $EASY_RSA_PKI_DIR
   ```
4. Create an Easy-RSA vars file in the PKI directory:
   ```
   cat >$EASY_RSA_PKI_DIR/vars <<EOF
   set_var EASYRSA_PKI "$EASY_RSA_PKI_DIR/pki"
   set_var EASYRSA_REQ_COUNTRY "$CERTIFICATE_COUNTRY"
   set_var EASYRSA_REQ_PROVINCE "$CERTIFICATE_STATE"
   set_var EASYRSA_REQ_CITY "$CERTIFICATE_LOCALITY"
   set_var EASYRSA_REQ_ORG "$CERTIFICATE_ORGANIZATION"
   set_var EASYRSA_REQ_EMAIL "$CERTIFICATE_EMAIL"
   set_var EASYRSA_ALGO rsa
   set_var EASYRSA_DIGEST "sha512"
   EOF
   ```
5. Initialize the PKI directory:
   ```
   /usr/share/easy-rsa/easyrsa --vars=$EASY_RSA_PKI_DIR/vars init-pki
   ```

6. Create a new CA in the PKI:
   ```
   /usr/share/easy-rsa/easyrsa --vars=$EASY_RSA_PKI_DIR/vars build-ca
   ```
7. Prepare an OpenSSL cnf file:
   ```
   cat >$CERTIFICATE_CNF_FILE <<EOF
   [ req ]
   default_bits       = 2048
   default_keyfile    = server-key.pem 
   distinguished_name = subject
   req_extensions     = req_ext
   string_mask        = utf8only
   
   [ subject ]
   countryName                 = Country Name (2 letter code)
   countryName_default         = $CERTIFICATE_COUNTRY
   stateOrProvinceName         = State or Province Name (full name)
   stateOrProvinceName_default = $CERTIFICATE_STATE
   localityName                = Locality Name (eg, city)
   localityName_default        = $CERTIFICATE_LOCALITY
   organizationName            = Organization Name (eg, company)
   organizationName_default    = $CERTIFICATE_ORGANIZATION
   commonName                  = Common Name (e.g. server FQDN or YOUR name)
   commonName_default          = $NSX_MANAGER_FQDN
   emailAddress                = Email Address
   emailAddress_default        = $CERTIFICATE_EMAIL
   
   [ req_ext ]
   subjectKeyIdentifier = hash
   basicConstraints     = CA:FALSE
   keyUsage             = digitalSignature, keyEncipherment
   subjectAltName       = @alternate_names
   nsComment            = "OpenSSL Generated Certificate"
   extendedKeyUsage     = serverAuth, clientAuth
   
   [ alternate_names ]
   DNS.1 = $NSX_MANAGER_HOST_NAME.$NSX_MANAGER_DOMAIN_NAME
   DNS.2 = $NSX_MANAGER_HOST_NAME
   DNS.3 = $NSX_MANAGER_HOST_NAME-1.$NSX_MANAGER_DOMAIN_NAME
   DNS.4 = $NSX_MANAGER_HOST_NAME-1
   DNS.5 = $NSX_MANAGER_HOST_NAME-2.$NSX_MANAGER_DOMAIN_NAME
   DNS.6 = $NSX_MANAGER_HOST_NAME-2
   DNS.7 = $NSX_MANAGER_HOST_NAME-3.$NSX_MANAGER_DOMAIN_NAME
   DNS.8 = $NSX_MANAGER_HOST_NAME-3
   EOF
   ```
8. Create a private key and store it in the working directory`:
   ```
   openssl genrsa -out $CERTIFICATE_KEY 2048
   ```
9. Create a certificate signing request (CSR) and store it in the working directory: 
   ```
   openssl req -new -nodes -out $CERTIFICATE_WORKING_DIR$NSX_MANAGER_FQDN.csr -keyout $CERTIFICATE_KEY -config $CERTIFICATE_CNF_FILE
   ```
10. Import the certificate signing request to easy-rsa: 
    ```
    /usr/share/easy-rsa/easyrsa --vars=$EASY_RSA_PKI_DIR/vars import-req $CERTIFICATE_WORKING_DIR$NSX_MANAGER_FQDN.csr $NSX_MANAGER_FQDN
    ```
11. Sign the request: 
    ```
    /usr/share/easy-rsa/easyrsa --vars=$EASY_RSA_PKI_DIR/vars sign-req server $NSX_MANAGER_FQDN
    ```
12. Copy the signed certificate to the working directory: 
    ```
    cat $EASY_RSA_PKI_DIR/pki/issued/$NSX_MANAGER_FQDN.crt | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' > $CERTIFICATE_CRT
    ```
13. Append the CA certificate to the signed certificate to create the chain: 
    ```
    cat $EASY_RSA_PKI_DIR/pki/ca.crt >> $CERTIFICATE_CRT
    ```
14. Run the script to import and apply the TLS certificate to the NSX Manager(s).
    ```
    ~/git/import-apply-nsx-certificate/import-apply-nsx-certificate.sh
    ```