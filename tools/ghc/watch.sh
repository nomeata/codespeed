#!/bin/bash

scripts="$(realpath "$(dirname $0)")"
cd ~/logs/

PATH=/opt/ghc/7.8.4/bin:/opt/alex/3.1.4/bin/:/opt/happy/1.19.5/bin/:$PATH

while true
do
	git -C ghc-master fetch --prune
	git -C ghc-master pull
	for branchtip in $(git -C ghc-master for-each-ref --format='%(objectname)')
	do
		if ! git -C ghc-master merge-base --is-ancestor 57ed4101687651ba3de59fb75355f4b83ffdca75 $branchtip
		then
			continue
		fi

		for rev in $(git -C ghc-master log --format=%H --first-parent 57ed4101687651ba3de59fb75355f4b83ffdca75..$branchtip | tac)
		do
			if ! [ -e "$rev.log" -o  -e "$rev.log.broken" -o -d "ghc-tmp-$rev" ]
			then
				echo "Benchmarking $rev..."
				$scripts/run-speed.sh "$rev" >/dev/null
				$scripts/log2json.pl "$rev.log"
				$scripts/upload.sh "$rev.json"

				git add $rev.log*
				git commit -m "Log for $rev"
				git push
				break
			fi
		done
	done
	sleep 60 || break
done
