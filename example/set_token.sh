#!/bin/sh
# replace `pk.YOUR_ACCESS_TOKEN`` with contents of ./accesstoken in ./ios/BasicApp/Info.plist files ./android/app/src/main/AndroidManifest.xml
# implement a shell script that will replace the token in the files
# if argument restore is passed then it'll restore so it can be commited to git


TOKEN=$(cat ./accesstoken)

FILES=(ios/BasicApp/Info.plist android/app/src/main/AndroidManifest.xml)

for FILE in ${FILES[@]}; do
  echo $FILE
  if [ "$1" = "remove" ]; then
    sed -i '' -e "s/$TOKEN/pk.YOUR_ACCESS_TOKEN/g" "$FILE"
  else
    sed -i '' -e "s/pk.YOUR_ACCESS_TOKEN/$TOKEN/g" "$FILE"
  fi
done



