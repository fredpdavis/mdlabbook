# mdlabbook is a markdown-format lab notebook

Author: [Fred P. Davis](http://fredpdavis.com),
[NIH/NIAMS](http://www.niams.nih.gov/)

## Summary

mdlabbook helps maintain a lab notebook in the text-based markdown format
that you can edit in any text editor, link to images or other files, and 
automatically converts to webpages you can view in a web browser and
a PDF file for printing.


## Features

- Write notebook entries in a simple text format called
[pandoc ](http://pandoc.org/README.html#pandocs-markdown)
[markdown](https://daringfireball.net/projects/markdown/)
- Compatible with any text editor
- Write equations with LaTeX syntax

- Creates webpages for viewing in a web browser
- Creates PDF for archiving
- Simple file layout compatible with any backup/sharing system.
- Searchable with standard tools like grep or Mac OS's Spotlight.


## Installation

1. Download mdlabbook from
[this link](https://github.com/fredpdavis/mdlabbook/archive/master.zip) or
using git: `git clone https://github.com/fredpdavis/mdlabbook.git`

2. Add an alias to your shell rc file so you can call the program easily
   from anywhere

    - You probably use the bash shell. if so, add this line to (or create)
      the `~/.bashrc` file and then run `source ~/.bashrc`:
        `alias mdlabbook='perl /FULLPATH/TO/THE/MDLABBOOK/src/mdlabbook.pl'`

    - If you use cshrc, add this line to (or create) the ~/.cshrc file and
      then run `source ~/.cshrc`:
        `alias mdlabbook perl /FULLPATH/TO/THE/MDLABBOOK/src/mdlabbook.pl`

2. Install [pandoc](http://pandoc.org). After installing pandoc, also follow
   their instructions to install LaTeX, as you'll need it to create PDFs.

3. Optional: Install [vim](http://vim.org) if you don't already have it -- vim
   is the default editor, though you can specify another editor in the config
   file (see below) if you prefer.

## Getting Started

1. Make a config file describing your notebook options -- start with the example
   file provided (example_mdlabbook.config) or copy these lines into a new file:

        # notebook directory
        -dir ~/labbook
        
        # preferred editor (default is vim)
        -editor vim
        
        # author name
        -author "Fred P. Davis, NIH/NIAMS"
        
        # notebook title
        -title "Lab Notebook"

2. Type `mdlabbook -c CONFIGFILE`, replacing CONFIGFILE with the location of
your config file, to open today's entry with vim. Write your notes in
[pandoc markdown syntax](http://pandoc.org/README.html#pandocs-markdown).
Here's a short example:

        ---
        title: lab notebook
        author: Fred P. Davis
        date: March 28, 2016
        ---
        
        # Today's agenda
        
        1. prep mdlabbook for release
        2. a little bit of this
        3. a little bit of that
        
        # mdlabbook

        ![Embed an image](files/my_favorite_image.pdf)
        
        ## coding
        
        - combined all to single perl script
        - added interface to config file option
        - [Pandoc](http://pandoc.org) understands LaTeX! $e = mc^2$
        - [Pandoc](http://pandoc.org) also understands formatted table
        
        Project      Date     Status
        ---------    ------   -------------
        project1     2015     completed
        project2     2016     in progress

3. When you exit the vim session, an html version of the notebook will be
generated. Open the index.html file in your notebook directory to view a
calendar linked to notebook entries.

4. To generate a PDF version: `mdlabbook -c CONFIGFILE -p` will create
wholelabbook.pdf in your notebook directory.


## Detailed usage

    USAGE: mdlabbook [OPTIONS] -c CONFIGFILE
    
    -c CONFIGFILE   ONLY REQUIRED OPTION: see example_mdlabbook.config
    
    -h              describe usage
    -e YEARMODA     open/create a specific entry, eg, 20160322 for March 22, 2016
                    - if -e not specified, will open today's entry
    -w              convert to webpages (automatically runs after editing an entry)
    -p              convert to PDF
    -f FILE1 FILE2... moves files to files directory of today's notebook
    -n              don't add prefix to filename before moving (default: date)
    
    -s PDF          crops 2-page PDF scans into individual page PNG files
                    - requires imagemagick
                    - defaults work for 300dpi 8.5x11 2-page scan of 5.5x8 green NIH
                      notebooks (Federal Supply Service, GPO 7530-00-286-6207)
    -b PAGENUM      first physical page number in the PDF scan (default: 1)
    -l cropspec     left page cropping spec (default: 1600x2350+250+0)
    -r cropspec     right page cropping spec (default: 1600x2350+1750+0)
    -o out_prefix   Prefix for cropped PNG file names (default "nb_p")
    -x CROPSPECFILE file listing cropping specs for individual pages, listed by
                    physical page number, eg: "1 1600x2350+250+0"

## Miscellaneous Details

- Notebook entries are stored one file per day in the following layout:
`notebookdirectory/year/yearmonth/yearmonthday.md`

- Stores images or other files by month:
`notebookdirectory/year/yearmonth/files`

- bash alias to search the notebook (change NOTEBOOKDIRECTORY to the actual directory path):

        function nbgrep() { grep "$@" NOTEBOOKDIRECTORY/20*/*/*md;}

- csh alias to search the notebook (change NOTEBOOKDIRECTORY to the actual directory path):

        alias nbgrep 'grep \!:* NOTEBOOKDIRECTORY/20*/*/*md'

- Add these lines to your ~/.vimrc file (changing NOTEBOOKPATH to the full path
of your notebook directory) to get a shortcut for opening notebook entries:

        " Add command :NBopen yearmonthdate (eg, 20160328) to open an entry
        
        function! NBopen(nbtarget)
           let t_nbyear=strpart(a:nbtarget, 0, 4)
           let t_nbmonth=strpart(a:nbtarget, 0, 6)
           let t_nbfile=a:nbtarget.".md"
           let target_path="NOTEBOOKPATH/".t_nbyear."/".t_nbmonth."/".t_nbfile
           exec "sp ".target_path
        endfunction
        command! -nargs=1 NBopen call NBopen(<f-args>)

        " If cursor is over a yearmonthdate string in your file, F1 will open it
        map <F1> :NBopen <C-R><C-W><CR>
