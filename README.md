# bib2bibframe #

## Overview ##

Tool to convert Cornell bibliographic IDs to Bibframe RDF.

Input: a comma- or newline delimited list of Cornell bib ids
Output: MARCXML and Bibframe 

The MARCXML is retrieved from the Cornell Library database. The Bibframe RDF is
generated using the LC Bibframe converter.


## Configuration ##

To configure the script, copy example_conf.yml to conf.yml. Specify the 
following:

- datadir: Directory to which MARCXML and Bibframe files are written. The
application will create this directory if it doesn't already exist. Each time 
the script runs, it will use the current datetime to create a subdirectory of 
the data directory, with further subdirectories marcxml and bibframe to store 
the xml and rdf output files, respectively.

- logdir: Directory to which runtime logs are written.

- saxon: Absolute, local path to Saxon engine.

- xquery: Absolute, local path to XQuery.

- baseuri: Namespace the Bibframe converter will use to mint URIs. This value
can be overwritten by an option passed to the script.


## Runtime options ##

--baseuri - optional. Overrides configuration file setting.

--format - optional. Specifies output format. Defaults to rdfxml.
Values supported by Bibframe converter:
- rdfxml: (default) flattened RDF/XML, everything has an identifier
- rdfxml-raw: verbose, cascaded output
- ntriples
- json
- exhibitJSON

--ids - required. Comma- or newline-delimited list of Cornell bib ids.


Example commands:
$ ./bib2bibframe.rb --baseuri=http://example.com --format=json ids=102063,1413966,152071



