#!/bin/bash

if ! pgrep -x "nginx" > /dev/null; then
    echo "Nginx is not running. Starting Nginx..."
    sudo systemctl start nginx  
else
    echo "Nginx is already running."
fi