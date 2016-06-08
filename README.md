# MongoDB-Auto-Backup-S3
Shell Script for Auto MongoDB Backup to Amazon S3 Periodically


### How to use
You must initialize these variables in script (`mongo-bkg-s3.sh`):

`MONGODB_USER`       This is your Mongodb root user

`MONGODB_PASSWORD`   This is your Mongodb root user\'s password

`AWS_ACCESS_KEY`     This is the AWS Access Key where you want to store your backup

`AWS_SECRET_KEY`     This is the AWS Secret Key where you want to store your backup

`S3_REGION`          This is the Amazon S3 region where you want to store your backup

`S3_BUCKET`          This is the Amazon S3 bucket name where you want to store your backup

And run this command in terminal `bash /path/to/mongo-bkg-s3.sh`.


### How to run periodically

run this command in terminal `sudo crontab -e` and choose option 2 to nano edittor.

Then add this line `0 1 * * * bash /path/to/mongo-bkg-s3.sh` in cronjobs to Execute on everyday at 01:00.

If you want to store the output in a log file, then this line `0 1 * * * bash /path/to/mongo-bkg-s3.sh > /var/log/db-bkg.log 2>&1`.

To view the list of cronjobs you can run: `sudo crontab -l`.
