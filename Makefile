all: lua/fennel-repl.lua

clean:
	rm -f lua/fennel-repl.lua

lua/%.lua: fnl/%.fnl
	fennel --compile $< > $@

.PHONY: all clean
