#!/usr/bin/sh

# textbook content settings
OUTPUT_FILENAME=documentation
OUTPUT_DIRECTORY=public

# ignore lines 4-5 from original makefile
#IMAGES=$(find source/images -type f)
CHAPTERS=$(find source/chapters -name '*.md')

# output configuration files
HOME='--defaults assets/defaults/home.yml'
HTML='--filter pandoc-crossref --defaults assets/defaults/html.yml --mathjax'
DOCX='--defaults assets/defaults/docx.yml'
LATEX='--filter pandoc-crossref --defaults assets/defaults/latex.yml --no-highlight'
EPUB='--defaults assets/defaults/epub.yml --mathml --resource-path=.:source/images'
OAI='assets/empty.txt --defaults assets/defaults/oai.yml'


# utilities
PANDOC_COMMAND='pandoc --quiet'

# build commands
epub="$OUTPUT_DIRECTORY/$OUTPUT_FILENAME.epub"

html="$OUTPUT_DIRECTORY/$OUTPUT_FILENAME.html"

pdf="$OUTPUT_DIRECTORY/$OUTPUT_FILENAME.pdf"

docx="$OUTPUT_DIRECTORY/$OUTPUT_FILENAME.docx"

latex="$OUTPUT_DIRECTORY/$OUTPUT_FILENAME.tex"

markdown="$OUTPUT_DIRECTORY/$OUTPUT_FILENAME.md"

oai="$OUTPUT_DIRECTORY/$OUTPUT_FILENAME.xml"

# maybe use 'chmod +x [file]' command to all files in directory

# command line helpers
# parse arguments


function status {
    $QUIET && return
    BOLD=$(tput bold)
    NORMAL=$(tput sgr0)
    echo "${BOLD}$*${NORMAL}"
}

function x {
    _IFS="$IFS"
    IFS=" "
    $QUIET || echo "↪" "$*" >&2
    IFS="$_IFS"
    "$@"
}

