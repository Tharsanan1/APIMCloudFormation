workingdir=$(pwd)
reldir=`dirname $0`
cd $reldir

echo "Uninstalling APIM in cluster."
helm uninstall "${product_name}" || true

eksctl delete fargateprofile  --name "${product_name}-fargate-profile" --cluster "${EKS_CLUSTER_NAME}" --region ${EKS_CLUSTER_REGION}

cd "$workingdir"