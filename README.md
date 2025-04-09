
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

> [!TIP] 
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

* 🔧 create a new project for demo-kubeconfig and do not add context to our current $KUBECONFIG
```bash
oc new-project $NAMESPACE\
 --display-name='Demo SA Kubeconfig Mgmt'\
 --description='See https://github.com/dlbewley/demo-kubeconfig'\
 --skip-config-write
```

* 🤖 create a service account
```bash
oc create serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE
```

* 🔑 create a token for the service account that lasts for a limited duration
```bash
export TOKEN=$(oc create token -n $NAMESPACE $SERVICE_ACCOUNT --duration=$DURATION)
```

* 🔧 create kubeconfig file for $SERVICE_ACCOUNT in $NAMESPACE and avoid insecure connection
```bash
oc login --server=$API_SERVER --token=$TOKEN --certificate-authority=./ca-bundle.crt --kubeconfig=$KUBECONFIG_SA
```

* 🔑 insert the ca-bundle.crt into the kubeconfig file
```bash
oc config set-cluster $API_SERVER --embed-certs --certificate-authority=./ca-bundle.crt --server https://$API_SERVER --kubeconfig="$KUBECONFIG_SA"
```

* ✅ verify using the kubeconfig file works
```bash
oc whoami --kubeconfig=$KUBECONFIG_SA
# 🔒 the service account will have limited permissions until RBAC is configured"
oc get sa --kubeconfig=$KUBECONFIG_SA
```

* 🎉 configure RBAC and provide $KUBECONFIG_SA to your user"

