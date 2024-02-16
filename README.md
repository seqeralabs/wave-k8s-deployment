# Wave container registry 

## Summary 

Build and augment container images for Nextflow workflows.

## Requirements

* AWS EKS cluster
* AWS S3 bucket for logs
* AWS EFS for shared files
* AWS Application Load Balancer
* AWS Certificate Manager
* AWS SES (simple email service)
* AWS ECR service
* AWS Elasticache
* AWS Route53

## AWS Environment preparation

* Create a EKS cluster instance following the [AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html). When the cluster is ready create a new Kubernetes namespace where the Wave service is going to be deployed e.g. `wave-production`.
* Create an AWS S3 bucket in the same region where the EKS cluster is running. The bucket will host Wave logs, e.g. `wave-logs-prod`.
* Create an EFS file system instance as described in the [AWS documentation](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html).
* The AWS SES service is required by Wave to send email notification. Make sure to have configured a AWS SES service for production usage. See the [AWS documentation](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html) for further details.
* Create AWS Certificate to allow HTTPS traffic to your Wave service by using the AWS Certificate Manager. The certificate should be in the same region where the EKS cluster is running. See the [AWS documentation](https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html) for further details.
* Create two container repositories in the same region where the container is deployed. The first repository is used to host the container images built by Wave and the second one will be used for caching purposes.
* Create an AWS Elasticache instance used by Wave for caching purposes. For production deployment it's adviced the used of instance type `cache.t3.medium` and using Redis 6.2.x engine version.

## AWS role creation

Create an AWS IAM role that will grant access to the AWS infrastructure to the Wave application.
The role is defined by this policy:


```
{
    "Statement": [
        {
            "Action": [
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:DescribeImages",
                "ecr:BatchGetImage",
                "ecr:GetLifecyclePolicy",
                "ecr:GetLifecyclePolicyPreview",
                "ecr:ListTagsForResource",
                "ecr:DescribeImageScanFindings",
                "ecr:CompleteLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:InitiateLayerUpload",
                "ecr:PutImage"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:ecr:<YOUR REGION>:<YOUR ACCOUNT>:repository/wave/*"
            ]
        },
        {
            "Action": "ecr:GetAuthorizationToken",
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "ssm:DescribeParameters"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": "s3:ListBucket",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::<YOUR WAVE BUCKERT>"
            ]
        },
        {
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::<YOUR WAVE BUCKET>/*"
            ]
        },
        {
            "Action": [
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:ssm:<YOUR REGION>:<YOUR ACCOUNT>:parameter/config/wave-*",
                "arn:aws:ssm:<YOUR REGION>:<YOUR ACCOUNT>:parameter/config/application*"
            ]
        }
    ],
    "Version": "2012-10-17"
}
```

In the above policy replace the placeholders `<YOUR REGION>`,`<YOUR ACCOUNT>` and `<YOUR WAVE BUCKET>`
with the corresponding resources created in the previous step

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


1. Create storage, app namespace and roles:

    ```
    kubectl apply -f <(cat src/create.yml | envsubst)
    kubectl config set-context --current --namespace=wave-deploy
    ```

2. Setup the Container registry credentials to access the Wave container image:

    ```
    kubectl create secret \
      docker-registry reg-creds \
      --namespace wave-deploy \
      --docker-server=cr.seqera.io \
      --docker-username='<SEQERA_CR_USER>' \
      --docker-password='<SEQERA_CR_PASSWORD>'
    ```

Replace the placeholders `<SEQERA_CR_USER>` and `<SEQERA_CR_PASSWORD>` with your Seqera registry credentials.
Make sure to include the username and password in between single quote `'`.

3. Create build storage and namespace

    ```
    kubectl apply -f <(cat src/build.yml | envsubst)
    ```

4. Deploy Surreal DB

    ```
    kubectl apply -f <(cat src/surrealdb.yml | envsubst)
    ```

4. Deploy the main application resources:

    ```
    kubectl apply -f <(cat src/app.yml | envsubst)
    ```

5. Deploy the Ingress controller:

    ```
    kubectl -f <(cat src/ingress.yml | envsubst)
    ```

The ingress controller will create automatically an AWS application load balancer to serve the Wave
service traffic. The Load balancer address can be retrieved using the following command:


    ```
    kubectl get ingress wave-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    ```

5. Configure the DNS 

Having the load balancer hostname, configure a *alias* record in your Route53 DNS so that the Wave service
hostname is mapped to the load balancer hostname created by the ingress.

See also [AWS documentation](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/routing-to-elb-load-balancer.html) for details.

