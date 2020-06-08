#!/bin/bash

mkdir -p html

LC="/fr" # empty for english
PUP=/root/go/bin/pup
LANG=$(wget --quiet https://www.theickabog.com$LC/read-the-story/ -O- | $PUP 'html attr{lang}')
HTML_FILE=ickabog.html
MAIN_TITLE=$(wget --quiet https://www.theickabog.com$LC/read-the-story/ -O- | $PUP 'ul.chapters__list a json{}' | jq -r '[.[] | {url: .href, chapter: .children[0].children[0].children[0].children[0].text, title: .children[0].children[0].children[0].children[1].text}] | sort_by(.chapter) | .[]|[.chapter, .title, .url] | @tsv' | grep $' 2\t' | while IFS=$'\t' read -r chapter title url; do echo "$title"; done)
OUTPUT_DIR=out

mkdir -p $OUTPUT_DIR

echo "<html><head><title>$MAIN_TITLE</title></head><body>" > "$HTML_FILE"

function download_chapter() {
	[[ $2 =~ 1$ ]] && MAIN_TITLE=$3
    URL=$( [[ $1 =~ ^http ]] && echo "$1" || echo "https://www.theickabog.com$1" )
    [ -s "html/$2.html" ] || wget --quiet "$URL" -O "html/$2.html"
    echo "<h2>$3</h2>" >> "$HTML_FILE"
    cat "html/$2.html" | $PUP 'article div.row:nth-child(2) div.entry-content' >> "$HTML_FILE"
}

wget --quiet https://www.theickabog.com$LC/read-the-story/ -O- | $PUP 'ul.chapters__list a json{}' | jq -r '[.[] | {url: .href, chapter: .children[0].children[0].children[0].children[0].text, title: .children[0].children[0].children[0].children[1].text}] | sort_by(.chapter | match("[0-9]+$")) | .[]|[.chapter, .title, .url] | @tsv' | while IFS=$'\t' read -r chapter title url; do download_chapter "$url" "$chapter" "$title"; done

echo "</body></html>" >> "$HTML_FILE"

pandoc --from=html --to=pdf \
    --output=ickabog1.pdf \
    --metadata title="$MAIN_TITLE" \
    --metadata author="J.K Rowling" \
    --pdf-engine=xelatex \
    --dpi=300 \
    -V book \
    -V lang=$LANG \
    -V geometry=margin=1.5cm \
    "$HTML_FILE"

qpdf --empty --pages cover.pdf ickabog1.pdf -- "$OUTPUT_DIR/ickabog.pdf"

echo "<dc:title id=\"epub-title-1\" opf:type=\"main\">$MAIN_TITLE</dc:title>" > metadata.xml
echo "<dc:date>$(date -I)</dc:date>" >> metadata.xml
echo "<dc:language>$LANG</dc:language>" >> metadata.xml
echo "<dc:creator id=\"epub-creator-1\" opf:role=\"aut\">J.K Rowling</dc:creator>" >> metadata.xml

pandoc --from=html --to=epub \
    --output="$OUTPUT_DIR/ickabog.epub" \
    --epub-metadata=metadata.xml \
    --epub-cover-image=cover.jpg \
	--epub-chapter-level=2 \
    "$HTML_FILE"

./kindlegen "$OUTPUT_DIR/ickabog.epub"
