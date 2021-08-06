#!/usr/bin/sh

# textbook content settings
OUTPUT_FILENAME=textbook
OUTPUT_DIRECTORY=public

# ignore lines 4-5 from original makefile
#IMAGES=$(find source/images -type f)
CHAPTERS=$(find source/chapters -name '*.md')

# output configuration files
HOME='--defaults assets/defaults/home.yml'
HTML='--filter pandoc-crossref --defaults assets/defaults/html.yml --mathjax'
DOCX='--defaults assets/defaults/docx.yml'
LATEX='--filter pandoc-crossref --defaults assets/defaults/latex.yml --no-highlight'
EPUB='--defaults assets/defaults/epub.yml --mathml'
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

clean() {
    rm -r $OUTPUT_DIRECTORY;
    echo "🗑️ Let's start over.";
}

epub() {
    mkdir -p $OUTPUT_DIRECTORY;
    awk 'FNR==1 && NR!=1 {print "\n\n"}{print}' $CHAPTERS > source/chapters/chapters.md
    sed -i 's/]\(images/]\(static\/images/' source/chapters/chapters.md
    $PANDOC_COMMAND source/chapters/chapters.md $EPUB -o $epub;
    rm public/chapters.md;
    echo "📖 The EPUB edition is now available in $epub";
}

html() {
    awk 'FNR==1 && NR!=1 {print "\n\n"}{print}' $CHAPTERS >> chapters.md;
    mkdir -p $OUTPUT_DIRECTORY;
    $PANDOC_COMMAND assets/empty.txt $HOME -o public/index.html;
    $PANDOC_COMMAND chapters.md $HTML -o public/textbook.html;
    cp -r source/static/* $OUTPUT_DIRECTORY;
    cp -r assets/lib $OUTPUT_DIRECTORY;
    cp -r assets/styles/ $OUTPUT_DIRECTORY;
    rm chapters.md;
    echo "🌐 The HTML edition is now available in public/index.html";
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
    #epub
    pdf
    latex
    docx
    oai
    html
}

# If no arguments are specified in the $ sh lantern.sh command,
# then run the textbook function (which builds all formats)
if [ -z "$1" ]
then
    textbook
fi

"$@"