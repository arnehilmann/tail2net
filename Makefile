APPID=$(notdir $(PWD))
SOURCE=$(wildcard src/*.erl)
EBIN=ebin

TARGETS = $(SOURCE:%.erl=$(EBIN)/%.beam)

all:	node

node:	compile generate

compile:
	rebar compile

generate:	dialyze
	rebar generate

dialyze:
	dialyzer --add_to_plt -r $(EBIN) --fullpath --output_plt $(APPID).plt

console:	node
	rel/$(APPID)/bin/$(APPID) console

clean:
	rm -rf $(EBIN)/*
	rm -rf rel/$(APPID)
	rm -rf *.plt
	rm -rf *.dump

start:
	rel/$(APPID)/bin/$(APPID) $@

stop:
	rel/$(APPID)/bin/$(APPID) $@

attach:
	rel/$(APPID)/bin/$(APPID) $@

