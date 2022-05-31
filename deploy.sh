workingdir=$(pwd)
reldir=`dirname $0`
cd $reldir

source ./utils.sh


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

isEmpty "${path_to_helm_folder}";
flag=$?
if [ $flag = 1 ];
    then echo "Path to helm folder is empty."; exit 1
fi;

isEmpty "${product_version}";
flag=$?
if [ $flag = 1 ];
    then echo "Product version is empty."; exit 1
fi;

isEmpty "${db_engine}";
flag=$?
if [ $flag = 1 ];
    then echo "DB engine value is empty."; exit 1
fi;

dbDriver=""
driverUrl=""
dbType=""
dbUserNameAPIM="wso2carbon"
dbPasswordAPIM="wso2carbon"
dbUserNameAPIMShared="wso2carbon"
dbPasswordAPIMShared="wso2carbon"
dbAPIMUrl=""
dbAPIMDSharedUrl=""
if [ "${db_engine}" = "postgres" ];
    then 
        dbDriver="org.postgresql.Driver"
        driverUrl="https://repo1.maven.org/maven2/org/postgresql/postgresql/42.3.6/postgresql-42.3.6.jar"
        dbType="postgre"
        dbEngine="postgres"
        dbAPIMUrl="jdbc:postgresql://$dbHost:$dbPort/WSO2AM_DB?useSSL=false&amp;autoReconnect=true&amp;requireSSL=false&amp;verifyServerCertificate=false"
        dbAPIMDSharedUrl="jdbc:postgresql://$dbHost:$dbPort/WSO2AM_SHARED_DB?useSSL=false&amp;autoReconnect=true&amp;requireSSL=false&amp;verifyServerCertificate=false"
elif [ "${db_engine}" = "mysql" ];
    then 
        dbDriver="com.mysql.cj.jdbc.Driver"
        driverUrl="https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.29/mysql-connector-java-8.0.29.jar"
        dbType="mysql"
        dbEngine="mysql"
        dbAPIMUrl="jdbc:mysql://$dbHost:$dbPort/WSO2AM_DB?useSSL=false&amp;autoReconnect=true&amp;requireSSL=false&amp;verifyServerCertificate=false"
        dbAPIMDSharedUrl="jdbc:mysql://$dbHost:$dbPort/WSO2AM_SHARED_DB?useSSL=false&amp;autoReconnect=true&amp;requireSSL=false&amp;verifyServerCertificate=false"
elif [ "${db_engine}" = "mssql" ];
    then 
        dbDriver="com.microsoft.sqlserver.jdbc.SQLServerDriver"
        driverUrl="https://repo1.maven.org/maven2/com/microsoft/sqlserver/mssql-jdbc/10.2.1.jre8/mssql-jdbc-10.2.1.jre8.jar"
        dbType="mssql"
        dbEngine="sqlserver-ex"
        dbAPIMUrl="jdbc:sqlserver://$dbHost:$dbPort/WSO2AM_DB?useSSL=false&amp;autoReconnect=true&amp;requireSSL=false&amp;verifyServerCertificate=false;SendStringParametersAsUnicode=false"
        dbAPIMDSharedUrl="jdbc:sqlserver://$dbHost:$dbPort/WSO2AM_SHARED_DB?useSSL=false&amp;autoReconnect=true&amp;requireSSL=false&amp;verifyServerCertificate=false;SendStringParametersAsUnicode=false"
elif [ "${db_engine}" = "oracle" ];
    then 
        dbDriver="oracle.jdbc.driver.OracleDriver"
        driverUrl="https://download.oracle.com/otn-pub/otn_software/jdbc/215/ojdbc11.jar"
        dbType="oracle"
        dbEngine="oracle-se2"
        dbUserNameAPIM="WSO2AM_DB"
        dbPasswordAPIM="wso2carbon"
        dbUserNameAPIMShared="WSO2AM_SHARED_DB"
        dbPasswordAPIMShared="wso2carbon"
        dbAPIMUrl="jdbc:oracle:thin://$dbHost:$dbPort:ORCL?useSSL=false&amp;autoReconnect=true&amp;requireSSL=false&amp;verifyServerCertificate=false;SendStringParametersAsUnicode=false"
        dbAPIMDSharedUrl="jdbc:oracle:thin://$dbHost:$dbPort:ORCL?useSSL=false&amp;autoReconnect=true&amp;requireSSL=false&amp;verifyServerCertificate=false;SendStringParametersAsUnicode=false"
else
    echo "The specified DB engine not supported.";
    exit 1;
fi;

echo "Details : $dbDriver $driverUrl $dbType";


# Download DB scripts from S3 bucket.
mkdir "${db_engine}"
aws s3 cp "s3://apim-test-grid/profile-automation/apim/${product_version}/${db_engine}/" "./${db_engine}/" --recursive || { echo 'Failed to download DB scripts.';  exit 1; }

