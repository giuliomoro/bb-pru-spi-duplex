#!/bin/bash

echo "Master pins: (should be 25 26 26 26)"
grep -E "9a4" $PINS
grep -E "83c" $PINS
grep -E "834" $PINS
grep -E "830" $PINS

echo "Slave pins: (should be 26 25 26 26)"
grep -E "8ac" $PINS
grep -E "8a8" $PINS
grep -E "8a0" $PINS
grep -E "8a4" $PINS
