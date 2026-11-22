# Git Tag Cheatsheet

## List tags
git tag

## Create tag
git tag v1.0.0

## Create tag with message
git tag -a v1.0.0 -m "Release v1.0.0"

## Push tag to remote
git push origin v1.0.0

## Push all tags
git push origin --tags

## Delete tag local
git tag -d v1.0.0

## Delete tag remote
git push origin --delete v1.0.0

## Show tag info
git show v1.0.0