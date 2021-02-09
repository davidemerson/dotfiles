#!/bin/bash

ADJ=$(shuf -n 1 adjectives.txt)
NOUN=$(shuf -n 1 nouns.txt)
AML=$(shuf -n 1 animals.txt)

echo "$ADJ $AML $NOUN"
