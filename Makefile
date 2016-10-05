# Paths to non-unix-standard tools that we depend on; can be overridden on the command line

CATMANDU=catmandu
MARC2BIBFRAME=../marc2bibframe
MARC2BIBFRAMEWRAPPER=../marc2bibframe-wrapper/target/marc2bibframe-wrapper-*.jar
RSPARQL=rsparql
UCONV=uconv

# Other configuration settings
FINTOSPARQL=http://api.dev.finto.fi/sparql
URIBASEFENNICA=http://urn.fi/URN:NBN:fi:bib:fennica:

# Pattern rules used internally

split-input/%.md5: input/%.alephseq
	awk '{ print $0 > "$(patsubst %.md5,%,$@)-"substr($$1,0,5)".alephseq" }' <$^
	cd split-input; md5sum $(patsubst split-input/%.md5,%,$@)-*.alephseq >`basename $@`

%.md5: %
	md5sum $^ >$@

slices/%.md5: split-input/%.md5
	scripts/update-slices.sh $^ $@

refdata/iso639-2-fi.csv: sparql/extract-iso639-2-fi.rq
	$(RSPARQL) --service $(FINTOSPARQL) --query $^ results=CSV >$@

%.mrcx: %.alephseq refdata/iso639-2-fi.csv
	uniq $< | sed -e 's/http:\\\\/http:\/\//' | scripts/filter-duplicates.py | $(UCONV) -x Any-NFC | grep -v -P ' CAT|LOW|SID ' | grep -v -F 'FENNI<DROP>' | grep -v -P '\d{9} 65[01](?!.*\$\$9FENNI<KEEP>)' | $(CATMANDU) convert MARC --type ALEPHSEQ to MARC --type XML --fix scripts/set-240-language.fix >$@

%-bf.rdf: %.mrcx
	java -jar $(MARC2BIBFRAMEWRAPPER) $(MARC2BIBFRAME) $^ $(URIBASEFENNICA) >$@ 2>$(patsubst %.rdf,%-log.xml,$@)

# Targets to be run externally

clean:
	rm -f split-input/*.alephseq split-input/*.md5
	rm -f slices/*.alephseq slices/*.md5
	rm -f slices/*.mrcx
	rm -f slices/*.rdf slices/*.xml

slice: $(patsubst input/%.alephseq,slices/%.md5,$(wildcard input/*.alephseq))

mrcx: $(patsubst %.alephseq,%.mrcx,$(wildcard slices/*.alephseq))

rdf: $(patsubst %.alephseq,%-bf.rdf,$(wildcard slices/*.alephseq))

.PHONY: clean slice mrcx rdf