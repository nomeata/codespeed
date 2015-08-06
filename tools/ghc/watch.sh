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
			if git cat-file -e HEAD:$rev.log 2>/dev/null; then continue; fi
			if git cat-file -e HEAD:$rev.log.broken 2>/dev/null; then continue; fi
			if test -d "ghc-tmp-$rev"; then continue; fi

			echo "Benchmarking $rev..."
			$scripts/run-speed.sh "$rev" >/dev/null
			$scripts/log2json.pl "$rev.log"
			$scripts/upload.sh "$rev.json"
			rm -f "$rev.json"

			git add $rev.log*
			git commit -m "Log for $rev"
			git push
			git checkout --
			break
		done
	done
	sleep 60 || break
done
