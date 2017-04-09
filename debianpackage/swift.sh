# Set Swift Path
export PATH=/opt/colemancda/swift/usr:$PATH

# Install Swift
tar xvf swift.tar
rm -rf /opt/colemancda/swift/*
cp -rf ./usr /opt/colemancda/swift/
rm -rf ~/debianpackage/lockd/opt/colemancda/swift/*
cp -rf ./usr ~/debianpackage/lockd/opt/colemancda/swift/
