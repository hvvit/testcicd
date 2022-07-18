#!/bin/bash

for i in {1..1360}
do
curl --location --request POST 'http://192.168.49.2:30007/thumbnail' --form 'file=@"./src/test/images/good_image_400x400.png"' 
done
