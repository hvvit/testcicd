#!/bin/bash

aws_access_key_id=$(cat ${AWS_SHARED_CREDENTIALS_FILE} | awk -F "=" '$1=="aws_access_key_id"{print $2}')
aws_secret_access_key=$(cat ${AWS_SHARED_CREDENTIALS_FILE} | awk -F "=" '$1=="aws_secret_access_key"{print $2}')

mc alias set s3 https://s3.amazonaws.com ${aws_access_key_id} ${aws_secret_access_key} --api S3v4
mc alias set minio http://${MINIO_URL}:9000 ${MINIO_ACCESS_KEY_ID} ${MINIO_SECRET_ACCESS_KEY} --api S3v4

#function to create bucket
function createBucket {
  BUCKET_EXISTS=$(aws s3api head-bucket --bucket $BUCKET 2>&1 || true)
  if [ -z "$BUCKET_EXISTS" ]; then
    echo "Bucket already exists"
  else
    echo "Bucket does not exist"
    echo "creating bucket ${BUCKET} in region ${REGION}"
    if [[ ${region} == "us-east-1" ]];
    then
      aws s3api create-bucket --bucket $BUCKET --region us-east-1
    else
      aws s3api create-bucket --bucket $BUCKET --region $REGION --create-bucket-configuration LocationConstraint=$REGION
    fi
  fi
  aws s3api wait bucket-exists --bucket $BUCKET
}

#function to take minio backup
function takeBackup {
  echo "******************************************************"
  echo Starting-BACKUP
  echo "******************************************************"
  echo "mc cp --recursive --preserve minio/thumbnails/ s3/$BUCKET/"
  mc cp --recursive --preserve minio/thumbnails/ s3/$BUCKET/
  echo "******************************************************"
  echo BACKUP-completed
  echo "******************************************************"
}

#function to restore backup
function restoreBackup {
  echo "******************************************************"
  echo Starting-RESTORE
  echo "******************************************************"
  mc cp --recursive --preserve s3/$BUCKET/  minio/thumbnails/
  echo "******************************************************"
  echo RESTORE-completed
  echo "******************************************************"
}
if [[ "$OPS" == "BACKUP" ]]; then
  createBucket
  takeBackup
elif [[ "$OPS" == "RESTORE" ]]; then
  restoreBackup
else
  echo "No working ops provided"
  exit 1
fi