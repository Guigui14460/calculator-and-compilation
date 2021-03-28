#! /bin/sh

# prefixe (répertoire de travail)
PREF_COR="BMs"
# rep qui contient les benchs calculette.
CALC_FOLDER=calcs
# rep qui contient les traces attendues
WRITES_FOLDER=writes
# input for reads.
READS_FOLDER=reads

# mon chemin antlr
ANTLR_JAR="../antlr.jar"
# mon chemain MVàP
MVAP_JAR="../MVaP.jar"
# point d'entrée de la grammaire.
ENTRY=start

usage () {
	/bin/echo "$0 <fichier.g4> <fichiersPourVotre@members.java>"
	exit 1
}


# Check that folders exist
if [ ! -d $PREF_COR/$CALC_FOLDER ] || [ ! -d $PREF_COR/$WRITES_FOLDER ] || [ ! -d $PREF_COR/$READS_FOLDER ]
then
	/bin/echo "Erreur interne: dossiers $PREF_COR/$CALC_FOLDER ou $PREF_COR/$WRITES_FOLDER ou $PREF_COR/$READS_FOLDER manquant" 1>&2
	exit 2
fi


# Check number of argument
if [ $# -lt 1 ]
then
	usage
fi

# Check input g4
if [ ! -r $1 ]
then
	/bin/echo "$1 : fichier non trouvé" 1>&2
	exit 1
fi

filename=`basename $1`


if ! grep $ENTRY $1  >/dev/null 
then 
	/bin/echo -e "Pas de règle $ENTRY" 1>&2 
	exit 1
fi
       	


# Make a tmp dir and put the file here
tmpdir="Compil-"`date +%m-%d-%H:%M`
mkdir $tmpdir
cp $* $tmpdir
cd $tmpdir


# Compile g4

/bin/echo -e "\e[34mAntlr4 ...\e[39m"
if ! /usr/bin/java -cp "$ANTLR_JAR" org.antlr.v4.Tool "$filename" 
then	
	/bin/echo -e "\e[31mErreur antlr4\e[39m"
	exit 3 
fi

/bin/echo -e "\e[34mJavac\e[39m"
if ! javac -cp "$ANTLR_JAR" *.java 2> Compilation_java.log
then	
	/bin/echo -e "\e[31mErreur java\e[39m"
	cat Compilation_java.log | grep -v "Supported source version"
       	exit 3 
fi


# Tests
note=0

for i in `ls ../$PREF_COR/$CALC_FOLDER/*.code`
do
    t_name=`basename "$i" ".code"`
    /bin/echo -ne "\e[32m"
    printf "%14.14s" "${t_name%.code}"

    # Compilation code -> MvaP
    /bin/echo -ne "\e[34m\t compil\e[39m"

   if ! /usr/bin/java -cp "$ANTLR_JAR":. org.antlr.v4.gui.TestRig ${filename%.*} $ENTRY < "$i" > $t_name.mvap 2> $t_name.comp.log
    then
	/bin/echo -e "\e[31m Erreur\e[39m";
	continue;
    elif egrep "^line" $t_name.comp.log > /dev/null
    then
	/bin/echo -ne "\e[33m Bug"
    fi

    # Mvap -> Cbap
    /bin/echo -en "\e[34m \t assembl\e[39m"
    if ! /usr/bin/java -cp "$ANTLR_JAR":$MVAP_JAR MVaPAssembler $t_name.mvap 2>$t_name.ass.log
    then
	/bin/echo -e "\e[31m Erreur\e[39m";
	continue;
    elif [ -s $t_name.ass.log ]
    then
	/bin/echo -ne "\e[33m Bug"
    fi

    # Execution

    if ls ../$PREF_COR/$READS_FOLDER/$t_name.read* 2>/dev/null 1>/dev/null
    then
	#avec reads
	echo ""
	for input in `ls ../$PREF_COR/$READS_FOLDER/$t_name.read*`; do

	    printf "%40.40s" "${input##*.}"

	    /bin/echo -ne "\e[34m \t execution\e[39m"

	    if ! timeout 5 /usr/bin/java -jar $MVAP_JAR  $t_name.mvap.cbap < $input > $t_name.res.${input##*.} 2> $t_name.run.log.${input##*.}
	    then
		/bin/echo -e "\e[31m Erreur\e[39m";
		continue;
	    elif
		sed -i "/^HALT/d" $t_name.run.log.${input##*.};
		[ -s $t_name.run.log.${input##*.} ]
	    then
	        /bin/echo -ne "\e[33m Bug"
	    fi

	    # Check résultat
	    /bin/echo -en "\e[34m \t résultat\e[39m"
	    
	    if diff ../$PREF_COR/$WRITES_FOLDER/$t_name.res.${input##*.} $t_name.res.${input##*.} > /dev/null 2> /dev/null
	    then
		if [ -s $t_name.ass.log ] || ( sed -i "/^HALT/d" $t_name.run.log 2> /dev/null; [ -s $t_name.run.log ] ) ||	egrep "^line" $t_name.comp.log > /dev/null
		then
		    /bin/echo -e "\e[33m Bof\e[39m"
		    note=$((note+1))
		else
		    /bin/echo -e "\e[32m OK\e[39m"
		    note=$((note+2))
	        fi
	    else
	        /bin/echo -e "\e[31m KO\e[39m"
	    fi

	done
    else
	# sans reads
	/bin/echo -ne "\e[34m \t execution\e[39m"

	if ! timeout 5 /usr/bin/java -jar $MVAP_JAR  $t_name.mvap.cbap  > $t_name.res 2> $t_name.run.log
	then
	    /bin/echo -e "\e[31m Erreur\e[39m";
	    continue;
	elif (  sed -i "/^HALT/d" $t_name.run.log 2> /dev/null; [ -s $t_name.run.log ] )
	then
	    /bin/echo -ne "\e[33m Bug\e[39m"
	fi

	# Check résultat
	/bin/echo -en "\e[34m \t résultat\e[39m"
	if diff ../$PREF_COR/$WRITES_FOLDER/$t_name.res $t_name.res > /dev/null 2> /dev/null
	then
	    if [ -s $t_name.ass.log ] || 
		( sed -i "/^HALT/d" $t_name.run.log 2> /dev/null; [ -s $t_name.run.log ]) || 
		egrep "^line" $t_name.comp.log > /dev/null
	    then
		/bin/echo -e "\e[33m Bof\e[39m"
		note=$((note+2))
	    else
		/bin/echo -e "\e[32m OK\e[39m"
		note=$((note+4))
	    fi
	else
	    /bin/echo -e "\e[31m KO\e[39m"
	fi
    fi
done


/bin/echo ""
/bin/echo -e "\e[34mRésultat: \e[39m$note "


