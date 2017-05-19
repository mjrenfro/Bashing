#!/bin/bash

#Searches for a keyword (without spaces) in PDFs, common formatted text files (Microsoft productivity suite[after 2003] files and Open Office suite files), and simple text files
#Outputs results to Found.txt and non-searchable files to NotSearchable.txt


#Setup Instructions
#   install antiword : (sudo) apt-get install antiword
#Run Instructions
#   bash FindKeyword.sh <root_dir> <keyword>


#Resources
# http://stackoverflow.com/questions/18897264/bash-writing-a-script-to-recursively-travel-a-directory-of-n-levels
# http://stackoverflow.com/questions/91368/checking-from-shell-script-if-a-directory-contains-files


#"Classifier" functions
function IsZippedFile()
{
  unzip -p "$1" &>/dev/null
  if [ $? -eq 0 ]; then
      return 0
  else
      return 1
  fi

}
function IsPdfFile()
{
  filename="$1"
  extension="${filename##*.}"
  if [ "$extension" == "pdf" ]
    then
      return 0
    else
      return 1
  fi
}
function IsSimpleFile()
{
  isFile=$(file -0 "$1" | cut -d $'\0' -f2)
  case "$isFile" in
     (*text*)
        return 0
        ;;
     (*)
        return 1
        ;;
  esac
}

function IsArchivedDirectory () {
  if file -0 "$1" | grep "archive" &>/dev/null
  then
    return 0
  else
    return 1
  fi
}

function PrintFound()
{
  printf -v a "%s contains the keyword '%s'" "$1" "$2"
  echo $a >>"Found.txt"
}
function PrintNotFound()
{
  echo "$1" >> "NotSearchable.txt"
}
function SimpleSearch()
{
  if grep -q "$2" "$1"; then
    PrintFound "$1" "$2"
  fi
}

function ZippedFileSearch()
{

  unzip -p "$1" | grep "$2" >&/dev/null
  if [ $? -eq 0 ]; then
    PrintFound "$1" "$2"
  fi
}

function PdfFileSearch()
{
  pdftotext "$1" - | grep "$2" &>/dev/null

  if [ $? -eq 0 ]; then
      PrintFound "$1" "$2"
  fi
}
function OldDocSearch()
{
  antiword "$1" |  grep "$2" &>/dev/null

  if [ $? -eq 0 ]; then
      PrintFound "$1" "$2"

  fi

}
#CURRENTLY NOT WORKING
#found at: https://gist.github.com/rishid/6124223
# extract different archives automatically
function extract () {
  if [ -f $1 ] ; then
    case $1 in
      *.tar.bz2)   tar xvjf $1   ;;
      *.tar.gz)    tar xvzf $1   ;;
      *.bz2)       bunzip2 $1    ;;
      *.gz)        gunzip $1     ;;
      *.tar)       tar xf $1     ;;
      *.tbz2)      tar xjf $1    ;;
      *.tgz)       tar xzf $1    ;;
      *.zip)       unzip $1      ;;
      *.Z)         uncompress $1 ;;
      *.rar)       7z x $1       ;;
      *.7z)        7z x $1       ;;
      *)           echo "'$1' cannot be extracted via extract()" ;;
    esac
  else
    echo "'$1' is not a valid file"
  fi
}


#simple text (.txt, .rtf, etc) =0
#'complicated' text formats (zipped up files): open office, M$ suite =1
#pdf = 2
#archive =3
#unsupport file type =4
function GetFileType()
{
  IsSimpleFile "$1"
  res=$?
  if [ "$res" == 0 ]
  then
    return 0
  fi

  IsZippedFile "$1"
  res=$?
  if [ "$res" == 0 ]
  then
    return 1
  fi

  IsPdfFile "$1"
  res=$?
  if [ "$res" == 0 ]
  then
    return 2
  fi

  IsArchivedDirectory "$1"
  res=$?
  if [ "$res" == 0 ]
  then
    return 3
  fi

  return 4
}

function FindKeyword() {

  #Does the folder have contents?
  if  [[ $(ls -A "$1"/* 2>/dev/null) ]]
  then
    #Iterate through all of the items (regardless of type)
    for file in "$1"/*
    do
        #Is not a simple directory
        if [ ! -d "${file}" ] ; then

          #Determine type of file
          GetFileType "${file}"
          fileType=$?
          case "$fileType" in
            #Simple ASCII file
             0)
                SimpleSearch "${file}" "$2"
                ;;
            #Complicated text file: docx, ppt, odt...
             1)
                ZippedFileSearch "${file}" "$2"
                ;;
            #PDF
             2)
                PdfFileSearch "${file}" "$2"
                ;;
            #Archive: Not currently extracting correctly
             3)
                extract "${file}"
                extractedURI="${file%.*}"
                #perform recursion on extracted file
                FindKeyword "${extractedURI}" "$2"
                ;;
             *)
                #could be M$ word doc 2003 or earlier
                filename="${file}"
                extension="${filename##*.}"
                #docx files should be zipped, but seen some that are not
                if [ "$extension" == "doc" ] || [ "$extension" == "docx" ] ; then
                  OldDocSearch "${file}" "$2"
                else
                  PrintNotFound "${file}"
                fi
                ;;

          esac

        else
            #Recursive case
            FindKeyword "${file}" "$2"
        fi
    done
fi
}

#Root folder must be provided
if  [ "$#" -ne 2 ]
  then
    echo "Root directory name and search word must be given"; exit $ERRCODE;
fi

FindKeyword "$1" "$2"
