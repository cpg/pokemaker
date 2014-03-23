
# run the server
thin:
	sudo bundle exec thin -p 80 start

# run the console
tux:
	bundle exec tux -c config.ru
