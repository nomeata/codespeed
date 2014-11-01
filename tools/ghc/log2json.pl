#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use File::Slurp;
use JSON;
use IPC::Run qw/run/;

my $TIME = {
	units_title => "Time",
	units => "seconds",
	lessisbetter => "True",
};
my $BUILDTIME = {
	units_title => "Buildtime",
	units => "seconds",
	lessisbetter => "True",
};

my $ALLOC = {
	units_title => "Allocations",
	units => "bytes",
	lessisbetter => "True",
};

my $BINARY_SIZE = {
	units_title => "Binary size",
	units => "bytes",
	lessisbetter => "True",
};

my $GOOD_TESTS = {
	units_title => "Tests",
	units => "tests",
	lessisbetter => "False",
};

my $BAD_TESTS = {
	units_title => "Tests",
	units => "tests",
	lessisbetter => "True",
};

for my $filename (@ARGV) {
	my $output = dirname($filename)."/".basename($filename,".log"). ".json";

	my $log = read_file($filename);

	my $commit;
	if ($log =~ m/^commit ([a-f0-9]+)$/m) {
		$commit = $1;
	} else {
		die "Coult not find commit ID in $filename\n";
	}

	my $data = [];
	my $report = sub {
		my ($unit, $name, $value) = @_;
		push @$data, {
			commitid => $commit,
			project => "GHC",
			branch => "default",
			executable => "ghc",
			environment => "nomeata's buildbot",
			benchmark => $name,
			result_value => $value,
			units_title => $unit->{units_title},
			units => $unit->{units},
			lessisbetter => $unit->{lessisbetter},
		}

	};

	$report->($ALLOC, "tests/alloc/$1", $2)
		while ($log =~ m/^    Actual  +([a-zA-Z0-9_\.-]+)\([a-z]*\) bytes allocated: (\d+)\s*$/mg);


	$report->($GOOD_TESTS, 'testsuite/tests', $1)
		if ($log =~ m/^ +(\d+) total tests, which gave rise to/m);
	$report->($GOOD_TESTS, 'testsuite/expected passes', $1)
		if ($log =~ m/^ +(\d+) expected passes/m);
	$report->($BAD_TESTS, 'testsuite/framework failures', $1)
		if ($log =~ m/^ +(\d+) caused framework failures/m);
	$report->($BAD_TESTS, 'testsuite/unexpected passes', $1)
		if ($log =~ m/^ +(\d+) unexpected passes/m);
	$report->($BAD_TESTS, 'testsuite/expected failures', $1)
		if ($log =~ m/^ +(\d+) expected failures/m);
	$report->($BAD_TESTS, 'testsuite/unexpected stats', $1)
		if ($log =~ m/^ +(\d+) unexpected stat failures/m);
	$report->($BAD_TESTS, 'testsuite/unexpected failures', $1)
		if ($log =~ m/^ +(\d+) unexpected failures/m);

	$report->($BUILDTIME, 'buildtime/make', $1*60 + $2)
		if ($log =~ m/^Buildtime was:\n[\d\.]+user [\d\.]+system (\d+):(\d+\.\d+)elapsed/m);

	my $out;
	run (["nofib-analyse", "--csv=Allocs"], \$log, \$out) or die "cat: $?";
	for (split /^/, $out) {
		$report->($ALLOC, "nofib/allocs/$1", $2)
			if /(.*),(.*)/;
	}
	run (["nofib-analyse", "--csv=Runtime"], \$log, \$out) or die "cat: $?";
	for (split /^/, $out) {
		$report->($TIME, "nofib/time/$1", $2)
			if /(.*),(.*)/ and $2 > 0.3;
	}
	run (["nofib-analyse", "--csv=Size"], \$log, \$out) or die "cat: $?";
	for (split /^/, $out) {
		$report->($BINARY_SIZE, "nofib/size/$1", $2)
			if /(.*),(.*)/;
	}
	write_file($output, to_json($data, {utf8 => 1, pretty => 1}));
}
