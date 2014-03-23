Pokémaker
=========

Pokémon maker is a Sinatra-based web app to make Pokémon creatures.

To run at port 80, run:

```
bundle install
make
```

Starting Up
===========

You will need to do this to get things going:

 * Change the INITIAL_ADMIN_USER  and INITIAL_ADMIN_PASSWORD in pokemaker.rb (they default to "admin" and "pokemaker" respectively)
 * With this, you will need to hit once the `/system/initialize` url to get the database initialized. Login should be possible after this
 * You need to find the ID that the console is using from the logs initially and change INITIAL_USER_ID in pokemaker.rb
 * Point the DNS server of your console to a server that sends the console accesses to this app. It will be required to run on port 80
 * You need to add PKM files to the pkm/ of the monsters you want to be able to create before starting, otherwise they will need to be uploaded one by one from the app

Issues
======

This app was found somewhere in GitHub, abandoned for 2+ years and I ported some of it to modern Ruby/Sinatra. It had a bunch of functionality working, but some things had some surprisingly basic bugs. It feels like it was abandoned while almost being developed.

The app itself is *not* working well, however the basics of sending a pokemon to *one* console works after the app is initialized properly.

To do:

 * Support for multiple consoles not just one (this is somewhat in there with the notion of Users/Trainers, but it's somewhat confused)
 * Support for friend codes
 * Proper initialization and "admin" management (should be done automatically)
 * There is some confusion about what is a Trainer (in the game?) and what is a User (in the app?) and what their relationship should be
 * Some of the CSS and JS was old and needs some love. Some of it maybe almost there but not quite
 * This app is only for Pearl/Diamond, I think, not for the more modern ones like white, black, X, Y, ..
 * The user system is not really secure. The passwords are stored in plaintext and there is no way to change or recover them from the app
 * Automatic addition of new PKM files in bulk

Credits
========

This app was found somewhere in GitHub abandoned. Thank you, original person who wrote it.

Pokémon is trademark of various companies. This software comes bundled with data covered under fair-use for fan reference and only for personal use, under the GPL v3 license (see LICENSE file). This software is provided AS IS. Use at your own risk.
