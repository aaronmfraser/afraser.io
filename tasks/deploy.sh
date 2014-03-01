#!/usr/bin/env bash
jekyll build  && rsync -avz --delete _site/ afraser:/var/www/afraser.io/ && ssh afraser chown -R www-data:www-data /var/www/afraser.io
