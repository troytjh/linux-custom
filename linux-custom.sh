#!/bin/bash

LINUX_CUSTOM=/home/troytjh/.cache/build/linux-custom
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

cd $SCRIPT_DIR
#asp update linux
git submodule update --remote --init --recursive
if [ -d linux-src ]; then
    #cd linux-src
    #git pull
    #cd ..

    if [ -d linux ]; then
        cp -f linux-src/trunk/* linux
    else
        cp -r linux-src/trunk linux
    fi    
    
    if [ -d linux/src/archlinux-linux ]; then
        cd linux/src/archlinux-linux
        git stash
        git stash clear
        cd ../../..
    fi
    
    cd linux
else
    #if [ -d linux ]; then
    #    mv linux linux-tmp
    #fi   
    #asp chechout linux
    #mv linux linux-src
    cp -f linux-src/trunk/* linux
    #mv linux-tmp linux

    cd linux
fi

#cd linux
pkgver=`awk '/^pkgver/ {print $1}' PKGBUILD | awk -F'=' '{print $2}'`
pkgnew=`awk '/^pkgver/ {print $1}' PKGBUILD | awk -F'=' '{print $2}'`
srctag=${pkgver%.*}-${pkgver##*.}
patch PKGBUILD < ../mkpkg.patch
#patch -b config < ../config.patch
if [ ! -d "src" ]; then
   mkdir src
fi
cp ../OpenRGB.patch . && cp ../OpenRGB.patch src
cp ../config.patch . && cp ../config.patch src
sed -i 's/pkgbase=linux/pkgbase=linux-custom/g' PKGBUILD
sed -i "s/pkgver=$pkgnew/pkgver=$pkgver/g" PKGBUILD
updpkgsums

if [ -d archlinux-linux ]; then
    cd archlinux-linux/
    git log --oneline --max-count 1 HEAD
    git fetch --verbose
    cd ../src

    if [ -d archlinux-linux ]; then
        cd archlinux-linux
        git stash
        git stash clear
        git checkout master
        git pull
        git fetch --tags --verbose
        git branch --verbose $srctag v$srctag
        git checkout $srctag

        git log --oneline $srctag

        cd ../../
    else
        cd ..
    fi
fi
makepkg --verifysource

build () {
	printf "\nPackages to build\n\n"; printf "$srctag\n\n"
	printf "Build?[y,n] "
	read ans
	case $ans in 
		y|Y)    printf "\n";
			tmpfs;
		        prepare;	
			makepkg --noextract -s;
			install;

			if [[ "$tmp" -eq 1 ]]; then
			    cd src;
			    shopt -s dotglob nullglob
			    mv archlinux-linux/* tmp;
			    printf "unmounting tmpfs archlinux-linux\n"
			    sudo umount archlinux-linux;
			    mv tmp/* archlinux-linux;
			    rm -r tmp
			fi ;;

       		n|N) 	printf "\n";
			clean ;;

       		*) 	printf "\n" ;;
	esac;
}

prepare () {
	pkgbase=`awk '/^pkgbase/ {print $1}' PKGBUILD | awk -F'=' '{print $2}'`
	pkgrel=`awk '/^pkgrel/ {print $1}' PKGBUILD | awk -F'=' '{print $2}'`
	sed -ie '/source=/a \ \ config.patch' PKGBUILD
	sed -ie '/source=/a \ \ OpenRGB.patch' PKGBUILD
	source=( 
  		`cat PKGBUILD \
  		| awk '/^source/,EOF {print}' \
  		| awk 'NR==3,/)/ {print prev} {prev = $0 }'`
  	)
	echo ${source[@]}
	cd src/archlinux-linux/
	
	echo "Setting version..."
	scripts/setlocalversion --save-scmversion
	echo "-$pkgrel" > localversion.10-pkgrel
	echo "${pkgbase#linux}" > localversion.20-pkgname

	local src
	for src in "${source[@]}"; do
	    src="${src%%::*}"
	    src="${src##*/}"
    	[[ $src = *.patch && $src ]] || continue
    	echo "Applying patch $src..."
    	patch -Np1 < "../$src"
	done

	echo "Setting config..."
	cp ../config .config
	make olddefconfig
        sed -i 's/#\ CONFIG_I2C_NCT6775\ is\ not\ set/CONFIG_I2C_NCT6775=m/g' .config
#	patch -b .config ../config.patch
	
	make -s kernelrelease > version
	echo "Prepared $pkgbase version $(<version)"
	cd ../../
}

tmpfs() {
    printf "\nBuild w/ tmpfs?[y,n] "
    read ans
    case $ans in 
        y|Y)    printf "\n";

                cd src/archlinux-linux;
		# printf "make mrproper\n";
		# sudo make mrproper;
		cd ..;

		if mv archlinux-linux tmp; then
		    mkdir archlinux-linux;
		    printf "\nsudo mount -t tmpfs -o size=18G tmpfs src/archlinux-linux\n";
		    sudo mount -v -t tmpfs -o size=18G tmpfs ${LINUX_CUSTOM}/linux/src/archlinux-linux;
		    mv tmp/* archlinux-linux;
		fi;
		cd ..;
		tmp=1 ;;

        n|N)    printf "\n" ;;
            

        *)      printf "\n" ;;
    esac;
}

install () {
	printf "\nPackages to install\n\n" 
	echo `ls linux-custom-$pkgver-$pkgrel-x86_64.pkg.tar.zst | awk -F'-x86_64.pkg' '{print $1}'`; printf "\n";
	printf ":: Proceed with installation? [y,n] "
	read ans
	case $ans in 
		y|Y) 	printf "\n"; 
			yay -U linux-custom-$pkgver-$pkgrel-x86_64.pkg.tar.zst \
				linux-custom-headers-$pkgver-$pkgrel-x86_64.pkg.tar.zst;
			clean ;;

       		n|N) 	printf "\n" ;
			clean ;;

       		*) 	printf "\n" ;
			clean ;;
	esac;
}

clean () {
	printf "\nClean packages? [y,n] "
	read ans
	case $ans in 
		y|Y) 	printf "\n"; 
			rm *.pkg.tar.zst ;;
	
		*)	printf "\n" ;;
	esac;
}

build
