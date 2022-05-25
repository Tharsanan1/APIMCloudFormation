isEmpty () {
    if [ ${#1} -ge 1 ];
        then 
            return 0;
    else
        return 1;
    fi;
}

isEmpty "${APIM_EKS_CLUSTER_NAME}";
flag=$?
if [ $flag = 1 ];
    then echo "APIM_EKS_CLUSTER_NAME environment variable is empty."; exit 1
fi;

isEmpty "${APIM_CLUSTER_REGION}";
flag=$?
if [ $flag = 1 ];
    then echo "APIM_CLUSTER_REGION environment variable is empty."; exit 1
fi;

isEmpty "${APIM_RDS_STACK_NAME}";
flag=$?
if [ $flag = 1 ];
    then echo "APIM_RDS_STACK_NAME environment variable is empty."; exit 1
fi;


workingdir=$(pwd)
reldir=`dirname $0`
cd $reldir

eksctl get cluster --region ${APIM_CLUSTER_REGION} -n ${APIM_EKS_CLUSTER_NAME} || { echo 'Cluster does not exists. Please create the cluster before deploying the applications.';  exit 1; }
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission || echo "WARNING : Failed to delete nginx admission."
eksctl scale nodegroup --region ${APIM_CLUSTER_REGION} --cluster ${APIM_EKS_CLUSTER_NAME} --name ng-1 --nodes=1 || { echo 'Failed to scale the node group.';  exit 1; }
dbPassword=$(echo $RANDOM | md5sum | head -c 8)
echo "DB password : $dbPassword"
aws cloudformation create-stack --region ${APIM_CLUSTER_REGION} --stack-name ${APIM_RDS_STACK_NAME}   --template-body file://apim-rds-cf.yaml --parameters ParameterKey=pDbUser,ParameterValue=root ParameterKey=pDbPass,ParameterValue="$dbPassword" || { echo 'Failed to create RDS stack.';  exit 1; }
aws cloudformation wait stack-create-complete --region ${APIM_CLUSTER_REGION} --stack-name ${APIM_RDS_STACK_NAME} || { echo 'RDS stack creation timeout.';  exit 1; }
dbPort=$(aws cloudformation describe-stacks --stack-name "${APIM_RDS_STACK_NAME}" --region "${APIM_CLUSTER_REGION}" --query 'Stacks[?StackName==`'$APIM_RDS_STACK_NAME'`][].Outputs[?OutputKey==`ApimDBJDBCPort`].OutputValue' --output text | xargs)
dbHost=$(aws cloudformation describe-stacks --stack-name "${APIM_RDS_STACK_NAME}" --region "${APIM_CLUSTER_REGION}" --query 'Stacks[?StackName==`'$APIM_RDS_STACK_NAME'`][].Outputs[?OutputKey==`ApimDBJDBCConnectionString`].OutputValue' --output text | xargs)
echo "db details DB port : $dbPort, DB host : $dbHost"

isEmpty "${dbPort}";
flag=$?
if [ $flag = 1 ];
    then echo "Extracted db port value is empty."; exit 1
fi;

isEmpty "${dbHost}";
flag=$?
if [ $flag = 1 ];
    then echo "Extracted DB host is empty."; exit 1
fi;


mysql -h "$dbHost" -P "$dbPort" -u root -p"$dbPassword" < wso2-am-db-cripts.sql || { echo 'Failed ton setup RDS database.';  exit 1; }

aws s3 cp s3://apim-test-grid/profile-automation/kube-config ~/.kube/config ||  { echo 'Failed to copy kube config file from S3 bucket.';  exit 1; }
sed -i 's/v1alpha1/v1beta1/' ~/.kube/config
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=240s ||  { echo 'Nginx service is not ready within the expected time limit.';  exit 1; }

helm repo add wso2 https://helm.wso2.com && helm repo update ||  { echo 'Error while adding WSO2 helm repository to helm.';  exit 1; }
helm dependency build "kubernetes-apim/${path_to_helm_folder}" ||  { echo 'Error while building helm folder : kubernetes-apim/${path_to_helm_folder}.';  exit 1; }
helm install apim "kubernetes-apim/${path_to_helm_folder}" --set wso2.deployment.am.mysql.hostname="$dbHost" --set wso2.deployment.am.mysql.port="$dbPort" ||  { echo 'Error while instaling APIM to cluster.';  exit 1; }


cd "$workingdir"