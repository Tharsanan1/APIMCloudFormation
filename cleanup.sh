workingdir=$(pwd)
reldir=`dirname $0`
cd $reldir

echo "Scaling node group instances to zero."
eksctl scale nodegroup --region ${EKS_CLUSTER_REGION} --cluster ${EKS_CLUSTER_NAME} --name ng-1 --nodes=0 || true
echo "Uninstalling APIM in cluster."
helm uninstall "${product_name}" || true
echo "Deleting RDS database."
aws cloudformation delete-stack --region ${EKS_CLUSTER_REGION} --stack-name ${RDS_STACK_NAME} ; aws cloudformation wait stack-delete-complete --region ${EKS_CLUSTER_REGION} --stack-name apim-rds-stack || true



cd "$workingdir"