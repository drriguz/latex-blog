.PHONY: build serve clean new

build:
	cargo run -- build


serve:
	cargo run -- serve --port 9527

clean:
	cargo run -- clean

new:
	@read -p "Post title: " title; \
	cargo run -- new "$$title"

dev: build serve
