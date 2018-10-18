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
KUBECTL=`which kubectl`

# methods
function echoBold () {
    ${ECHO} -e $'\e[1m'"${1}"$'\e[0m'
}

function usage () {
    echoBold "This script automates the installation of WSO2 EI Integrator Analytics Kubernetes resources\n"
    echoBold "Allowed arguments:\n"
    echoBold "-h | --help"
    echoBold "--wu | --wso2-username\t\tYour WSO2 username"
    echoBold "--wp | --wso2-password\t\tYour WSO2 password"
    echoBold "--cap | --cluster-admin-password\tKubernetes cluster admin password\n\n"
}

WSO2_SUBSCRIPTION_USERNAME=''
WSO2_SUBSCRIPTION_PASSWORD=''
ADMIN_PASSWORD=''

# capture named arguments
while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`

    case ${PARAM} in
        -h | --help)
            usage
            exit 1
            ;;
        --wu | --wso2-username)
            WSO2_SUBSCRIPTION_USERNAME=${VALUE}
            ;;
        --wp | --wso2-password)
            WSO2_SUBSCRIPTION_PASSWORD=${VALUE}
            ;;
        --cap | --cluster-admin-password)
            ADMIN_PASSWORD=${VALUE}
            ;;
        *)
            echoBold "ERROR: unknown parameter \"${PARAM}\""
            usage
            exit 1
            ;;
    esac
    shift
done

# create a new Kubernetes Namespace
${KUBECTL} create namespace wso2

# create a new service account in 'wso2' Kubernetes Namespace
${KUBECTL} create serviceaccount wso2svc-account -n wso2

# switch the context to new 'wso2' namespace
${KUBECTL} config set-context $(${KUBECTL} config current-context) --namespace=wso2

# create a Kubernetes Secret for passing WSO2 Private Docker Registry credentials
${KUBECTL} create secret docker-registry wso2creds --docker-server=docker.wso2.com --docker-username=${WSO2_SUBSCRIPTION_USERNAME} --docker-password=${WSO2_SUBSCRIPTION_PASSWORD} --docker-email=${WSO2_SUBSCRIPTION_USERNAME}

# create Kubernetes Role and Role Binding necessary for the Kubernetes API requests made from Kubernetes membership scheme
${KUBECTL} create --username=admin --password=${ADMIN_PASSWORD} -f ../../rbac/rbac.yaml

echoBold 'Creating ConfigMaps...'
# create the IS as Key Manager ConfigMaps
${KUBECTL} create configmap is-as-km-conf --from-file=../confs/is-as-km/
${KUBECTL} create configmap is-as-km-conf-axis2 --from-file=../confs/is-as-km/axis2/
${KUBECTL} create configmap is-as-km-conf-datasources --from-file=../confs/is-as-km/datasources/
# create the APIM Gateway ConfigMaps
${KUBECTL} create configmap apim-gateway-conf --from-file=../confs/apim-gateway/
${KUBECTL} create configmap apim-gateway-conf-axis2 --from-file=../confs/apim-gateway/axis2/
# create the APIM Traffic Manager ConfigMaps
${KUBECTL} create configmap apim-tm-conf --from-file=../confs/apim-tm/
${KUBECTL} create configmap apim-tm-conf-axis2 --from-file=../confs/apim-tm/axis2/
# create the APIM Publisher Store ConfigMaps
${KUBECTL} create configmap apim-pubstore-conf --from-file=../confs/apim-pubstore/
${KUBECTL} create configmap apim-pubstore-conf-axis2 --from-file=../confs/apim-pubstore/axis2/
${KUBECTL} create configmap apim-pubstore-conf-datasources --from-file=../confs/apim-pubstore/datasources/

${KUBECTL} create configmap mysql-dbscripts --from-file=../extras/confs/rdbms/mysql/dbscripts/

# deploy the Kubernetes services
${KUBECTL} create -f ../apim-gw/wso2apim-gateway-service.yaml
${KUBECTL} create -f ../apim-pubstore/wso2apim-pubstore-service.yaml
${KUBECTL} create -f ../apim-tm/wso2apim-tm-1-service.yaml
${KUBECTL} create -f ../apim-tm/wso2apim-tm-2-service.yaml
${KUBECTL} create -f ../apim-tm/wso2apim-tm-3-service.yaml
${KUBECTL} create -f ../apim-tm/wso2apim-tm-service.yaml
${KUBECTL} create -f ../is-as-km/wso2apim-is-as-km-service.yaml

echoBold 'Deploying persistent storage resources...'
${KUBECTL} create -f ../volumes/persistent-volumes.yaml
${KUBECTL} create -f ../extras/rdbms/volumes/persistent-volumes.yaml

# MySQL
echoBold 'Deploying WSO2 API Manager Databases...'
${KUBECTL} create -f ../extras/rdbms/mysql/mysql-persistent-volume-claim.yaml
${KUBECTL} create -f ../extras/rdbms/mysql/mysql-deployment.yaml
${KUBECTL} create -f ../extras/rdbms/mysql/mysql-service.yaml
sleep 30s

echoBold 'Deploying WSO2 Identity Server as Key Manager...'
${KUBECTL} create -f ../is-as-km/wso2apim-is-as-km-volume-claim.yaml
${KUBECTL} create -f ../is-as-km/wso2apim-is-as-km-deployment.yaml
sleep 1m

echoBold 'Deploying WSO2 API Manager Publisher and Store...'
${KUBECTL} create -f ../apim-pubstore/wso2apim-pubstore-deployment.yaml
sleep 1m

echoBold 'Deploying WSO2 API Manager Traffic Manager...'
${KUBECTL} create -f ../apim-tm/wso2apim-tm-volume-claim.yaml
${KUBECTL} create -f ../apim-tm/wso2apim-tm-1-deployment.yaml
${KUBECTL} create -f ../apim-tm/wso2apim-tm-2-deployment.yaml
${KUBECTL} create -f ../apim-tm/wso2apim-tm-3-deployment.yaml
sleep 1m

echoBold 'Deploying WSO2 API Manager Gateway...'
${KUBECTL} create -f ../apim-gw/wso2apim-gateway-volume-claim.yaml
${KUBECTL} create -f ../apim-gw/wso2apim-gateway-deployment.yaml
sleep 1m

echoBold 'Deploying Ingresses...'
${KUBECTL} create -f ../ingresses/wso2apim-gateway-ingress.yaml
${KUBECTL} create -f ../ingresses/wso2apim-ingress.yaml

echoBold 'Finished'
