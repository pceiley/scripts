#!/bin/bash
#
# Install the binary plugin for HPs hplip printer driver library on Clear Linux.
# The hplip binary plugin licence is proprietary.
#
# This script was adapted from https://aur.archlinux.org/packages/hplip-plugin
#
# See:
# http://hplipopensource.com/node/309
# https://developers.hp.com/hp-linux-imaging-and-printing/binary_plugin.html

#pkgver=3.19.8
pkgver=`awk -F= '/version/{ print $2 }' /usr/share/defaults/etc/hp/hplip.conf`
pkgdesc="Binary plugin for HPs hplip printer driver library"
#source=("http://www.openprinting.org/download/printdriver/auxfiles/HP/plugins/hplip-$pkgver-plugin.run")
source=("https://developers.hp.com/sites/default/files/hplip-$pkgver-plugin.run")
srcdir=`mktemp -d`

precheck() {
    # This script must be run as root
    if [[ $EUID -ne 0 ]]; then
        echo "This script must be run as root"
        exit 1
    fi

    # Make sure the hplip version was obtained and the temp dir was created
    if [ -z "$pkgver" ] || [ -z "$srcdir" ]; then
	echo "Could not identify installed hplip version"
        exit 1
    fi
}

download_plugin() {
    cd "$srcdir"
    curl -LO $source
    sh "hplip-$pkgver-plugin.run" --target "$srcdir/hplip-$pkgver-plugin" --noexec
}

install_plugin(){
    cd "$srcdir/hplip-$pkgver-plugin"

    _arch='x86_64'

    # Create folders
    install -d "/usr/share/hplip/data/firmware"
    install -d "/usr/share/hplip/fax/plugins"
    install -d "/usr/share/hplip/prnt/plugins"
    install -d "/usr/share/hplip/scan/plugins"
    install -d "/usr/share/licenses/hplip-plugin"
    install -d "/var/lib/hp"

    # Copy files
    install -m644 plugin.spec                  "/usr/share/hplip/"
    install -m644 hp_laserjet_*.fw.gz          "/usr/share/hplip/data/firmware/"
    install -m755 fax_marvell-"$_arch".so      "/usr/share/hplip/fax/plugins/"
    install -m755 hbpl1-"$_arch".so            "/usr/share/hplip/prnt/plugins/"
    install -m755 lj-"$_arch".so               "/usr/share/hplip/prnt/plugins/"
    install -m755 bb_*-"$_arch".so             "/usr/share/hplip/scan/plugins/"
    install -m644 license.txt                  "/usr/share/licenses/hplip-plugin/"

    # Create hplip.state used by hplip-tools
    cat << EOF > hplip.state
[plugin]
installed = 1
eula = 1
version = $pkgver
EOF
    install -m644 hplip.state "$pkgdir/var/lib/hp"

    # Create symlinks
    find "$pkgdir/usr/share/hplip" -type f -name "*.so" | while read f; do
        lib_dir="${f%/*}"
        lib_name="${f##*/}"
        ln -vsf "$lib_name" "$lib_dir/${lib_name%%-*}.so"
    done

    # The binary plugin relies on /etc/hp/hplip.conf being present
    [ ! -d /etc/hp ] && sudo ln -s /usr/share/defaults/etc/hp /etc/hp
}

precheck
download_plugin
install_plugin

