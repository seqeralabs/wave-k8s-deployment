# Wave container registry 

## Summary 

Build and augment container images for Nextflow workflows.

## Requirements

* AWS EKS cluster
* AWS OpenID Connect (OIDC) provider for EKS
* AWS S3 bucket for logs
* AWS EFS for shared files
* AWS EFS CSI driver for EKS
* AWS Application Load Balancer
* AWS Certificate Manager
* AWS SES (simple email service)
* AWS ECR service
* AWS Elasticache
* AWS Route53

## AWS Environment preparation

* Create a EKS cluster instance following the [AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html). When the cluster is ready create a new Kubernetes namespace where the Wave service is going to be deployed e.g. `wave-production`.
* Create an AWS S3 bucket in the same region where the EKS cluster is running. The bucket will host Wave logs, e.g. `wave-logs-prod`.
* Create an EFS file system instance as described in the [AWS documentation](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html). Make sure to use the same VPC used for the EKS cluster and [EFS CSI driver](https://docs.aws.amazon.com/eks/latest/userguide/efs-csi.html) for EKS.
  Also make sure Your EFS file system's security group must have an inbound and outbound rule that allows NFS traffic from the CIDR for your cluster's VPC.Allow port 2049 for inbound and outbound traffic.
* Create AWS Certificate to allow HTTPS traffic to your Wave service by using the AWS Certificate Manager. The certificate should be in the same region where the EKS cluster is running. See the [AWS documentation](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html) for further details.
* Create two container repositories in the same region where the container is deployed. The first repository is used to host the container images built by Wave and the second one will be used for caching purposes. Make sure to create two repository have the same name prefix e.g. `wave/build` and `wave/cache`.
* Create an AWS Elasticache instance used by Wave for caching purposes. It's required the use of a single-node cluster. For production deployment it's adviced the used of instance type `cache.t3.medium` and using Redis 6.2.x engine version or later (serverless is not supported). Make sure to use the same VPC used for the EKS cluster.
* The AWS SES service is required by Wave to send email notification. Make sure to have configured a AWS SES service for production usage. See the [AWS documentation](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html) for further details.

## AWS policy & role creation

Create an AWS IAM policy that will grant access to the AWS infrastructure to the Wave application. This requires
your cluster to have an existing AWS Identity and Access Management (IAM) OpenID Connect (OIDC) provider for your
EKS cluster. To determine whether you already have one, or to create one, see
[Creating an IAM OIDC provider for your cluster](https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html).

1. Make sure the file `settings.sh` have a valid value for the following settings:

    * `AWS_REGION`: The AWS region where your cluster is deployed e.g. `eu-central-1`.
    * `AWS_ACCOUNT`: The ID of the AWS account where the cluster is deployed.
    * `WAVE_CONFIG_NAME`: The name for this Wave deployment e.g. `seqera-wave`.
    * `WAVE_LOGS_BUCKET`: The S3 bucket for storing Wave logs, created in the previous step.
    * `WAVE_CONTAINER_NAME_PREFIX`: The name prefix given the build cache ECR repository e.g. `wave`
    * `AWS_EKS_CLUSTER_NAME`: The name of the cluster name where the service is going to be deployed.
    * `WAVE_NAMESPACE`: The Kubernetes namespace where the Wave service is going to be deployed e.g. `wave-test`.
    * `WAVE_BUILD_NAMESPACE`: The Kubernetes namespace where container build jobs will be executed e.g. `wave-build`.


1. Create the IAM policy using the template included in this repo with name `seqera-wave-policy.json` and using
the command below:

   ```bash
   source settings.sh
   aws \
     --region $AWS_REGION \
     iam create-policy \
     --policy-name $WAVE_CONFIG_NAME \
     --policy-document file://<( cat policies/seqera-wave-policy.json | envsubst )
   ```

Take note of the policy Arn show in the command result.

Find your cluster's OIDC provider URL using the command below:

   ```bash
   aws \
     --region $AWS_REGION \
     eks describe-cluster \
     --name $AWS_EKS_CLUSTER_NAME \
     --query "cluster.identity.oidc.issuer" \
     --output text
   ```

An example output is as follows.

  ```
  https://oidc.eks.region-code.amazonaws.com/id/EXAMPLED539D4633E53DE1B71EXAMPLE
  ```

Set the variable `AWS_EKS_OIDC_ID` in the `settings.sh` using the id value from your result. Then run
the command below:

  ```
  source settings.sh
  aws \
    --region $AWS_REGION \
    iam create-role \
    --role-name $WAVE_CONFIG_NAME \
    --assume-role-policy-document file://<( cat policies/seqera-wave-role.json | envsubst )
  ```


Take note of the Arn of the IAM role created and use it as value for the variable `AWS_IAM_ROLE`
in the `settings.sh` file.

Finally attach to the role the policy created in the previous step, using the command below:

  ```bash
  source settings.sh
  aws \
    --region $AWS_REGION \
    iam attach-role-policy \
    --role-name $WAVE_CONFIG_NAME \
    --policy-arn arn:aws:iam::$AWS_ACCOUNT:policy/$WAVE_CONFIG_NAME
  ```


## Deployment

### Kubernetes manifests preparation

Update the variables in the file `settings.sh` with the values corresponding your AWS infrastructure
created in the previous step. The following settings are required:

* `WAVE_HOSTNAME`: The host name to use to access the Wave service e.g. `wave.your-company.com`. This should match the host name used when creating the HTTPS certificate by using AWS Certificate manager.
* `WAVE_CONTAINER_BUILD_REPO`: The ECR repository name used to host the containers built by Wave e.g. `<YOUR ACCOUNT>.dkr.ecr.<YOUR REGION>.amazonaws.com/wave/build`.
* `WAVE_CONTAINER_CACHE_REPO`: The ECR repository name used to cache the containers built by Wave e.g. `<YOUR ACCOUNT>.dkr.ecr.<YOUR REGION>.amazonaws.com/wave/cache`.
* `WAVE_LOGS_BUCKET`: The AWS S3 bucket used to store the Wave logs e.g. `wave-logs-prod`.
* `WAVE_REDIS_HOSTNAME`: The AWS Elasticache instance hostname and port e.g. `<YOUR ELASTICACHE INSTANCE>.cache.amazonaws.com:6379`.
* `WAVE_SENDER_EMAIL`: The email address that will be used by Wave to send email e.g. `wave-app@your-company.com`. Note: it must an email address validated in your AWS SES setup.
* `TOWER_API_URL`: The API URL of your Seqera Platform installation e.g. `<https://your-platform-hostname.com>/api`.
* `AWS_EFS_VOLUME_HANDLE`: The AWS EFS shared file system instance ID e.g. `fs-12345667890`
* `AWS_CERTIFICATE_ARN`: The arn of the AWS Certificate created during the environment preparation e.g. `arn:aws:acm:<YOUR REGION>:<YOUR ACCOUNT>:certificate/<YOUR CERTIFICATE ID>`
* `AWS_IAM_ROLE`: The arn of the AWS IAM role granting permissions to AWS resources to the Wave service.
* `SURREAL_DB_PASSWORD`: User defined password to be used for embedded Surreal DB deployed by Wave.
* `SEQERA_CR_USER`: The username to access the Seqera container registry to providing the images for installing Wave service
* `SEQERA_CR_PASSWORD`: The password to access the Seqera container registry to providing the images for installing Wave service

### Application deployment

Once the application manifest files have been updated replacing the above variables with the
corresponding values, proceed with the application deployment following those steps:

0. Export the content of the `settings.sh` file in your environment using this command:

   ```bash
   source settings.sh
   ```

1. Create storage, app namespace and roles:

   ```bash
   kubectl apply -f <(cat src/create.yml | envsubst)
   kubectl config set-context --current --namespace=${WAVE_NAMESPACE}
   ```

2. Setup the Container registry credentials to access the Wave container image:

   ```bash
   kubectl create secret \
      docker-registry seqera-reg-creds \
      --namespace "${WAVE_NAMESPACE}" \
      --docker-server=cr.seqera.io \
      --docker-username="${SEQERA_CR_USER}" \
      --docker-password="${SEQERA_CR_PASSWORD}"
   ```

3. Create build storage and namespace

   ```bash
   kubectl apply -f <(cat src/build.yml | envsubst)
   ```

4. Deploy Surreal DB

   ```bash
   kubectl apply -f <(cat src/surrealdb.yml | envsubst)
   ```

5. Deploy the main application resources:

   ```bash
   kubectl apply -f <(cat src/app.yml | envsubst)
   ```

6. Deploy the Ingress controller:

   ```bash
   kubectl apply -f <(cat src/ingress.yml | envsubst)
   ```

The ingress controller will create automatically an AWS application load balancer to serve the Wave
service traffic. The Load balancer address can be retrieved using the following command:


  ```bash
  kubectl get ingress wave-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
  ```


Having the load balancer hostname, configure a *alias* record in your Route53 DNS so that the Wave service
hostname is mapped to the load balancer hostname created by the ingress.

See also [AWS documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-elb-load-balancer.html) for details.

Once the DNS is configured verify the Wave API is accessible using this command:

  ```bash
  curl https://${WAVE_HOSTNAME}/service-info | jq
  ```

7. Pair Seqera Platform with Wave

Once Wave service ready, you will need to configure the Seqera Platform (aka Tower) to pair
with the Wave service in your infrastructure.

Follow the documentation available at [this link](https://docs.seqera.io/platform/23.4.0/enterprise/configuration/wave)
replacing replacing the Wave endpoint `https://wave.seqera.io` with the one defined in your installation.


8. Verify the service is operating correctly

Check the Wave pod logs. There should not be any error and it should be reported the line

  ```
  Opening pairing session - endpoint: <YOUR SEQERA PLATFORM URL>
  ```

Sign in the Seqera Platform and create a Personal access token, and export the token value as shown below:

  ```bash
  export TOWER_ACCESS_TOKEN=<TOKEN VALUE>
  ```

Then download the [Wave CLI](https://github.com/seqeralabs/wave-cli) tool, and use it request a Wave container
using the command below:

  ```bash
  wave \
      --wave-endpoint https://$WAVE_HOSTNAME \
      --tower-endpoint $TOWER_API_URL \
      --image alpine:latest
  ```

It will show the Wave container name for the request alpine image. You should be able to pull the container using
a simple `docker pull <wave container>` command.


To verify Wave build is working as expected run this command:


  ```bash
  wave \
      --wave-endpoint https://$WAVE_HOSTNAME \
      --tower-endpoint $TOWER_API_URL \
      --conda-package cowpy
  ```

You should receive an email notification when the Wave build process completes and container
is ready to be pulled.


### Notes

* Suggested instance type for Wave backend `m5a.2xlarge`
* This deployment does not support the build of ARM (Graviton) CPU architecture containers.
