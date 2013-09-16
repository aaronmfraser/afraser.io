---
layout: post
title: "Nagios behind Nginx"
date: 2012-08-05 05:07
comments: false
categories: [monitoring,nginx] 
---

Recently changed jobs, Diseny Interactive, and their default web server is Nginx. So to better support nginx I decided to migrate all of the services that I play with to work behind it and today was Nagios's turn. I followed a few other blogs help in getting the configs straighted out but below is another rendition of this exercise.

<!-- more -->

SPECS:
System: Amazon AMI   
Server: Nginx 1.0.15   
Nagios: 3.3.1   


### Install nagios & plugins:
First lets install the packages needed:
```
yum install nagios nagios-plugins-all
```
Before we start services we need to head over to change the ownership of a few files. These files are important for nginx to access on startup:
```
	chown root:nginx /etc/passwd
	chown root:nginx /usr/share/nagios/html/config.inc.php
```
Also we need to add nginx to nagios group. This is necessary for nginx to be able to access certain files for FastCGI:
```
	nagios:x:497:nginx
```
We can now go ahead and start services as we wont be changing any of the nagios configs from here on out:
```
	# service nagios start
	Starting nagios: done.

	# chkconfig --level 3 nagios on
```
### Configure FastCGI and PHP scripts/services
To start you have it install epel. Many of the required packages arent provided with Amazons version of epel
```
	wget http://mirror.steadfast.net/epel/6/i386/epel-release-6-7.noarch.rpm
	rpm -Uvh epel-release-6-7.noarch.rpm

	yum install fcgi spawn-fcgi fcgi-devel
```
##### Install fcgiwrap
We will need to install fcgiwrap. It is a Simple server for running CGI applications over FastCGI (http://nginx.localdomain.pl/wiki/FcgiWrap). Below are the steps to install fcgiwrap:
```
	cd /tmp
	git clone git://github.com/gnosek/fcgiwrap.git
	cd fcgiwrap/
	autoreconf -i
	make
	make install
```
##### Configure spawn-fcgi
Once fcgiwrap is installed, what we want to do is enable FastCGI and enable us to pass requests.
To begin lets set up spawn-fcgi config located, /etc/sysconfig/spawn-fcgi:
```	
OPTIONS="-u nginx -g nginx -a 127.0.0.1 -p 9001 -f /usr/local/sbin/fcgiwrap -P /var/run/spawn-fcgi.pid"
```
##### Configure spawn-fcgi-php
Next lets set up spawn-fcgi-php config located, /etc/sysconfig/spawn-fcgi-php:
```
	cp /etc/sysconfig/spawn-fcgi /etc/sysconfig/spawn-fcgi-php
```	
Add the following line to the newly created file:
```
	OPTIONS="-u nginx -g nginx -a 127.0.0.1 -p 9002 -f /usr/bin/php-cgi -P /var/run/spawn-fcgi-php.pid"
```
### Install & Configure nginx
First we will need to install nginx.
```
	yum install nginx
```
Next lets configure the VirtualHost
```
	server {
	    server_name  <servername>;
    
	    location / {
	        auth_basic "Access to the web interface is restricted";
	        auth_basic_user_file /etc/nagios/passwd;
		index index.php;
	        rewrite ^/nagios/(.*) /$1 break;

	        root /usr/share/nagios/html;
	        fastcgi_index  index.php;
	        include /etc/nginx/fastcgi_params;
		fastcgi_param SCRIPT_FILENAME /usr/share/nagios/html$fastcgi_script_name;
	        if ($uri ~ "\.php"){
		   fastcgi_pass   127.0.0.1:9002;
	        }
	    }

	    location ~ ^/nagios/cgi-bin/ {
		root /usr/lib64/;        
		include /etc/nginx/fastcgi_params;
	        auth_basic "Restricted";
	        auth_basic_user_file /etc/nagios/passwd;
	        fastcgi_param  AUTH_USER $remote_user;
	        fastcgi_param  REMOTE_USER $remote_user;
		fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
	        if ($uri ~ "\.cgi$"){
	            fastcgi_pass   127.0.0.1:9001;
	        }
	    }
	}
```
