# !/bin/bash
# https://github.com/IamMohaiminul/mongodb-auto-backup-s3
# This script dumps the your mongo database, tars it, then sends it to an Amazon S3 bucket.

set -e

export PATH="$PATH:/usr/local/bin"

variableMissingMsg()
{
cat << EOF
usage: $0 options
Some variable initialization is missing. You must initialize these variables in script:
  -MONGODB_USER       This is your Mongodb root user
  -MONGODB_PASSWORD   This is your Mongodb root user\'s password
  -AWS_ACCESS_KEY     This is the AWS Access Key where you want to store your backup
  -AWS_SECRET_KEY     This is the AWS Secret Key where you want to store your backup
  -S3_REGION          This is the Amazon S3 region where you want to store your backup
  -S3_BUCKET          This is the Amazon S3 bucket name where you want to store your backup
EOF
}

# Initialize these variables
MONGODB_USER=
MONGODB_PASSWORD=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_REGION=
S3_BUCKET=

if [[ -z $MONGODB_USER ]] || [[ -z $MONGODB_PASSWORD ]] || [[ -z $AWS_ACCESS_KEY ]] || [[ -z $AWS_SECRET_KEY ]] || [[ -z $S3_REGION ]] || [[ -z $S3_BUCKET ]]
then
  variableMissingMsg
  exit 1
fi

# Get the directory the script is being run from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR

# Store the current date in YYYY-mm-DD-HHMMSS
DATE=$(date -u "+%F-%H%M%S")
FILE_NAME="backup-$DATE"
ARCHIVE_NAME="$FILE_NAME.tar.gz"

# Lock the database
# Note there is a bug in mongo 2.2.0 where you must touch all the databases before you run mongodump
mongo --username "$MONGODB_USER" --password "$MONGODB_PASSWORD" admin --eval "var databaseNames = db.getMongo().getDBNames(); for (var i in databaseNames) { printjson(db.getSiblingDB(databaseNames[i]).getCollectionNames()) }; printjson(db.fsyncLock());"

# Dump the database
mongodump --username "$MONGODB_USER" --password "$MONGODB_PASSWORD" --out $DIR/mongo-s3-bkg/$FILE_NAME

# Unlock the database
mongo --username "$MONGODB_USER" --password "$MONGODB_PASSWORD" admin --eval "printjson(db.fsyncUnlock());"

# Tar Gzip the file
tar -C $DIR/mongo-s3-bkg/ -zcvf $DIR/mongo-s3-bkg/$ARCHIVE_NAME $FILE_NAME/

# Send the file to the backup drive or S3
HEADER_DATE=$(date -u "+%a, %d %b %Y %T %z")
CONTENT_MD5=$(openssl dgst -md5 -binary $DIR/mongo-s3-bkg/$ARCHIVE_NAME | openssl enc -base64)
CONTENT_TYPE="application/x-download"
STRING_TO_SIGN="PUT\n$CONTENT_MD5\n$CONTENT_TYPE\n$HEADER_DATE\n/$S3_BUCKET/$ARCHIVE_NAME"
SIGNATURE=$(echo -e -n $STRING_TO_SIGN | openssl dgst -sha1 -binary -hmac $AWS_SECRET_KEY | openssl enc -base64)

curl -X PUT \
--header "Host: $S3_BUCKET.s3-$S3_REGION.amazonaws.com" \
--header "Date: $HEADER_DATE" \
--header "content-type: $CONTENT_TYPE" \
--header "Content-MD5: $CONTENT_MD5" \
--header "Authorization: AWS $AWS_ACCESS_KEY:$SIGNATURE" \
--upload-file $DIR/mongo-s3-bkg/$ARCHIVE_NAME \
https://$S3_BUCKET.s3-$S3_REGION.amazonaws.com/$ARCHIVE_NAME

# Remove the backup directory
rm -r $DIR/mongo-s3-bkg/$FILE_NAME
