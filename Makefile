APPID=$(notdir $(PWD))
SOURCE=$(wildcard src/*.erl)
EBIN=ebin

TARGETS = $(SOURCE:%.erl=$(EBIN)/%.beam)

all:	node

node:	compile generate

compile:
	rebar compile

generate:
	rebar generate

console:	node
	rel/$(APPID)/bin/$(APPID) console

clean:
	rm -rf $(EBIN)/*
	rm -rf rel/$(APPID)

start:
	rel/$(APPID)/bin/$(APPID) $@

stop:
	rel/$(APPID)/bin/$(APPID) $@

attach:
	rel/$(APPID)/bin/$(APPID) $@
