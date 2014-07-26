#!/bin/bash

function say {
	echo
	echo "$@"
	echo
}

function run {
	echo "$@"
	"$@"
}

rev="$1"
if [ -z "$rev" ]
then
  echo "$0 <rev>"
fi

set -e


cd ~/logs/

cd ghc-master
git pull
git submodule update --recursive
cd ..



if [ -e "ghc-tmp-$rev" ]
then
	echo "ghc-tmp-$rev already exists"
	exit 1
fi

#logfile="$rev-$(date --iso=minutes).log"
logfile="$rev.log"
exec > >(sed -e "s/ghc-tmp-$rev/ghc-tmp-REV/g" | tee "$logfile".tmp)
exec 2>&1

set -o errtrace

function failure {
	test -f "$logfile".tmp || cd ..
	say "Failure..."
	run mv "$logfile".tmp "$logfile".broken
	run rm -rf "ghc-tmp-$rev"
}
trap failure ERR

say "Cloning"

run git clone --recursive --reference ghc-master git://git.haskell.org/ghc "ghc-tmp-$rev"
cd "ghc-tmp-$rev"
run git checkout "$rev"

say "Identifying"

run git log -n 1

say "Code stats"

run ohcount compiler/

run ohcount rts/

run ohcount testsuite/

say "Booting"

run perl boot

say "Configuring"

echo "Try to match validate settings"
echo 'GhcLibHcOpts += -O -dcore-lint'  >> mk/build.mk
echo 'GhcStage2HcOpts += -O -dcore-lint'  >> mk/build.mk

run ./configure

say "Building"

run /usr/bin/time -o buildtime make -j8 V=0
echo "Buildtime was:"
cat buildtime

say "Running the testsuite"

run make -C testsuite fast VERBOSE=4 THREADS=8

say "Running nofib"

run cd nofib/
run make boot
run make
run cd ..

say "Total space used"

run du -sc .

say "Cleaning up"

run cd ..
run rm -rf "ghc-tmp-$rev"
run mv "$logfile".tmp "$logfile"
