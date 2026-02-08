#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi

if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    BUILD_DIR="${OUTDIR}/linux-build"

    if [ ! -f "${BUILD_DIR}/arch/${ARCH}/boot/Image" ]; then
        echo "Building Linux kernel ${KERNEL_VERSION} for ${ARCH}"

        make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} mrproper 

        make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} O=${BUILD_DIR} defconfig

        make -j4 ARCH=${ARCH} \
            CROSS_COMPILE=${CROSS_COMPILE} \
            O=${BUILD_DIR} \
            Image modules dtbs
    else
        echo "Kernel Image already exists, skipping build"
    fi 
fi

echo "Adding the Image in outdir"

echo "Searching for kernel image under ${BUILD_DIR}"

# Possible kernel image names (ordered by preference)
KERNEL_IMAGE=$(find "${BUILD_DIR}/arch" -type f \
    \( -name "Image" -o -name "zImage" -o -name "bzImage" \) \
    | head -n 1)

if [ -z "$KERNEL_IMAGE" ]; then
    echo "ERROR: No kernel image found!"
    exit 1
fi

echo "Found kernel image: ${KERNEL_IMAGE}"

# Copy to OUTDIR
cp "${KERNEL_IMAGE}" "${OUTDIR}/"

echo "Kernel image copied to ${OUTDIR}/$(basename "${KERNEL_IMAGE}")"

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories

echo "Creating base root filesystem directories"

ROOTFS_DIR="${OUTDIR}/rootfs"

mkdir -p "${ROOTFS_DIR}"
mkdir -p -m 755 "${ROOTFS_DIR}"/{bin,sbin,etc,lib,lib64,dev,proc,sys,tmp}
mkdir -p -m 755 "${ROOTFS_DIR}"/usr/{bin,sbin}
mkdir -p -m 755 "${ROOTFS_DIR}"/var/{log,run}

# Set proper permissions
chmod 755 "${ROOTFS_DIR}"
chmod 1777 "${ROOTFS_DIR}/tmp"

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
else
    cd busybox
fi

# Clean any previous configuration
make distclean

# Generate default BusyBox configuration
make defconfig

make -j$(nproc) \
    ARCH=${ARCH} \
    CROSS_COMPILE=${CROSS_COMPILE}

# TODO: Make and install busybox

make ARCH=${ARCH} \
    CROSS_COMPILE=${CROSS_COMPILE} \
    CONFIG_PREFIX="${OUTDIR}/rootfs" \
    install

echo "Library dependencies"
${CROSS_COMPILE}readelf -a busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
echo "Adding library dependencies to root filesystem"
export CROSS_COMPILE=aarch64-none-linux-gnu-
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
echo "SYSROOT = $SYSROOT"
ROOTFS="${OUTDIR}/rootfs"

# Create library directories
mkdir -p -m 755 "${ROOTFS}/lib"
mkdir -p  -m 755 "${ROOTFS}/lib64"

# Copy dynamic loader (required)
cp -a "${SYSROOT}/lib/ld-linux-aarch64.so.1" "${ROOTFS}/lib/"

# Copy required libraries
cp -a "${SYSROOT}/lib64/libc.so.6" "${ROOTFS}/lib/"
cp -a "${SYSROOT}/lib64/libm.so.6" "${ROOTFS}/lib/"

# Optional but commonly required
if [ -f "${SYSROOT}/lib64/libresolv.so.2" ]; then
    cp -a "${SYSROOT}/lib64/libresolv.so.2" "${ROOTFS}/lib/"
fi

# Some toolchains place libs in lib64
if [ -d "${SYSROOT}/lib64" ]; then
    cp -a "${SYSROOT}/lib64/"* "${ROOTFS}/lib64/"
fi

chmod 755 $ROOTFS/bin/busybox

sudo chown -R root:root $ROOTFS

#sudo chown -R root:root "${ROOTFS}/lib" "${ROOTFS}/lib64"
#chmod 755 "${ROOTFS}/lib" "${ROOTFS}/lib64"

# TODO: Make device nodes
echo "Creating device nodes in root filesystem"

ROOTFS="${OUTDIR}/rootfs"

# Ensure dev directory exists
sudo mkdir -p "${ROOTFS}/dev"

# Create device nodes
# /dev/console – used by the kernel to attach /bin/sh
if [ ! -e "${ROOTFS}/dev/console" ]; then
    sudo mknod -m 600 "${ROOTFS}/dev/console" c 5 1
fi

# /dev/null – required by many programs
if [ ! -e "${ROOTFS}/dev/null" ]; then
    sudo mknod -m 666 "${ROOTFS}/dev/null" c 1 3
fi

# TODO: Clean and build the writer utility
echo "Cleaning and building writer utility"

WRITER_DIR="${FINDER_APP_DIR}"

cd "${WRITER_DIR}"

# Clean previous build artifacts
make clean || true

# Build writer using cross compiler
make CROSS_COMPILE=${CROSS_COMPILE}

# Install writer into root filesystem
sudo install -m 0755 writer "${OUTDIR}/rootfs/usr/bin/writer"

# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
DEST_DIR="${OUTDIR}/rootfs/home"

# Ensure /home exists in the target rootfs
sudo mkdir -p -m 755 "${DEST_DIR}"

FINDER_SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
sudo cp -rL --no-preserve=ownership "$FINDER_SRC_DIR/." "$DEST_DIR/"

# TODO: Chown the root directory
sudo chown root:root "${ROOTFS}"

#######################
# Create minimal /init script
#######################
sudo bash -c "cat << 'EOF' > "$ROOTFS/init"
#!/bin/sh
echo "Initramfs starting..."
mount -t proc proc /proc
mount -t sysfs sys /sys
mount -t devtmpfs dev /dev
mkdir -p /tmp
chmod 1777 /tmp
echo "Starting writer application..."
/usr/bin/writer &
exec /bin/sh
EOF"

sudo chmod +x "$ROOTFS/init"

#######################
# Create initramfs.cpio.gz
#######################
cd "$ROOTFS"
echo ">>> Creating initramfs.cpio.gz from $ROOTFS"
find . -print0 | cpio --null -ov --format=newc --owner root:root | gzip -9 > "${OUTDIR}/initramfs.cpio.gz"
echo ">>> initramfs.cpio.gz created at ${OUTDIR}/initramfs.cpio.gz"

echo ">>> Build complete. Kernel and initramfs are ready in $OUTDIR"
# TODO: Create initramfs.cpio.gz
