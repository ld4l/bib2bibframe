# bib2bibframe-converter #

## Overview ##

Commandline tool to convert Cornell bibliographic IDs to Bibframe RDF.

**Script name**: bib2bibframe.rb  
**Input**: a comma-delimited list of bib record ids   
**Output**: MARCXML and Bibframe RDF files

The MARCXML is retrieved from the Cornell Library database. The Bibframe RDF is
generated using the LC Bibframe converter.


## Configuration ##

To configure the script, copy conf.example.yml to conf.yml. Specify the 
following:

- **baseuri** *(optional: can be specified on commandline)*: Namespace the 
Bibframe converter will use to mint URIs; can be overwritten by a runtime
option.

- **catalog** *(mandatory)*:  Catalog URL. The catalog is assumed to support use 
of the .marcxml extension to request marcxml. A future update will include 
marc2marcxml conversion if the catalog doesn't support this.

- **datadir** *(optional: defaults to ./data)*: Directory to which MARCXML and 
Bibframe files are written. The application will create this directory if it 
doesn't already exist. Each time the script runs, it will use the current 
datetime to create a subdirectory of the data directory, with further 
subdirectories marcxml and bibframe to store the xml and rdf output files, 
respectively. 

- **logdir** *(optional: defaults to ./log)*: Directory to which runtime logs 
are written. 


## Runtime options ##

**--ids** - required. Comma-delimited list of Cornell bib ids.

**--baseuri** - optional. Overrides configuration file setting.

**--format** - optional. Specifies output format. Defaults to rdfxml.
Values supported by Bibframe converter:
- *rdfxml*: (default) flattened RDF/XML, everything has an identifier
- *rdfxml-raw*: verbose, cascaded output
- *ntriples*
- *json*



### Example commands ###
$ ./bib2bibframe.rb --ids=102063,1413966,152071    
$ ./bib2bibframe.rb --baseuri=http://example.com --format=json --ids=102063,1413966,152071



