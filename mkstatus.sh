#!/usr/bin/env sh
# SPDX-License-Identifier: CC0-1.0
# SPDX-FileCopyrightText: 2022 Ayman El Didi
set -euf

user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/98.0.4758.81 Safari/537.36'
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p out/
find out -type f -exec rm {} \;
cp -r green-circle.svg orange-circle.svg font/ 404.html out/

if [ "$#" != 4 ]; then
	printf 'usage: mkstatus.sh <checks.tsv> <incidents.tsv> <status page url> <org name>\n'
	exit 1
fi

if [ ! "$(command -v curl)" ]; then
	printf 'error: curl is not installed\n'
	exit 1
fi

# I'll eventually add a test that just pings some address.
if [ ! "$(command -v ping)" ]; then
	printf 'error: ping is not installed\n'
	exit 1
fi

# Arguments:
#	$1 = The URL to check.
#	$2 = The status code to check for.
check_http() {
	# IPv4
	(curl -X GET -4isSfIL -H "$user_agent" -m 10 -w '%{http_code}' -o /dev/null "$1" \
		| grep -q "$2") &&
	# IPv6
	(curl -X GET -6isSfIL -H "$user_agent" -m 10 -w '%{http_code}' -o /dev/null "$1" \
		| grep -q "$2")
}

touch "$tmpdir/services.html"

# Actually perform the checks

IFS='	'
while read -r test_type status name url; do
	test_type="$(echo "$test_type" | awk '{$1=$1};1')"
	status="$(echo "$status" | awk '{$1=$1};1')"
	name="$(echo "$name" | awk '{$1=$1};1')"
	url="$(echo "$url" | awk '{$1=$1};1')"
	case "$test_type" in
	http)
		if check_http "$url" "$status"; then
			printf '\n<div class="valign"><img class="status" alt="Operational:" src="/green-circle.svg">%s</div>\n' "$name" >> "$tmpdir/services.html"
		else
			printf '\n<div class="valign"><img class="status" alt="Failure:" src="/orange-circle.svg">%s</div>\n' "$name" >> "$tmpdir/services.html"
		fi
		;;
	ping)
		printf 'error: not implemented\n'
		exit 1
		;;
	*)
		printf 'error: "%s" is not a test type\n' "$test_type"
		exit 1
		;;
	esac
done < "$1"

# Generate the summary at the top of the page

cat "header.html" > "$tmpdir/header.html"
failtext='Failure'
if grep -q "$failtext" "$tmpdir/services.html"; then
	count="$(grep -c "$failtext" "$tmpdir/services.html")"
	printf '<summary class="valign failure-border">%s Service(s) Down</summary>\n' \
		"$count" >> "$tmpdir/header.html"
else
	printf '<summary class="valign success-border">All Systems Operational</summary>\n' \
		>> "$tmpdir/header.html"
fi

printf '<p class="small">Last updated <span class="last-checked">%s</span></p>\n<div class="grid">\n' \
	"$(date -u +'%Y-%m-%dT%H:%M:%SZ')" >> "$tmpdir/header.html"
cat "$tmpdir/services.html" >> "$tmpdir/header.html"
printf '</div>\n<a class="incident-feed" href="/rss.xml">Incident History (RSS)</a>
<h1><a name="incidents"></a>Incidents</h1>\n' >> "$tmpdir/header.html"
touch "$tmpdir/incident_report.html"

if [ "$(wc -l "$2" | awk '{print $1}')" = '0' ]; then
	cat "$tmpdir/header.html" > 'out/index.html' 
	printf '<p>No incidents yet.</p>\n<div class="center"><p>1/1</p></div>' \
		>> 'out/index.html'
	cat 'footer.html' >> 'out/index.html'
fi

cp "$2" "$tmpdir/incidents.tsv"
incidents_lines="$(wc -l "$tmpdir/incidents.tsv" | awk '{print $1}')"
num_pages="$(($incidents_lines / 5))"
if [ "$num_pages" = '0' ]; then
	num_pages='1'
fi
current_page='1'
while [ "$(head -n 5 "$tmpdir/incidents.tsv")" != '' ]; do
	outfile='out/index.html'
	if [ "$current_page" != '1' ]; then
		outfile="out/$current_page.html"
	fi

	cat "$tmpdir/header.html" > "$outfile"

	lines="$(head -n 5 "$tmpdir/incidents.tsv")"
	tail -n +6 "$tmpdir/incidents.tsv" > "$tmpdir/tmp"
	mv "$tmpdir/tmp" "$tmpdir/incidents.tsv"

	echo "$lines" | awk -F'\t' '{
			print "<div class=\"incident\"><strong>" $1;
			print "</strong><p>" $2 "</p></div>";
		}' >> "$outfile"

	printf '<p class="center">' >> "$outfile"
	if [ "$current_page" != '1' ]; then
		# Not the first page, so render the previous page button
		printf '<a href="/%s.html">Previous Page</a>' \
			"$(($current_page - 1))" >> "$outfile"
	fi

	printf '<span>%s / %s</span>' "$current_page" "$num_pages" >> "$outfile"

	if [ "$current_page" != "$num_pages" ]; then
		# Not the last page, so render the next page button
		printf '<a href="/%s.html">Next Page</a>' \
			"$(($current_page + 1))" >> "$outfile"
	fi

	printf '</p>\n' >> "$outfile"
	cat 'footer.html' >> "$outfile"
	current_page="$(($current_page + 1))"
done

# Generate the incident RSS feed

# Arguments:
# $1 = path to incidents.tsv
# $2 = the status website's url
# $3 = the name of the one hosting the status website
generate_feed() {
	echo '<?xml version="1.0" encoding="UTF-8" ?><rss version="2.0">
<channel>'
	printf '<title>%s</title>
<link>%s</link>
<description>The incident history for %s</description>\n' "$3" "$2" "$2"
	while read -r date description; do
		printf '<item>'
		printf '<title>%s</title>
<link%s</link>
<description>%s</description>' "$date" "$2" "$description"
		echo '</item>'
	done < "$1"
	echo '</channel></rss>'
}

generate_feed "$2" "$3" "$4" > out/rss.xml

cp 'out/index.html' 'out/1.html'
rm -rf "$tmpdir"
