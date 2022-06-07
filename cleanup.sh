workingdir=$(pwd)
reldir=`dirname $0`
cd $reldir

echo "Scaling node group instances to zero."
eksctl scale nodegroup --region ${EKS_CLUSTER_REGION} --cluster ${EKS_CLUSTER_NAME} --name ng-1 --nodes=0 || true
echo "Uninstalling APIM in cluster."
helm uninstall "${product_name}" || true

cd "$workingdir"