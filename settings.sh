export WAVE_HOSTNAME='<wave.your-company.com>'
export WAVE_CONTAINER_BUILD_REPO='<ECR registry for image built by wave>'
export WAVE_CONTAINER_CACHE_REPO='<ECR registry for image cached by wave>'
export WAVE_LOGS_BUCKET="wave-logs-prod"
export WAVE_REDIS_HOSTNAME="<YOUR ELASTICACHE INSTANCE>.cache.amazonaws.com:6379"
export WAVE_SENDER_EMAIL="wave-app@your-company.com"
export TOWER_API_URL="https://your-platform-hostname.com>/api"
export AWS_EFS_VOLUME_HANDLE="fs-000000"
export AWS_CERTIFICATE_ARN="arn:aws:acm:<YOUR REGION>:<YOUR ACCOUNT>:certificate/<YOUR CERTIFICATE ID>"
export AWS_IAM_ROLE=""
export SURREAL_DB_PASSWORD='secret123'
export SEQERA_CR_USER='<YOUR SEQERA REGISTRY USERNAME>'
export SEQERA_CR_PASSWORD=='<YOUR SEQERA REGISTRY PASSWORD>'
