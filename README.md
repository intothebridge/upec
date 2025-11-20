# UPEC - Ultra Primitive EIT Converter

upec is a bash script which iterates through a (large) movie collection and DVB-recordings and generates NFO-files either based on found EIT-sidecar files or based on filename and directory.

## Features

* upec uses the current directory as genre-indicator. The directory name is used as "genre" but can be overwritten with the contents of "upecgenre.txt" placed in the same directory
* if there is no EIT-file upec uses the filename for the metadata and derives the genre (see above)
* upec works unattended and recursive and scans also large collections very efficient
* the NFO-files can be used by emby, jellyfin, kodi als metadata to build a personalized structure
* upec also generates json-files containing the extracted/constructed metadata
* upec generates a CSV (one line per movie) with all the metadata and filenames

## prerequisites

* a linux distro
* bash
* and the eit-parser: https://github.com/intothebridge/parse_eit in the working directory (easy task)

Have fun!
gearginner

  
