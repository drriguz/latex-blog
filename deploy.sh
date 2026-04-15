#!/bin/sh
# Deploy latex-blog static site to remote server
set -e

REMOTE_USER=riguz
REMOTE_HOST=typedefai.com
REMOTE_PORT=54194
REMOTE_DIR=/var/www/blog
LOCAL_DIR=output/

rsync -avz --delete -e "ssh -p $REMOTE_PORT" "$LOCAL_DIR" "$REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR/"
echo "Deployed to $REMOTE_USER@$REMOTE_HOST:$REMOTE_DIR"
