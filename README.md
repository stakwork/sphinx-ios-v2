# sphinx-ios-v2

# Setup

## Github Large Files

- This repository uses git large files. Run the following commands to get the full large files:

```
brew install git-lfs
git lfs install
git lfs pull
```

## CocoaPods

- This repository uses CocoaPods submodules. After cloning run:

```
pod install
```

## Info.plist Configuration

- Set a valid `GIPHY_API_KEY` value for the Giphy library.
- Set a valid `PODCAST_INDEX_API_KEY` value for the [Podcast Index API](https://podcastindex-org.github.io/docs-api/#overview).

## Branch

This repository uses ```develop``` branch as base branch for development. Master is not up to date.

