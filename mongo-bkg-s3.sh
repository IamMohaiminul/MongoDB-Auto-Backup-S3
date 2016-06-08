# !/bin/bash
# http://IamMohaiminul.GitHub.io/MongoDB-Auto-Backup-S3/
# This script dumps the your mongo database and compress it and then sends it to your Amazon S3 bucket.

set -e

export PATH="$PATH:/usr/local/bin"

MSG="Required Variable Initialization Missing!"

# Initialize these variables
MONGODB_USER=
MONGODB_PASSWORD=
AWS_ACCESS_KEY=
AWS_SECRET_KEY=
S3_REGION=
S3_BUCKET=

if [[ -z $MONGODB_USER ]] || [[ -z $MONGODB_PASSWORD ]] || [[ -z $AWS_ACCESS_KEY ]] || [[ -z $AWS_SECRET_KEY ]] || [[ -z $S3_REGION ]] || [[ -z $S3_BUCKET ]]
then
  echo $MSG
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

# Remove the backup from directory
rm -r $DIR/mongo-s3-bkg/$FILE_NAME

# Send the Tar Gzip file to the backup drive S3
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
