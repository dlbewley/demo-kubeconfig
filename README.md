
# Create Kubeconfig for OpenShift ServiceAccounts

**Blog:**
* https://guifreelife.com

**Related Articles:**
* https://access.redhat.com/solutions/6998487
* https://docs.redhat.com/en/documentation/openshift_container_platform/4.18/html/cli_tools/openshift-cli-oc#oc-create-token

## Demo

[![asciicast](https://asciinema.org/a/713156.svg)](https://asciinema.org/a/713156)

## Detailed Steps

* 🔍 establish default values

```bash
export API_SERVER='api.agent.lab.bewley.net:6443'
export SERVICE_ACCOUNT='demo-sa'
export KUBECONFIG_SA="kubeconfig-$SERVICE_ACCOUNT"
export NAMESPACE='demo-kubeconfig'
export DURATION='1h'
```

* 💻 login to the cluster as admin (See [how I manage kubeconfigs](https://guifreelife.com/blog/2023/09/22/Storing-OpenShift-Credentials-with-1Password/) )

```bash
source ~/.kube/ocp/agent/.env
echo $KUBECONFIG
oc config current-context
oc whoami
```

* 🔑 get the API CA certificate
```bash
export API_CERT=$(oc get secret -n openshift-kube-apiserver-operator loadbalancer-serving-signer -o jsonpath='{.data.tls\.crt}' | base64 -d)
```

* 🔑 get the ingress CA certificate
```bash
export INGRESS_CERT=$(oc get secret -n openshift-ingress-operator router-ca -o jsonpath='{.data.tls\.crt}' | base64 -d)
```

* 🔑 save the certificates to a bundle
```bash
cat <<EOF > ca-bundle.crt
$API_CERT
$INGRESS_CERT
EOF
```

[!TIP] 
> View some details of the CA certificates
> ```bash
> $ echo $API_CERT | openssl x509 -noout -dates -issuer -subject
> notBefore=Mar 17 20:50:37 2025 GMT
> notAfter=Mar 15 20:50:37 2035 GMT
> issuer=OU=openshift, CN=kube-apiserver-lb-signer
> subject=OU=openshift, CN=kube-apiserver-lb-signer
> 
> $ echo $INGRESS_CERT | openssl x509 -noout -dates -issuer -subject 
> notBefore=Mar 17 21:39:50 2025 GMT
> notAfter=Mar 17 21:39:51 2027 GMT
> issuer=CN=ingress-operator@1742247591
> subject=CN=ingress-operator@1742247591
> ```

* 🤖 create a service account
```bash
oc create serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE
```

* 🔑 create a token for the service account that lasts for a limited duration
```bash
export TOKEN=$(oc create token -n $NAMESPACE $SERVICE_ACCOUNT --duration=$DURATION)
```

[!TIP] 
> If you are curious to see the JWT token contents try this:
> ```bash
echo $TOKEN | cut -d '.' -f2 | base64 -d | jq                   
{
  "aud": [
    "https://kubernetes.default.svc"
  ],
  "exp": 1744146844,
  "iat": 1744143244,
  "iss": "https://kubernetes.default.svc",
  "jti": "e4510577-5955-4eb4-9f97-dec4f0e6dc34",
  "kubernetes.io": {
    "namespace": "demo-kubeconfig",
    "serviceaccount": {
      "name": "demo-sa",
      "uid": "73a74060-e67d-4b1a-ad56-e92227732d53"
    }
  },
  "nbf": 1744143244,
  "sub": "system:serviceaccount:demo-kubeconfig:demo-sa"
}

# mac
TS_ISSUED=$(echo $TOKEN | cut -d '.' -f2 | base64 -d | jq '.iat')
TS_EXPIRATION=$(echo $TOKEN | cut -d '.' -f2 | base64 -d | jq '.exp')

# view the issued and expiry times
date -r $TS_EXPIRATION # on MacOS
date -d @$TS_EXPIRATION # on Linux

oc login --server="$API_URL" --token="$TOKEN" --kubeconfig="$KUBECONFIG_SA"
# The server uses a certificate signed by an unknown authority.
# You can bypass the certificate check, but any data you send to the server could be intercepted by others.
# Use insecure connections? (y/n): y

# WARNING: Using insecure TLS client config. Setting this option is not supported!

# Logged into "https://api.agent.lab.bewley.net:6443" as "system:serviceaccount:demo-kubeconfig:demo-sa" using the token provided.

# You have one project on this server: "openshift-virtualization-os-images"

# Using project "openshift-virtualization-os-images".

oc whoami --kubeconfig="$KUBECONFIG_SA"
system:serviceaccount:demo-kubeconfig:demo-sa

# oc create configmap -n $NAMESPACE $SERVICE_ACCOUNT-token --from-literal=token=$TOKEN
# oc create secret generic -n $NAMESPACE $SERVICE_ACCOUNT-token --from-literal=token=$TOKEN

```

```bash
source ~/src/demos/demo-magic/demo-magic.sh
source ~/.kube/ocp/agent/.env
echo $KUBECONFIG
oc whoami
oc new-project demo-kubeconfig \
    --display-name="Demo Kubeconfig Mgmt" \
    --description="See https://github.com/dlbewley/demo-kubeconfig" \
    --skip-config-write
oc get serviceaccounts -n demo-kubeconfig
oc create serviceaccount demo-sa -n demo-kubeconfig

API_CERT=$(oc get secret -n openshift-kube-apiserver-operator loadbalancer-serving-signer -o jsonpath='{.data.tls\.crt}' | base64 -d)
echo $API_CERT | openssl x509 -noout -dates -issuer -subject
notBefore=Mar 17 20:50:37 2025 GMT
notAfter=Mar 15 20:50:37 2035 GMT
issuer=OU=openshift, CN=kube-apiserver-lb-signer
subject=OU=openshift, CN=kube-apiserver-lb-signer

INGRESS_CERT=$(oc get secret -n openshift-ingress-operator router-ca -o jsonpath='{.data.tls\.crt}' | base64 -d)
echo $INGRESS_CERT | openssl x509 -noout -dates -issuer -subject 
notBefore=Mar 17 21:39:50 2025 GMT
notAfter=Mar 17 21:39:51 2027 GMT
issuer=CN=ingress-operator@1742247591
subject=CN=ingress-operator@1742247591

echo $API_CERT > ca-bundle.crt
echo $INGRESS_CERT >> ca-bundle.crt

# verify ca for API
curl --cacert ./ca-bundle.crt https://$API_URL/healthz 
ok%                                                                                          

# modify existing context, but i don't know what that name is yet... it appears to be set to the same value as $API_URL exactly
oc config set-cluster $API_URL --embed-certs --certificate-authority=./ca-bundle.crt --server https://$API_URL --kubeconfig="$KUBECONFIG_SA"

```