preprocess() {
    docx_files=`ls -1 source/preprocess/*.docx 2>/dev/null | wc -l`
    odt_files=`ls -1 source/preprocess/*.odt 2>/dev/null | wc -l`
    latex_files=`ls -1 source/preprocess/*.tex 2>/dev/null | wc -l`

    if [ $docx_files != 0 ] ; then 
    for f in source/preprocess/*.docx
        do 
            pandoc "$f" -t markdown --wrap=none --extract-media=assets/images -s -o "${f%.*}.md"
            mv "${f%.docx}.md" source/chapters/
        done
    fi

    if [ $odt_files != 0 ] ; then 
    for f in source/preprocess/*.odt
        do 
            pandoc "$f" -t markdown --wrap=none --extract-media=assets/images -s -o "${f%.*}.md"
            mv "${f%.odt}.md" source/chapters/
        done
    fi

    if [ $latex_files != 0 ] ; then 
    for f in source/preprocess/*.tex
        do 
            pandoc "$f" -t latex --wrap=none -s -o "${f%.*}.md"
            mv "${f%.odt}.md" source/chapters/
        done
    fi
}

reset() {
    rm -r $OUTPUT_DIRECTORY;
    rm -r _temp;
    echo "🗑️ Let's start over.";
}

epub() {
    awk 'FNR==1 && NR!=1 {print "\n\n"}{print}' $CHAPTERS >> chapters.md;
    mkdir -p $OUTPUT_DIRECTORY;
    $PANDOC_COMMAND chapters.md $EPUB -o $epub;
    rm chapters.md;
    echo "📖 The EPUB edition is now available in $epub";
}

html() {
    TIME_START=$(date +%s)
    mkdir -p $OUTPUT_DIRECTORY
    touch $OUTPUT_DIRECTORY/dummy.txt
    rm -r $OUTPUT_DIRECTORY/
    mkdir -p $OUTPUT_DIRECTORY
    mkdir -p _temp/
    touch _temp/dummy.txt
    rm -r _temp/
    mkdir -p _temp/

    echo "Copying assets"
    if [ -d "source/images" ] 
    then
        cp -r source/images $OUTPUT_DIRECTORY; 
    else
        echo "No images. Skipping..."
    fi 
    cp -r assets/lib $OUTPUT_DIRECTORY;
    cp -r assets/styles/ $OUTPUT_DIRECTORY;
    
    echo "Copying static files..."
    for FILE in source/chapters/*; do
        [[ "$FILE" == *.md ]] && continue
        x cp "$FILE" $OUTPUT_DIRECTORY
    done

    echo "Extracting metadata..."
    for FILE in source/chapters/*.md; do

        pandoc "$FILE" \
            --metadata-file source/data/metadata.yml \
            --metadata basename="$(basename "$FILE" .md)" \
            --template assets/templates/category.template.txt \
            -t html -o "_temp/$(basename "$FILE" .md).category.txt"

        pandoc "$FILE" \
            --metadata htmlfile="$(basename "$FILE" .md).html" \
            --template assets/templates/metadata.template.json \
            --to html -o "_temp/$(basename "$FILE" .md).metadata.json"
    done;

    # this next block is straight from nyum...
    echo "Grouping metadata by category..."  # (yep, this #is a right mess)
    echo "{\"categories\": [" > _temp/index.json
    SEPARATOR_OUTER=""  # no comma before first list element #(categories)
    SEPARATOR_INNER=""  # ditto (recipes per category)
    IFS=$'\n'           # tell for loop logic to split on #newlines only, not spaces
    CATS="$(cat _temp/*.category.txt)"
    for CATEGORY in $(echo "$CATS" | cut -d" " -f2- | sort | uniq); do
        printf '%s' "$SEPARATOR_OUTER" >> _temp/index.json
        CATEGORY_FAUX_URLENCODED="$(echo "$CATEGORY" | awk -f "assets/templates/faux_urlencode.awk")"

        # some explanation on the next line and similar #ones: this uses `tee -a`
        # instead of `>>` to append to two files instead of #one, but since we don't
        # actually want to see the output, pipe that to /dev/#null
        x printf '%s' "{\"category\": \"$CATEGORY\", \"category_faux_urlencoded\": \"$CATEGORY_FAUX_URLENCODED\", \"recipes\": [" | tee -a "_temp/index.json" "_temp/$CATEGORY_FAUX_URLENCODED.category.json" > /dev/null
        for C in $CATS; do
            BASENAME=$(echo "$C" | cut -d" " -f1)
            C_CAT=$(echo "$C" | cut -d" " -f2-)
            if [[ "$C_CAT" == "$CATEGORY" ]]; then
                printf '%s' "$SEPARATOR_INNER" | tee -a "_temp/index.json" "_temp/$CATEGORY_FAUX_URLENCODED.category.json" > /dev/null
                x cat "_temp/$BASENAME.metadata.json" | tee -a "_temp/index.json" "_temp/$CATEGORY_FAUX_URLENCODED.category.json" > /dev/null
                SEPARATOR_INNER=","
            fi
        done
        x printf "]}\n" | tee -a "_temp/index.json" "_temp/$CATEGORY_FAUX_URLENCODED.category.json" >/dev/null
        SEPARATOR_OUTER=","
        SEPARATOR_INNER=""
    done
    unset IFS
    echo "]}" >> _temp/index.json
    echo "Building chapter pages..."
    for FILE in source/chapters/*.md;do
        CATEGORY_FAUX_URLENCODED="$(cat "_temp/$(basename "$FILE" .md).category.txt" | cut -d" " -f2- | awk -f "assets/templates/faux_urlencode.awk")"
        # when running under GitHub Actions, all file #modification dates are set to
        # the date of the checkout (i.e., the date on which #the workflow was
        # executed), so in that case, use the most recent #commit date of each recipe
        # as its update date – you'll probably also want to #set the TZ environment
        # variable to your local timezone in the workflow #file (#21)
        if [[ "$GITHUB_ACTIONS" = true ]]; then
            UPDATED_AT="$(git log -1 --date=short-local --pretty='format:%cd' "$FILE")"
        else
            UPDATED_AT="$(date -r "$FILE" "+%Y-%m-%d")"
        fi
        # set basename to enable linking to github in the footer, and set
        # category_faux_urlencoded in order to link to that in the header
        pandoc "$FILE" \
            --metadata-file source/data/metadata.yml \
            --metadata basename="$(basename "$FILE" .md)" \
            --metadata category_faux_urlencoded="$CATEGORY_FAUX_URLENCODED" \
            --metadata updatedtime="$UPDATED_AT" \
            --template assets/templates/html.html \
            -o "$OUTPUT_DIRECTORY/$(basename "$FILE" .md).html"
    done

    #echo "Building category pages..."
    #for FILE in _temp/*.category.json; do
    #    x pandoc assets/empty.txt \
    #        --metadata-file config.yaml \
    #        --metadata title="dummy" \
    #        --metadata updatedtime="$(date "+%Y-%m-%d")" \
    #        --metadata-file "$FILE" \
    #        --template _templates/category.template.html \
    #        -o "_site/$(basename "$FILE" .category.json).#html"
    #done
    
    echo "Building the home page..."
    pandoc assets/empty.txt \
        --defaults assets/defaults/home.yml \
        --metadata updatedtime="$(date "+%Y-%m-%d")" \
        -o $OUTPUT_DIRECTORY/index.html

    echo "Assembling search index..."
    echo "[" > _temp/search.json
    SEPARATOR=""
    for FILE in _temp/*.metadata.json; do
        printf '%s' "$SEPARATOR" >> _temp/search.json
        cat "$FILE" >> _temp/search.json
        SEPARATOR=","
    done
    echo "]" >> _temp/search.json
    cp -r _temp/search.json $OUTPUT_DIRECTORY

    TIME_END=$(date +%s)
    TIME_TOTAL=$((TIME_END-TIME_START))
    echo "🚀 All done after $TIME_TOTAL seconds!"
}

pdf() {
    awk 'FNR==1 && NR!=1 {print "\n\n"}{print}' $CHAPTERS >> chapters.md;
    mkdir -p $OUTPUT_DIRECTORY;
    $PANDOC_COMMAND chapters.md $LATEX -o $pdf;
    rm chapters.md;
    echo "📖 The PDF edition is now available in $pdf";
}

latex() {
    awk 'FNR==1 && NR!=1 {print "\n\n"}{print}' $CHAPTERS >> chapters.md;
    mkdir -p $OUTPUT_DIRECTORY;
    $PANDOC_COMMAND chapters.md $LATEX -o $latex;
    rm chapters.md;
    echo "📖 The LaTeX edition is now available in $latex";
}

docx() {
    awk 'FNR==1 && NR!=1 {print "\n\n"}{print}' $CHAPTERS >> chapters.md;
    mkdir -p $OUTPUT_DIRECTORY;
    $PANDOC_COMMAND chapters.md $DOCX -o $docx;
    rm chapters.md;
    echo "📖 The DOCX edition is now available in $docx";
}

oai() {
    mkdir -p $OUTPUT_DIRECTORY;
    $PANDOC_COMMAND $OAI -o $oai;
    echo "🌐 The OAI-PMH record is now available in $oai"
}

textbook() {
    markdown
    epub
    html
    pdf
    latex
    docx
    oai
}

markdown() {
    CHAPTERS=$(find source/chapters -name '*.md')
    awk 'FNR==1 && NR!=1 {print "\n\n"}{print}' $CHAPTERS >> chapters.md;
    echo "📖 The Markdown file is now available in $markdown";
}

# If no arguments are specified in the $ sh lantern.sh command,
# then run the textbook function (which builds all formats)
if [ -z "$1" ]
then
    textbook
fi

"$@"
