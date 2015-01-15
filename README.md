# bib2bibframe-converter #

## Overview ##

Commandline tool to convert Cornell bibliographic IDs to Bibframe RDF.

**Script name**: bib2bibframe.rb  
**Input**: a comma-delimited list of bib record ids   
**Output**: MARCXML and Bibframe RDF files

The MARCXML is retrieved from the Cornell Library database. The Bibframe RDF is
generated using the LC Bibframe converter.


## Configuration settings ##

To configure the script, copy conf.example.yml to conf.yml. Specify the 
following configuration settings. All settings are optional, and can be 
overridden by commandline arguments. Some settings (see below) also define 
default values in the application if they are specified neither in the config 
file nor on the commandline.

- **baseuri:** Namespace the Bibframe converter will use to mint URIs.

- **catalog:** Catalog URL for lookups. The catalog is assumed to support use of 
the .marcxml extension to request marcxml. A future update will include 
marc2marcxml conversion if the catalog doesn't support this.

- **format:** Specifies rdf serialization format. Defaults to rdfxml. Possible
values are determined by Bibframe converter. A future update will include an
option for turtle output.   
    - *rdfxml*: (default) flattened RDF/XML, everything has an identifier  
    - *rdfxml-raw*: verbose, cascaded output  
    - *ntriples*  
    - *json*  

- **datadir:** Directory to which MARCXML and Bibframe files will be written. 
The application will create this directory if it doesn't already exist. Each 
time the script runs, it will use the current datetime to create a subdirectory 
of the data directory, with further subdirectories marcxml and bibframe to store 
the xml and rdf output files, respectively. The bibframe directory is further
partitioned by format.

- **logdir:** Directory to which runtime logs are written. 


## Runtime arguments ##

Bib ids must be specified on the commandline. All other arguments are optional,
and can be specified in the config file rather than the commandline. See above
for descriptions of these arguments.

**--ids:** Comma-delimited list of Cornell bib ids **or** 'file:' followed by 
the relative path to a newline-delimited file of bib ids.

See the corresponding config file options for description of the following:

**--baseuri**   
**--catalog**     
**--format**     
**--datadir**     
**--logdir**     

## Default values ##

The ids, baseuri and catalog arguments have no programmatic default values. The 
other arguments have the following defaults:

**format:** rdfxml  
**datadir:** ./data  
**logdir:** ./log  

*Warning:* there is currently no error-checking for missing required values or
the format and content of any specified values.


## Sample commands ##
$ ./bib2bibframe.rb --ids=102063,1413966,152071 
$ ./bib2bibframe.rb --ids=file:/usr/local/bibids.txt  
$ ./bib2bibframe.rb --baseuri=http://example.com --format=json --ids=102063,1413966,152071



