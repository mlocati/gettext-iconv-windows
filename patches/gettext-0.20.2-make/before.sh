#!/bin/bash

# Reduce dependency on libwinpthread

sed -Ei 's/(#define HAVE_CLOCK_GETTIME 1|\/\* #undef HAVE_CLOCK_GETTIME \*\/)/#define HAVE_CLOCK_GETTIME 0/g' gettext-tools/config.h
