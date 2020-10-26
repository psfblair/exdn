all: deps app protocols

get-deps:
	rm -f mix.lock
	mix deps.get

deps: get-deps
	mix deps.compile

app:
	mix compile

protocols:
	mix compile.protocols

clean-deps:
	mix deps.clean --all
	rm -rf deps

clean: clean-deps
	mix clean

test: app
	mix test

docs:
	mix docs

lint: format
	mix credo --strict

format:
	mix format

outdated:
	mix hex.outdated

publish:
	mix hex.publish
	mix hex.publish docs