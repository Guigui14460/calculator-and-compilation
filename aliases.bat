@echo off
SET CLASSPATH=.;lib\antlr.jar;%CLASSPATH%
DOSKEY antlr=java org.antlr.v4.Tool $*
DOSKEY antlr-compile=javac *.java
DOSKEY grun=java org.antlr.v4.gui.TestRig $*
DOSKEY antlr4-grun=java org.antlr.v4.runtime.misc.TestRig $*
DOSKEY mvap-jar="java org.antlr.v4.Tool MVaP.g4 && javac MVaPAssembler.java CBaP.java && jar cfm MVaP.jar META-INF\MANIFEST.MF *.class"
DOSKEY mvap-compile=java -cp ".;lib/antlr.jar;lib/MVaP.jar" MVaPAssembler $*
DOSKEY mvap-run=java -jar lib/MVaP.jar $*
DOSKEY mvap-debug=java -jar lib/MVaP.jar -d $*

DOSKEY antlr-all=java org.antlr.v4.Tool Calculette.g4 ^&^& echo OK ^&^& javac *.java ^&^& echo OK ^&^& java MainCalculette
DOSKEY mvap-all-run=java -cp ".;lib/antlr.jar;lib/MVaP.jar" MVaPAssembler test.mvap ^&^& echo OK ^&^& java -jar lib/MVaP.jar test.mvap.cbap
DOSKEY mvap-all-debug=java -cp ".;lib/antlr.jar;lib/MVaP.jar" MVaPAssembler test.mvap ^&^& echo OK ^&^& java -jar lib/MVaP.jar -d test.mvap.cbap

DOSKEY export-package=if exist archive (rmdir /S /Q archive) ^&^& mkdir archive ^&^& xcopy Calculette.g4 archive ^&^& xcopy AdresseType.java archive ^&^& xcopy CalculetteUtils.java archive ^&^& xcopy TablesSymboles.java archive ^&^& xcopy TableSymboles.java archive ^&^& xcopy MainCalculette.java archive ^&^& xcopy ReadMe.txt archive ^&^& xcopy Who.txt archive ^&^& xcopy aliases.bat archive
@echo on