#!/bin/bash

if [ -z "$DAYS_UNTIL_DELETE" ]
then
  DAYS_UNTIL_DELETE=7
fi

if [ -z "$DO_REGISTRY_NAME" ]
then
  DO_REGISTRY_NAME="gang-registry"
fi

# Get all images that are currently using by some pods
RESULT=$(
  kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec.containers[*].image}" |\
    tr -s '[[:space:]]' '\n' |\
    sort |\
    uniq   
)
IMAGES=()
for image in $RESULT
do 
  IMAGE_WITH_VER=`echo $image | sed "s/.*$DO_REGISTRY_NAME\///"`
  IMAGES+=($IMAGE_WITH_VER)
done

function allowed_version() {
    rx='^([0-9]+\.){0,2}(\*|[0-9]+)$'
    if [[ $1 =~ $rx ]];
    then
      return 1
    fi 

    if [[ $1 == "latest" ]]
    then
      return 1
    fi

    return 0
}


function check_image_in_use() {
  local i
  local IMAGE_NAME
  for i in "${IMAGES[@]}"
  do
    IMAGE_NAME=`echo $i | sed 's/:.*//'`
    IMAGE_VERSION=`echo $i | sed 's/.*://'`
    if [[ "$IMAGE_NAME" = "$1" ]] && [[ "$IMAGE_VERSION" = "$2" ]]
    then
      return 1
    fi
  done
  return 0
}

function list_tags() {
  IMAGE_NAME=$1
  TAGS=$(doctl registry repository list-tags -t $DO_ACCESS_TOKEN $IMAGE_NAME)
  i=0
  DAYS_AGO=$(date -d "@$(( $(busybox date +%s) - 86400 * $DAYS_UNTIL_DELETE ))" +%s)
  while read -r line; do
    if [ $i -ne 0 ]
    then
      THE_DATE=`echo $line | awk '{print $4}'`
      DATE_TO_CHECK=$(date -d $THE_DATE +%s)
      if [[ "$DATE_TO_CHECK" < "$DAYS_AGO" ]]
      then
        TAG_ID=`echo $line | awk '{print $1}'`
        allowed_version $TAG_ID
        if [[ $? == 0 ]];
        then
          check_image_in_use "$IMAGE_NAME" "$TAG_ID"
          if [[ $? == 0 ]];
          then
            echo "Deleting: $IMAGE_NAME:$TAG_ID"
            doctl registry repository delete-tag -t $DO_ACCESS_TOKEN -f $IMAGE_NAME $TAG_ID
          fi
        fi
      fi
    fi
    let "i+=1"
  done <<< "$TAGS"
}

REPOSITORIES=$(doctl registry repository -t $DO_ACCESS_TOKEN list)
i=0
while read -r line; do
  if [ $i -ne 0 ]
  then
    TAG_NAME=`echo $line | awk '{print $1}'`
    list_tags $TAG_NAME
  fi
  let "i+=1"
done <<< "$REPOSITORIES"

# Clean up using garbage collection
doctl registry garbage-collection start -t $DO_ACCESS_TOKEN -f $DO_REGISTRY_NAME