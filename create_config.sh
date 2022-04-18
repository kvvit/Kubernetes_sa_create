#!/bin/bash
#--------------------------------create serviceaccount-----------------------------------------------------------------------
export NAMESPACE=default
read -p 'Please, enter the username: ' USER_NAME
kubectl -n ${NAMESPACE} create serviceaccount ${USER_NAME}
#--------------------------------create clusterrolebinding-------------------------------------------------------------------
cat << EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${USER_NAME}           
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: ${USER_NAME}           
  namespace: ${NAMESPACE}
EOF
#---------------------------------create config-------------------------------------------------------------------------------
export USER_TOKEN_NAME=$(kubectl -n ${NAMESPACE} get serviceaccount ${USER_NAME} -o=jsonpath='{.secrets[0].name}')
export USER_TOKEN_VALUE=$(kubectl -n ${NAMESPACE} get secret/${USER_TOKEN_NAME} -o=go-template='{{.data.token}}' | base64 --decode)
export CURRENT_CONTEXT=$(kubectl config current-context)
export CURRENT_CLUSTER=$(kubectl config view --raw -o=go-template='{{range .contexts}}{{if eq .name "'''${CURRENT_CONTEXT}'''"}}{{ index .context "cluster" }}{{end}}{{end}}')
export CLUSTER_CA=$(kubectl config view --raw -o=go-template='{{range .clusters}}{{if eq .name "'''${CURRENT_CLUSTER}'''"}}"{{with index .cluster "certificate-authority-data" }}{{.}}{{end}}"{{ end }}{{ end }}')
export CLUSTER_SERVER=$(kubectl config view --raw -o=go-template='{{range .clusters}}{{if eq .name "'''${CURRENT_CLUSTER}'''"}}{{ .cluster.server }}{{end}}{{ end }}')
#-----------------------------------------------------------------------------------------------------------------------------
cat << EOF > ${USER_NAME}-config           
apiVersion: v1
kind: Config
current-context: ${CURRENT_CONTEXT}
contexts:
- name: ${CURRENT_CONTEXT}
  context:
    cluster: ${CURRENT_CONTEXT}
    user: ${USER_NAME}           
    namespace: ${NAMESPACE}    
clusters:
- name: ${CURRENT_CONTEXT}
  cluster:
    certificate-authority-data: ${CLUSTER_CA}
    server: ${CLUSTER_SERVER}
users:
- name: ${USER_NAME}
  user:
    token: ${USER_TOKEN_VALUE}
EOF