# Update kube config file.
aws eks update-kubeconfig --region ${APIM_CLUSTER_REGION} --name ${APIM_EKS_CLUSTER_NAME} || { echo 'Failed to update cluster kube config.';  exit 1; }

# Check whether a cluster exists.
eksctl get cluster --region ${APIM_CLUSTER_REGION} -n ${APIM_EKS_CLUSTER_NAME} || { echo 'Cluster does not exists. Please create the cluster before deploying the applications.';  exit 1; }

# Delete Nginx admission if it exists.
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission || echo "WARNING : Failed to delete nginx admission."

# Scale node group with one EC2 instance.
eksctl scale nodegroup --region ${APIM_CLUSTER_REGION} --cluster ${APIM_EKS_CLUSTER_NAME} --name ng-1 --nodes=1 || { echo 'Failed to scale the node group.';  exit 1; }

# Create a random password.
dbPassword=$(echo $RANDOM | md5sum | head -c 8)
echo "DB password : $dbPassword"

# Create RDS DB using cloudformation.
dbUserName="root"
aws cloudformation create-stack --region ${APIM_CLUSTER_REGION} --stack-name ${APIM_RDS_STACK_NAME}   --template-body file://apim-rds-cf.yaml --parameters ParameterKey=pDbUser,ParameterValue="$dbUserName" ParameterKey=pDbPass,ParameterValue="$dbPassword"  ParameterKey=pDbEngine,ParameterValue="$dbEngine" ParameterKey=pDbVersion,ParameterValue="$db_version" ParameterKey=pDbInstanceClass,ParameterValue="$db_instance_class" || { echo 'Failed to create RDS stack.';  exit 1; }

# Wait for RDS DB to come alive.
aws cloudformation wait stack-create-complete --region ${APIM_CLUSTER_REGION} --stack-name ${APIM_RDS_STACK_NAME} || { echo 'RDS stack creation timeout.';  exit 1; }

# Extract DB port and DB host name detail.
dbPort=$(aws cloudformation describe-stacks --stack-name "${APIM_RDS_STACK_NAME}" --region "${APIM_CLUSTER_REGION}" --query 'Stacks[?StackName==`'$APIM_RDS_STACK_NAME'`][].Outputs[?OutputKey==`ApimDBJDBCPort`].OutputValue' --output text | xargs)
dbHost=$(aws cloudformation describe-stacks --stack-name "${APIM_RDS_STACK_NAME}" --region "${APIM_CLUSTER_REGION}" --query 'Stacks[?StackName==`'$APIM_RDS_STACK_NAME'`][].Outputs[?OutputKey==`ApimDBJDBCConnectionString`].OutputValue' --output text | xargs)
echo "db details DB port : $dbPort, DB host : $dbHost"

# Validate DB Port.
isEmpty "${dbPort}";
flag=$?
if [ $flag = 1 ];
    then 
        echo "Extracted db port value is empty."; exit 1
fi;

# Validate DB host name.
isEmpty "${dbHost}";
flag=$?
if [ $flag = 1 ];
    then 
        echo "Extracted DB host is empty."; exit 1
fi;

# Provision rds db
./provision_db_apim.sh "${db_engine}" "$dbPassword" "$dbHost" "$dbUserName" "$dbPort"

# Wait for nginx to come alive.
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=480s ||  { echo 'Nginx service is not ready within the expected time limit.';  exit 1; }

# Install APIM using helm.
helm repo add wso2 https://helm.wso2.com && helm repo update ||  { echo 'Error while adding WSO2 helm repository to helm.';  exit 1; }
helm dependency build "kubernetes-apim/${path_to_helm_folder}" ||  { echo 'Error while building helm folder : kubernetes-apim/${path_to_helm_folder}.';  exit 1; }
helm install apim "kubernetes-apim/${path_to_helm_folder}" \
    --set wso2.deployment.am.db.hostname="$dbHost" \
    --set wso2.deployment.am.db.port="$dbPort" \
    --set wso2.deployment.am.db.type="$dbType" \
    --set wso2.deployment.am.db.driver="$dbDriver" \
    --set wso2.deployment.am.db.driver_url="$driverUrl" \
    --set wso2.deployment.am.db.apim.username="$dbUserNameAPIM" \
    --set wso2.deployment.am.db.apim_shared.username="$dbUserNameAPIMShared" \
    --set wso2.deployment.am.db.apim.password="$dbPasswordAPIM" \
    --set wso2.deployment.am.db.apim_shared.password="$dbPasswordAPIMShared" \
    --set wso2.deployment.am.db.apim.url="$dbAPIMUrl" \
    --set wso2.deployment.am.db.apim_shared.url="$dbAPIMSharedUrl" \
    ||  { echo 'Error while instaling APIM to cluster.';  exit 1; }

cd "$workingdir"