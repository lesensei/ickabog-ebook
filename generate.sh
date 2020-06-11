#!/bin/sh
set -euo pipefail
IFS=$'\n\t'

OUTPUT_DIR=out

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NORMAL='\033[0m'

mkdir -p html
mkdir -p "$OUTPUT_DIR"
MAIN_STORY_OUTPUT_FILE="html/read-the-story.html"
HTML_FILE=ickabog.html

LC=${LC:-""}
if [[ "$LC" != "" ]]; then
    LC="/$LC"
fi
MAIN_STORY_URL="https://www.theickabog.com$LC/read-the-story/"

if ! [ -x "$(command -v wget)" ] ; then
    echo -e "${RED}[-] wget command missing: aborting.$NORMAL"
    exit -1
fi

echo -n "[+] Fetching $MAIN_STORY_URL ... "

wget --quiet "$MAIN_STORY_URL" --output-document "$MAIN_STORY_OUTPUT_FILE"

if [[ $? = 0 ]]; then
    echo -e "${GREEN}Done${NORMAL}."
else
    echo -e "${RED}Failed, aborting${NORMAL}."
fi

if ! [ -x "$(command -v pup)" ] ; then
    echo -e "${RED}[-] pup command missing: aborting${NORMAL}"
    exit -1
fi

LANG=$(cat "$MAIN_STORY_OUTPUT_FILE"| pup 'html attr{lang}')
echo "[+] Language set to $LANG"

if ! [ -x "$(command -v jq)" ] ; then
    echo -e "${RED}[-] jq command missing: aborting${NORMAL}"
    exit -1
fi

MAIN_TITLE=$(cat "$MAIN_STORY_OUTPUT_FILE" | pup 'ul.chapters__list a json{}' | jq -r '[.[] | {url: .href, chapter: .children[0].children[0].children[0].children[0].text, title: .children[0].children[0].children[0].children[1].text}] | sort_by(.chapter) | .[]|[.chapter, .title, .url] | @tsv' | grep $' 2\t' | while IFS=$'\t' read -r chapter title url; do echo "$title"; done)

echo "[+] Title set to $MAIN_TITLE"

echo "<html lang=$LANG><head><meta charset=UTF-8><title>$MAIN_TITLE</title></head><body>" > "$HTML_FILE"

# args = "$url" "$chapter" "$title"
function download_chapter() {
    URL=$( ( echo -n "$1" | grep -Eq ^http ) && echo "$1" || echo "https://www.theickabog.com$1" )
    [ -s "html/$2.html" ] || wget --quiet "$URL" -O "html/$2.html"
    echo "<h1>$3</h1>" >> "$HTML_FILE"
    cat "html/$2.html" | pup 'article div.row:nth-child(2) div.entry-content' >> "$HTML_FILE"
}

cat "$MAIN_STORY_OUTPUT_FILE" |
pup 'ul.chapters__list a json{}' |
jq -r '[.[] | {url: .href, chapter: .children[0].children[0].children[0].children[0].text, title: .children[0].children[0].children[0].children[1].text}] | sort_by(.chapter | match("[0-9]+$")) | .[]|[.chapter, .title, .url] | @tsv' |
while IFS=$'\t' read -r chapter title url; do download_chapter "$url" "$chapter" "$title"; done

echo "</body></html>" >> "$HTML_FILE"

cat <<__METADATA__ > metadata.xml
<dc:creator opf:role="aut">J.K Rowling</dc:creator>
__METADATA__

if [ -x "$(command -v pandoc)" ] ; then
    echo -n "[+] Generating $OUTPUT_DIR/ickabog.epub ... "
    pandoc --from=html \
        --output="$OUTPUT_DIR/ickabog.epub" \
        --epub-metadata=metadata.xml \
        --epub-cover-image=cover.jpg \
        --epub-chapter-level=1 \
        "$HTML_FILE"

    if [[ $? = 0 ]]; then
        echo -e "${GREEN}Done${NORMAL}."
    else
        echo -e "${YELLOW}Failed${NORMAL}."
    fi
else
    echo -e "${RED}[-] pandoc command missing: aborting${NORMAL}"
    exit -1
fi

