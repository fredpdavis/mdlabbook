# Finds all md files and pattern substitute to html output file
HTMLS := $(patsubst %.md,%.html,$(wildcard */*.md */*/2*.md))

# ALL rule makes all HTML files listed
all: index $(HTMLS)

# Generic rule to accept HTML target and corresponding MD source
%.html : %.md
	pandoc -s --mathjax -B index_header.html -S --toc -H css/buttondown_edit.css $< -o $@

clean :
	rm $(HTMLS)

index :
	perl SRCDIR/mdlabbook.pl -c CONFIGFILE -i > index.md
	pandoc -s -S --toc -H css/buttondown_edit.css index.md -o index.html
	echo "<small>" > index_header.html
	sed -n '/<table>/,$$p' < index.html | grep -v '</body>' | grep -v '</html>' | sed 's/href=\"/href=\"..\/..\//g' >> index_header.html

	echo "</small><p>" >> index_header.html

rebuild : clean all

.PHONY : index
