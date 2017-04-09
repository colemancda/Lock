# Set Swift Path
export PATH=/opt/colemancda/swift/usr:$PATH

# Build
echo "Building lockd"
cd ~/developer/Lock
rm -rf .build
swift build --configuration debug

# Package
echo "Creating Debian package"
cp -rf .build/debug/lockd ~/debianpackage/lockd/usr/bin/
cd ~/debianpackage
./package.sh
