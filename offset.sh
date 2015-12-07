#!/bin/bash

echo $(readelf -s $1 | awk -F" " "\$8==\"$2\" {printf(\"#define $3 0x%s\n\", \$2)}")
