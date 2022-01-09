# utility
## Utility functions to facilitate day-to-day jobs on the command line
### Preliminaries
Put ```utility.sh``` file into a location of your choice, e.g. into```~/Documents/utility/```folder.
Then add this line to your```~/.bashrc```file:
```commandline
source ~/Documents/utility/utility.sh
```
### CONTENT
1. _extract_

Extract any archive file to the current folder. 
### Usage
Navigate to the desired folder (or alternatively specify the full path) containing the archive file - thunderbird in this example - and execute the following command:
```commandline
extract thunderbird-91.3.0.tar.bz2
```