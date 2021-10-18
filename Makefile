all: lua/fennel-repl.lua

clean:
	rm -f lua/*.lua

lua/%.lua: fnl/%.fnl
	fennel --compile $< > $@

.PHONY: all clean
