#!/bin/bash
# ------------------------------------------------------------------------
# Copyright 2017 WSO2, Inc. (http://wso2.com)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License
# ------------------------------------------------------------------------

set -e

ECHO=`which echo`
KUBERNETES_CLIENT=`which kubectl`

# methods
function echoBold () {
    ${ECHO} -e $'\e[1m'"${1}"$'\e[0m'
}

# create a new Kubernetes Namespace
#${KUBERNETES_CLIENT} create namespace wso2

# create a new service account in 'wso2' Kubernetes Namespace
${KUBERNETES_CLIENT} create serviceaccount wso2svc-account -n wso2

# switch the context to new 'wso2' namespace
${KUBERNETES_CLIENT} config set-context $(${KUBERNETES_CLIENT} config current-context) --namespace=wso2

# create Kubernetes Role and Role Binding necessary for the Kubernetes API requests made from Kubernetes membership scheme
${KUBERNETES_CLIENT} create -f ../../rbac/rbac.yaml

echoBold 'Creating Kubernetes ConfigMaps for WSO2 product configurations...'
# create the APIM Analytics ConfigMaps
${KUBERNETES_CLIENT} create configmap apim-analytics-conf-worker --from-file=../confs/apim-analytics/
# create the Kubernetes ConfigMaps for API Manager's KeyManager
#${KUBERNETES_CLIENT} create configmap apim-km-conf --from-file=../confs/apim-km/
#${KUBERNETES_CLIENT} create configmap apim-km-conf-axis2 --from-file=../confs/apim-km/axis2/
#${KUBERNETES_CLIENT} create configmap apim-km-conf-datasources --from-file=../confs/apim-km/datasources/
# create the Kubernetes ConfigMaps for Identity Server as Key Manager
${KUBERNETES_CLIENT} create configmap apim-is-as-km-conf --from-file=../confs/apim-is-as-km/
${KUBERNETES_CLIENT} create configmap apim-is-as-km-conf-axis2 --from-file=../confs/apim-is-as-km/axis2/
${KUBERNETES_CLIENT} create configmap apim-is-as-km-conf-datasources --from-file=../confs/apim-is-as-km/datasources/
# create the Kubernetes ConfigMaps for API Manager's Publisher-Store-TM
${KUBERNETES_CLIENT} create configmap apim-pub-store-tm-1-conf --from-file=../confs/apim-pub-store-tm-1/
${KUBERNETES_CLIENT} create configmap apim-pub-store-tm-1-conf-axis2 --from-file=../confs/apim-pub-store-tm-1/axis2/
${KUBERNETES_CLIENT} create configmap apim-pub-store-tm-1-conf-datasources --from-file=../confs/apim-pub-store-tm-1/datasources/
${KUBERNETES_CLIENT} create configmap apim-pub-store-tm-2-conf --from-file=../confs/apim-pub-store-tm-2/
${KUBERNETES_CLIENT} create configmap apim-pub-store-tm-2-conf-axis2 --from-file=../confs/apim-pub-store-tm-2/axis2/
${KUBERNETES_CLIENT} create configmap apim-pub-store-tm-2-conf-datasources --from-file=../confs/apim-pub-store-tm-2/datasources/
# create the Kubernetes ConfigMaps for API Manager's Gateway
${KUBERNETES_CLIENT} create configmap apim-gateway-conf --from-file=../confs/apim-gateway/
${KUBERNETES_CLIENT} create configmap apim-gateway-conf-axis2 --from-file=../confs/apim-gateway/axis2

# Kubernetes MySQL deployment (recommended only for evaluation purposes)
echoBold 'Deploying WSO2 API Manager Databases in MySQL...'
# create a Kubernetes ConfigMap for MySQL database initialization script
${KUBERNETES_CLIENT} create configmap mysql-dbscripts --from-file=../extras/confs/rdbms/mysql/dbscripts/
# create Kubernetes persistent storage resources for persisting database data
${KUBERNETES_CLIENT} create -f ../extras/rdbms/volumes/persistent-volumes.yaml
${KUBERNETES_CLIENT} create -f ../extras/rdbms/mysql/mysql-persistent-volume-claim.yaml
# create a Kubernetes Deployment for MySQL
${KUBERNETES_CLIENT} create -f ../extras/rdbms/mysql/mysql-deployment.yaml
# create a Kubernetes Service for MySQL
${KUBERNETES_CLIENT} create -f ../extras/rdbms/mysql/mysql-service.yaml
sleep 30s

echoBold 'Creating Kubernetes Services...'
${KUBERNETES_CLIENT} create -f ../apim-analytics/wso2apim-analytics-service.yaml
#${KUBERNETES_CLIENT} create -f ../apim-km/wso2apim-km-service.yaml
${KUBERNETES_CLIENT} create -f ../apim-is-as-km/wso2apim-is-as-km-service.yaml
${KUBERNETES_CLIENT} create -f ../apim-pub-store-tm/wso2apim-pub-store-tm-1-service.yaml
${KUBERNETES_CLIENT} create -f ../apim-pub-store-tm/wso2apim-pub-store-tm-2-service.yaml
${KUBERNETES_CLIENT} create -f ../apim-pub-store-tm/wso2apim-pub-store-tm-service.yaml
${KUBERNETES_CLIENT} create -f ../apim-gw/wso2apim-gateway-service.yaml

echoBold 'Deploying Kubernetes persistent storage resources...'
${KUBERNETES_CLIENT} create -f ../volumes/persistent-volumes.yaml

echoBold 'Deploying WSO2 API Manager Analytics...'
${KUBERNETES_CLIENT} create -f ../apim-analytics/wso2apim-analytics-deployment.yaml
sleep 1m

#echoBold 'Deploying WSO2 API Manager Key Manager...'
#${KUBERNETES_CLIENT} create -f ../apim-km/wso2apim-km-deployment.yaml
#sleep 3m

echoBold 'Deploying WSO2 Identity Server as Key Manager...'
${KUBERNETES_CLIENT} create -f ../apim-is-as-km/wso2apim-is-as-km-volume-claim.yaml
${KUBERNETES_CLIENT} create -f ../apim-is-as-km/wso2apim-is-as-km-deployment.yaml
sleep 3m

echoBold 'Deploying WSO2 API Manager Publisher-Store-Traffic-Manager...'
${KUBERNETES_CLIENT} create -f ../apim-pub-store-tm/wso2apim-pub-store-tm-volume-claim.yaml
${KUBERNETES_CLIENT} create -f ../apim-pub-store-tm/wso2apim-pub-store-tm-1-deployment.yaml
sleep 2m
${KUBERNETES_CLIENT} create -f ../apim-pub-store-tm/wso2apim-pub-store-tm-2-deployment.yaml
sleep 3m

echoBold 'Deploying WSO2 API Manager Gateway...'
${KUBERNETES_CLIENT} create -f ../apim-gw/wso2apim-gateway-volume-claim.yaml
${KUBERNETES_CLIENT} create -f ../apim-gw/wso2apim-gateway-deployment.yaml
sleep 4m

echoBold 'Deploying Kubernetes Ingresses...'
${KUBERNETES_CLIENT} create -f ../ingresses/wso2apim-gateway-ingress.yaml
${KUBERNETES_CLIENT} create -f ../ingresses/wso2apim-ingress.yaml

echoBold 'Finished'
echo 'To access the WSO2 API Manager Management console, try https://wso2apim/carbon in your browser.'
echo 'To access the WSO2 API Manager Publisher, try https://wso2apim/publisher in your browser.'
echo 'To access the WSO2 API Manager Store, try https://wso2apim/store in your browser.'
