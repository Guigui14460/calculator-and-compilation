# Calculator and compilation

University project proposed in the subject "Language theory and compilation" in 3rd year of Computer Science degree at the University of Caen Normandy in order to make us use the tools seen in class for language theory for automates and grammars and to see how works the compilation for others languages.

## Table of contents

  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Setup](#setup)
  - [Commands](#commands)
  - [Authors](#authors)
  - [License](#license)

## Introduction
The goal of the project is to build a small language that we can use to make a calculator. We can use some statement like if, else, for, while, or repeat until. We can also create and use functions and variables.

## Setup
All dependencies are in the `lib` folder.

If you are on Windows, you can launch this command in your terminal :
```shell
$ aliases.bat
```
If you are on POSIX, you can launch this command in your terminal :
```shell
$ aliases.sh
```

## Commands
- To launch the ANTLR and write some code :
```shell
$ antlr-all
```
- To run the generated code in our virtual stack machine :
```shell
$ mvap-all-run
```
- To debug it :
```shell
$ mvap-all-debug
```
- To launch the benchmarks, you need to use a Unix-like system and launch this command (at the root) :
```shell
$ test
```

## Authors
- [PIERRE Corentin](https://github.com/coco-ia)
- [LETELLIER Guillaume](https://github.com/Guigui14460)

## License
Project under the MIT license.