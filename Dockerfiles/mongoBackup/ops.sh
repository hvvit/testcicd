#!/bin/bash

mkdir -pv /mongodump/db/
stamp=$(date '+%Y%m%d%H%M%S')
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

#function to push to s3
function pushToS3 {
  filename=${1}
  aws s3 cp /mongodump/db/${filename} s3://${BUCKET}/mongodump/${filename}
}

#function to pull from s3
function pullFromS3 {
  BUCKET_EXISTS=$(aws s3api head-bucket --bucket $BUCKET 2>&1 || true)
  if [ -z "$BUCKET_EXISTS" ]; then
    echo "Bucket already exists"
    filename=${1}
    aws s3 cp s3://${BUCKET}/mongodump/${filename} /mongodump/db/${filename} 
  else
    echo "Backup Bucket ${BUCKET} does not exists"
    exit 1
  fi
}

#function to take backup
function takeBackup {
  echo ******************************************************
  echo Starting-BACKUP
  echo ******************************************************
  file_name="mongo_${stamp}.gz"
  mongodump --uri=$MONGODB_URI --gzip --archive=/mongodump/db/$file_name
  pushToS3 ${file_name}
  echo ******************************************************
  echo BACKUP-COMPLETED
  echo ******************************************************
}

#function to restore backup
function restoreBackup {
  echo ******************************************************
  echo Restoring-BACKUP
  echo ******************************************************
  pullFromS3 ${DUMPNAME} 
  mongorestore --uri=$MONGODB_URI --gzip --archive=/mongodump/db/$DUMPNAME
  echo ******************************************************
  echo RESTORE-COMPLETED
  echo ******************************************************
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