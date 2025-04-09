#!/bin/bash

# git clone https://github.com/paxtonhare/demo-magic.git
source ~/src/demos/demo-magic/demo-magic.sh
TYPE_SPEED=100
PROMPT_TIMEOUT=2
DEMO_PROMPT="${CYAN}\W ${GREEN}$ ${COLOR_RESET}"
DEMO_COMMENT_COLOR=$GREEN
GIT_ROOT=$(git rev-parse --show-toplevel)
DEMO_ROOT=$GIT_ROOT

# https://archive.zhimingwang.org/blog/2015-09-21-zsh-51-and-bracketed-paste.html
#unset zle_bracketed_paste
clear
p "📺 Demonstration of creating a kubeconfig file for a service account with"
p "CA material included."
p

p "# 💻 login to the cluster as admin"
source ~/.kube/ocp/agent/.env 2&>/dev/null
p "echo \$KUBECONFIG"
echo $KUBECONFIG
pei "oc config current-context"
pei "oc whoami"
p

p "# 🔑 get the API CA certificate"
p "export API_CERT=\$(oc get secret -n openshift-kube-apiserver-operator loadbalancer-serving-signer -o jsonpath='{.data.tls\.crt}' | base64 -d)"
export API_CERT=$(oc get secret -n openshift-kube-apiserver-operator loadbalancer-serving-signer -o jsonpath='{.data.tls\.crt}' | base64 -d)

p "# 🔑 get the ingress CA certificate"
p "export INGRESS_CERT=\$(oc get secret -n openshift-ingress-operator router-ca -o jsonpath='{.data.tls\.crt}' | base64 -d)"
export INGRESS_CERT=$(oc get secret -n openshift-ingress-operator router-ca -o jsonpath='{.data.tls\.crt}' | base64 -d)

p "# 🔑 save the certificates to a bundle"
p "cat <<EOF > ca-bundle.crt \n\
\$API_CERT \n\
\$INGRESS_CERT \n\
EOF"
cat <<EOF > ca-bundle.crt
$API_CERT
$INGRESS_CERT
EOF
p

p "# 🔍 establish default values"
pei "export API_SERVER='api.agent.lab.bewley.net:6443'"
pei "export SERVICE_ACCOUNT='demo-sa'"
pei "export KUBECONFIG_SA="'"kubeconfig-$SERVICE_ACCOUNT"'""
pei "export NAMESPACE='demo-kubeconfig'"
pei "export DURATION='1h'"
p

p "# ✅ show that the ca-bundle.crt file validates the API connection"
pei "curl --cacert ca-bundle.crt https://$API_SERVER/healthz"
echo
p

p "# 🔧 create a new project for demo-kubeconfig and do not add context to our current \$KUBECONFIG"
pei "oc new-project $NAMESPACE\
 --display-name='Demo SA Kubeconfig Mgmt'\
 --description='See https://github.com/dlbewley/demo-kubeconfig'\
 --skip-config-write"

p "# 🤖 create a service account in the new project"
pei "oc create serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE"
pei "oc get serviceaccounts -n $NAMESPACE"
p

p "# 🔑 create a token for the service account"
p "export TOKEN=\$(oc create token -n \$NAMESPACE \$SERVICE_ACCOUNT --duration=\$DURATION)"
export TOKEN=$(oc create token -n $NAMESPACE $SERVICE_ACCOUNT --duration=$DURATION)
p

p "# 🔧 create kubeconfig file for $SERVICE_ACCOUNT in $NAMESPACE and avoid insecure connection"
p "oc login --server=\$API_SERVER --token=\$TOKEN --certificate-authority=./ca-bundle.crt --kubeconfig=\$KUBECONFIG_SA"
oc login --server=$API_SERVER --token=$TOKEN --certificate-authority=./ca-bundle.crt --kubeconfig=$KUBECONFIG_SA

p "# 🔑 insert the ca-bundle.crt into the kubeconfig file"
p "oc config set-cluster \$API_SERVER --embed-certs --certificate-authority=./ca-bundle.crt --server https://\$API_SERVER --kubeconfig=\$KUBECONFIG_SA"
oc config set-cluster $API_SERVER --embed-certs --certificate-authority=./ca-bundle.crt --server https://$API_SERVER --kubeconfig="$KUBECONFIG_SA"
p

p "# ✅ show the certificate-authority-data and token in the kubeconfig file"
pei "bat -l yaml $KUBECONFIG_SA"

p "# ✅ verify using the kubeconfig file works"
pei "oc whoami --kubeconfig=$KUBECONFIG_SA"
p
p "# 🔒 the service account will have limited permissions until RBAC is configured"
pei "oc get sa --kubeconfig=$KUBECONFIG_SA"
p
p "# 🎉 configure RBAC and provide $KUBECONFIG_SA to your user"
