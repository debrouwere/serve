all:
	coffee --compile --output lib src

update:
	wget https://raw.githubusercontent.com/livereload/livereload-js/master/dist/livereload.js \
		-O vendor/livereload.js