if [ -x "$(command -v kindlegen)" ] ; then
    echo -n "[+] Generating MOBI using kindlegen: $OUTPUT_DIR/ickabog.mobi ... "
    kindlegen "$OUTPUT_DIR/ickabog.epub" > /dev/null 2>&1
    if [[ $? = 0 ]]; then
        echo -e "${GREEN}Done${NORMAL}."
    else
        echo -e "${YELLOW}Failed${NORMAL}."
    fi
elif [ -x "$(command -v ebook-convert)" ] ; then
    echo -n "[+] Generating MOBI using ebook-convert: $OUTPUT_DIR/ickabog.mobi ... "
    ebook-convert "$OUTPUT_DIR/ickabog.epub" \
        "$OUTPUT_DIR/ickabog.mobi" \
        --metadata title="$MAIN_TITLE" \
        > /dev/null 2>&1
    if [[ $? = 0 ]]; then
        echo -e "${GREEN}Done${NORMAL}."
    else
        echo -e "${YELLOW}Failed${NORMAL}."
    fi
else
    echo -e "${YELLOW}[-] Both kindlegen and calibre missing: could not generate MOBI${NORMAL}"
fi

if [ -x "$(command -v xelatex)" ] ; then
    echo -n "[+] Generating PDF using xelatex: $OUTPUT_DIR/ickabog.pdf ... "
    pandoc --from=html \
        --pdf-engine=xelatex \
        --metadata title="$MAIN_TITLE" \
        --metadata author="J.K Rowling" \
        --output="$OUTPUT_DIR/ickabog-no-cover.pdf" \
        -V lang="$LANG" \
        -V geometry=margin=1.5cm \
        "$HTML_FILE"

    if [[ $? = 0 ]]; then
        echo -e "${GREEN}Done${NORMAL}."
        
		if [ -x "$(command -v qpdf)" ] ; then
            echo -n "  [+] Adding cover to PDF ... "
            qpdf --empty --pages cover.pdf "$OUTPUT_DIR/ickabog-no-cover.pdf" -- "$OUTPUT_DIR/ickabog.pdf"
            if [[ $? = 0 ]]; then
                echo -e "${GREEN}Done${NORMAL}."
            else
                echo -e "${YELLOW}Failed${NORMAL}."
            fi
        else
            echo -e "  ${YELLOW}[-] qpdf command missing: not adding cover to PDF${NORMAL}."
            mv "$OUTPUT_DIR/ickabog-no-cover.pdf" "$OUTPUT_DIR/ickabog.pdf"
        fi
    else
        echo -e "${YELLOW}Failed${NORMAL}."
    fi
else
    echo -e "${YELLOW}[-] xelatex command missing: could not generate PDF${NORMAL}"
fi


# Run only if context is available
if [ -x "$(command -v context)" ] ; then
    echo -n "[+] Generating large font PDF using context: $OUTPUT_DIR/ickabog-large.pdf ... "
    pandoc --from=html --to=pdf \
        -V fontsize=18pt \
        --output="$OUTPUT_DIR/ickabog-large-no-cover.pdf" \
        --metadata title="$MAIN_TITLE" \
        --metadata author="J.K Rowling" \
        --pdf-engine=context \
        -V margin-left=0cm \
        -V margin-right=0cm \
        -V margin-top=0cm \
        -V margin-bottom=0cm \
        -V geometry=margin=0cm \
        -V lang="$LANG" \
        "$HTML_FILE"

    if [[ $? = 0 ]]; then
        echo -e "${GREEN}Done${NORMAL}."
        
		if [ -x "$(command -v qpdf)" ] ; then
            echo -n "  [+] Adding cover to large font PDF ... "
            qpdf --empty --pages cover.pdf "$OUTPUT_DIR/ickabog-large-no-cover.pdf" -- "$OUTPUT_DIR/ickabog-large.pdf"
            if [[ $? = 0 ]]; then
                echo -e "${GREEN}Done${NORMAL}."
            else
                echo -e "${YELLOW}Failed${NORMAL}."
            fi
        else
            echo -e "  ${YELLOW}[-] qpdf command missing: not adding cover to large font PDF${NORMAL}."
            mv "$OUTPUT_DIR/ickabog-large-no-cover.pdf" "$OUTPUT_DIR/ickabog-large.pdf"
        fi
    else
        echo -e "${YELLOW}Failed${NORMAL}."
    fi
else
    echo -e "${YELLOW}[-] context command missing: could not generate large font PDF${NORMAL}"
fi

