#!/bin/bash
rm _community_archive/*
rm -rf img/derivatives
rm -rf _community_archive/*
cp ../community_archive.csv _data/
bundle exec rake wax:derivatives:iiif community_archive
bundle exec rake wax:pages community_archive
bundle exec rake wax:search community_archive
