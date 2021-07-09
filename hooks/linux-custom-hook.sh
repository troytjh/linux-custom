LINUX_CUSTOM=/home/troytjh/.cache/build/linux-custom
	
cd $LINUX_CUSTOM
mv linux linux-tmp
asp update linux
asp export linux
mv linux/* linux-tmp
mv linux-tmp/* linux
rm -r linux-tmp
	
cd linux
patch PKGBUILD < ../mkpkg.patch
#patch -b config < ../config-8700k.patch
sed -i 's/pkgbase=linux/pkgbase=linux-custom/g' PKGBUILD
pkgver=`awk '/^pkgver/ {print $1}' PKGBUILD | awk -F'=' '{print $2}'`
pkgbase=`awk '/^pkgbase/ {print $1}' PKGBUILD | awk -F'=' '{print $2}'`
pkgrel=`awk '/^pkgrel/ {print $1}' PKGBUILD | awk -F'=' '{print $2}'`
srctag=${pkgver%.*}-${pkgver##*.}
updpkgsums
	
cd archlinux-linux/
git --no-pager log --oneline --max-count 1 HEAD
git fetch --verbose

cd ../src/archlinux-linux/
git stash
git stash clear
git checkout master
git pull
git fetch --tags --verbose
git branch --verbose $srctag v$srctag
git checkout $srctag

git --no-pager log --oneline --max-count 40 $srctag

cd ../../
makepkg --noextract --verifysource

build () {
	printf "\nPackages to build\n\n"; printf "$pkgver\n\n"
	prepare
	makepkg --noextract -s --noconfirm
	printf "Run install-linux\n"
}

prepare () {
	source=( 
		`cat PKGBUILD \
		| awk '/^source/,EOF {print}' \
		| awk 'NR==4,/)/ {print prev} {prev = $0 }'`
		OpenRGB.patch
	)
	echo $source[@]
	cd src/archlinux-linux/

  	echo "Setting version..."
  	scripts/setlocalversion --save-scmversion
  	echo "-$pkgrel" > localversion.10-pkgrel
  	echo ${pkgbase#linux} > localversion.20-pkgname
	echo version set linux-$pkgver`cat localversion.10-pkgrel``cat localversion.20-pkgname`
	printf "\n"

  	local src
  	for src in "${source[@]}"; do
    	src="${src%%::*}"
    	src="${src##*/}"
    	[[ $src = *.patch ]] || continue
    	echo "Applying patch $src..."
    	patch -Np1 < "../$src"
  	done

  	echo "Setting config..."
  	cp ../config .config
  	make olddefconfig

  	make -s kernelrelease > version
  	echo "Prepared $pkgbase version $(<version)"
	
	cd ../../
}

build
