#!/bin/bash 
echo "chmodding files"
find ./* -type f -exec chmod -R 664 {} \;
echo "chmodding directories"
find ./* -type d -exec chmod -R 755 {} \;
echo "completed"
