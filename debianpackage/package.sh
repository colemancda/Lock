echo "Building Debian package"
dpkg-deb -b lockd lockd.deb

echo "Creating static repo"
reprepro -b ./repo includedeb jessie ./lockd.deb

echo "Uploading to S3"
s3cmd --verbose --acl-public --delete-removed  sync ~/debianpackage/repo/ s3://cerraduraupdates/
