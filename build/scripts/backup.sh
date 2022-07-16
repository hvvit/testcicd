#!/bin/bash

export BUCKET="assignmentkubevelerobackup"
export REGION=$(cat ~/.aws/config  | awk -F "=" '$1=="region"{print$2}' | tr -d " ")
#function to check aws cli config file
function checkConfig {
  if [ -f ~/.aws/config ];
  then
    echo "awscli config is already present"
  else 
    echo "Please setup the aws cli config for the script to work properly"
    echo "Please refer the following document for information: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html"
    exit 1
  fi
}

#function to check creadentials
function checkCredentials {
  if [ -f ~/.aws/credentials ];
  then
    echo "awscli credentials is already present"
  else 
    echo "Please setup the aws cli credentials for the script to work properly"
    echo "Please refer the following document for information: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-files.html"
    exit 1
  fi
}

#function to install cli
function installCli {
  if [ -f /usr/local/aws-cli/v2/current/bin/aws ];
  then
    echo "awscli already installed"
  else 
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
    aws --version
    sudo ln -svf /usr/local/bin/aws /usr/bin/aws 
    rm -rf ./aws awscliv2.zip
  fi
}

function createBucket {
  BUCKET_EXISTS=$(aws s3api head-bucket --bucket $BUCKET 2>&1 || true)
  if [ -z "$BUCKET_EXISTS" ]; then
    echo "Bucket already exists"
  else
    echo "Bucket does not exist"
    echo "creating bucket ${BUCKET} in region us-east-1"
    if [[ ${region} == "us-east-1" ]];
    then
      aws s3api create-bucket --bucket $BUCKET --region us-east-1
    else
      aws s3api create-bucket --bucket $BUCKET --region $REGION --create-bucket-configuration LocationConstraint=$REGION
    fi
  fi
  aws s3api wait bucket-exists --bucket $BUCKET
}

function iamUser {
  USER_EXISTS=$(aws iam list-users | grep -wc velero)
  if [ "$USER_EXISTS" -ge 1 ]; then
    echo "user velero already exists"
  else
    echo "creating user velero"
    aws iam create-user --user-name velero
  fi
  aws iam wait user-exists --user-name velero
}

function iamUserPolicy {
  cat > /tmp/velero-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:DescribeSnapshots",
                "ec2:CreateTags",
                "ec2:CreateVolume",
                "ec2:CreateSnapshot",
                "ec2:DeleteSnapshot"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObject",
                "s3:AbortMultipartUpload",
                "s3:ListMultipartUploadParts"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET}/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${BUCKET}"
            ]
        }
    ]
}
EOF
  POLICY_EXISTS=$(aws iam get-user-policy --user-name velero --policy-name velero 2>&1 || true)
  if [ -z "$POLICY_EXISTS" ]; then
    echo "policy velero already exists for user velero"
  else
    echo "creating policy velero for user velero"
    aws iam put-user-policy \
    --user-name velero \
    --policy-name velero \
    --policy-document file:///tmp/velero-policy.json
  fi
}

function getKey {
  if [ -f /tmp/velero.key ];
  then
    echo "velero keys already installed.."
  else
    echo "fetching keys for velero user"
    aws iam create-access-key --user-name velero > /tmp/velero.key  
  fi
}

function createCredFile {
  if [ -f /tmp/velero.key ];
  then
    echo "creating cred file"
    aws_access_key_id=$(cat /tmp/velero.key | jq '.AccessKey.AccessKeyId' | tr -d '"')
    aws_secret_access_key=$(cat /tmp/velero.key | jq '.AccessKey.SecretAccessKey' | tr -d '"')
    cat > /tmp/velero-aws-credentials <<EOF
[default]
aws_access_key_id=${aws_access_key_id}
aws_secret_access_key=${aws_secret_access_key}
EOF
  else
    echo "velero key file does not exists"
    exit 1
  fi
}

function installVelero {
  if [ -f /usr/local/bin/velero ];
  then
    echo "velero binary already installed.."
  else
    echo "installing velero"
    wget https://github.com/vmware-tanzu/velero/releases/download/v1.9.0/velero-v1.9.0-linux-amd64.tar.gz
    tar xf velero-v1.9.0-linux-amd64.tar.gz
    sudo mv velero-v1.9.0-linux-amd64/velero /usr/local/bin/
    sudo chmod a+x /usr/local/bin/velero
    rm -rf velero-v1.9.0-linux-amd64 velero-v1.9.0-linux-amd64.tar.gz
    echo "Install successfull"
  fi
}

function configAwsVelero {
  velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.4.0 \
    --bucket $BUCKET \
    --backup-location-config region=$REGION \
    --snapshot-location-config region=$REGION \
    --secret-file  /tmp/velero-aws-credentials \
    --use-restic \
    --wait
}
checkConfig
checkCredentials
installCli
createBucket
iamUser
iamUserPolicy
getKey
createCredFile
installVelero
configAwsVelero