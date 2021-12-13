#!/usr/bin/env bash

FIND_ARM_STR='"architecture": "arm'
FIND_AMD_STR='"architecture": "amd'

INPUT_FILE=$1

function is_multi_arch_img() {
  img=$1
  manifest=$(docker manifest inspect --verbose ${img})

  local valid=1

  echo ${manifest} | grep "${FIND_ARM_STR}" >> /dev/null
  if [ $? -ne 0  ]; then
    echo "${img} less arm"
    valid=0
  fi

  echo ${manifest} | grep "${FIND_AMD_STR}" >> /dev/null
  if [ $? -ne 0  ]; then
    echo "${img} less amd"
    valid=0
  fi

#  if [ ${valid} -eq 1 ]; then
#    echo "${img} yes"
#  fi
}

echo "validating images in ${INPUT_FILE}"

for image in $(cat ${INPUT_FILE})
do
  is_multi_arch_img ${image}
done