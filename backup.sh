#!/bin/bash
#
# Argument = -u user -p password -k key -s secret -b bucket
#
# To Do - Add logging of output.
# To Do - Abstract bucket region to options

set -e

export PATH="$PATH:/usr/local/bin"

usage()
{
cat << EOF
usage: $0 options

This script dumps the current mongo database, tars it, then sends it to an Amazon S3 bucket.

OPTIONS:
   -u      Mongodb user (optional)
   -p      Mongodb password (optional)
   -s      AWS Secret Key (required)
   -b      Amazon S3 bucket name (required)
   -a      Amazon S3 folder (required)
   -f      Backup filename prefix (optional)
EOF
}

MONGODB_USER=
MONGODB_PASSWORD=
AWS_SECRET_KEY=
S3_BUCKET=
FOLDER_NAME=
FILE_NAME_PREFIX=


while getopts “ht:u:p:k:s:b:a:f:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    u)
      MONGODB_USER=$OPTARG
      ;;
    p)
      MONGODB_PASSWORD=$OPTARG
      ;;
    s)
      AWS_SECRET_KEY=$OPTARG
      ;;
    b)
      S3_BUCKET=$OPTARG
      ;;
    a)
      FOLDER_NAME=$OPTARG
      ;;
    f)
      FILE_NAME_PREFIX=$OPTARG
      ;;
    ?)
      usage
      exit
    ;;
  esac
done

if [[ -z $AWS_SECRET_KEY ]] || [[ -z $S3_BUCKET ]] || [[ -z $FOLDER_NAME ]]
then
  usage
  exit 1
fi

# Get the directory the script is being run from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR
# Store the current date in YYYY-mm-DD-HHMM
DATE=$(date -u "+%F-%H%M")
FILE_NAME="$FILE_NAME_PREFIX$DATE"
ARCHIVE_NAME="$FILE_NAME.tgz"


# Dump the database
if [[ -z $MONGODB_USER ]] || [[ -z $MONGODB_PASSWORD ]]
then
    mongodump --out $DIR/backup/$FILE_NAME
else
    mongodump -username "$MONGODB_USER" -password "$MONGODB_PASSWORD" --out $DIR/backup/$FILE_NAME
fi

# Tar Gzip the file
tar -C $DIR/backup/ -zcvf $DIR/backup/$ARCHIVE_NAME $FILE_NAME/

# Remove the backup directory
rm -r $DIR/backup/$FILE_NAME

# Send the file to the backup drive or S3


# /usr/bin/az login --identity
/usr/bin/az storage blob upload \
  -f $DIR/backup/$ARCHIVE_NAME \
  --auth-mode key \
  --account-name $S3_BUCKET \
  --account-key "$AWS_SECRET_KEY" \
  -n $ARCHIVE_NAME \
  -c $FOLDER_NAME

rm $DIR/backup/$ARCHIVE_NAME
