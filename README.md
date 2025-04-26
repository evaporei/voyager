# voyager

Cross platform mini file explorer. Although small, it is very fast (it is faster than `Finder`), it can **read and render +50k files** in a folder **over the network** (more about it below).

This program does the minimal amount of work and allocations needed to achieve its goals for `Windows`, `MacOS` and `Linux`.

You can see a demo for it below, for now it's not very pretty, I'll probably introduce better text rendering and fonts later.

![demo of program](demo.gif)

Features:

- [x] List dir files
- [x] Open file with default app
- [x] Navigate to other dirs
- [x] Start on specified folder (CLI arg)
- [ ] File stats (on hover)
- [ ] Delete files (right click)
- [ ] Rename files (one click + typing)
- [ ] File selection (shift)
- [ ] Move files (hard one)
- [ ] New file (empty though)
- [ ] Extra: keybindings

## Background

We recently have exposed a folder of our Raspberry Pi via [Samba](https://en.wikipedia.org/wiki/Samba_(software)) at home. Although we can read/write most folders via Finder, one of them simply freezes MacOS's software, because it has over +50k files. I was convinced there was a performant way to access these files over the network. After just one day of experimenting, `voyager`'s first version was born and it already could access that folder in a performant way, whereas Finder would simply load forever.
