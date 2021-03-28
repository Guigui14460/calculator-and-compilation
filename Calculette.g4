grammar Calculette;

@members {
	CalculetteUtils utils = new CalculetteUtils();
}

// parser

start: a = calcul EOF;

calcul
	returns[ String code ]
	@init { $code = ""; }
	@after { System.out.println($code); }: // accumulateur
	(declaration { $code += $declaration.code; })* { $code += "  JUMP main\n"; } NEWLINE* (
		function { $code += $function.code; }
	)* NEWLINE* { $code += "LABEL main\n"; } (
		instruction { $code += $instruction.code; }
	)* {
		$code += utils.unstackWholeStack(); // on libère la mémoire de la pile (en supprimant l'espace pris par les variables globales)
        $code += "  HALT\n";
    };

instruction
	returns[ String code ]:
	ioFunctions endInstruction {
		$code = $ioFunctions.code;
	}
	| RETURN expression endInstruction {
		/*  -3 car il y a fp et pc et il faut mettre 1 en plus pour prendre la valeur (car on commence à 0),
			on ajoute la valeur que l'on souhaite
			et on fait l'opposé pour récupérer en local
		*/
		$code = $expression.code;
		$code += "  STOREL -" + (3 + utils.generateStoreLocalToFunction()) + "\n";
		if(utils.isFloat(utils.getAdresseTypeOfCurrentFunction())){
			$code += "  STOREL -" + (4 + utils.generateStoreLocalToFunction()) + "\n";
		}
		$code += "  RETURN\n";
	}
	| loopStatement {
		$code = $loopStatement.code;
	}
	| conditionStatement { $code = $conditionStatement.code; }
	| expression endInstruction {
        $code = $expression.code;
    }
	| assignment endInstruction {
        $code = $assignment.code;
	}
	| block { $code = $block.code; }
	| endInstruction { $code = ""; };

endInstruction: (NEWLINE | SEMICOLON)+;

function
	returns[ String code ]
	@init { $code = ""; }: // déclaration de fonction
	TYPE IDENTIFIANT O_ROUND_BRACKETS params? C_ROUND_BRACKETS {
			// on ne déclare la fonction que si elle n'existe pas encore
            boolean ok = utils.newFunction($IDENTIFIANT.text, $TYPE.text);
            if(ok){
                $code = "LABEL " + $IDENTIFIANT.text + "\n";
            } else {
				System.err.println("Warning : '" + $IDENTIFIANT.text + "' fonction déjà définie avec comme type de retour '" + $TYPE.text + "' -> 2ème déclaration ignorée");
			}
        } block {
            if(ok){
                $code += $block.code;
                $code += "RETURN\n";
                utils.dropLocaleTable();
            }
        };

params
	returns[ String code ]
	@init { utils.newLocaleTable(); }:
	TYPE IDENTIFIANT {
            utils.putVariable($IDENTIFIANT.text, $TYPE.text);
    } (
		COMMA TYPE IDENTIFIANT {
            utils.putVariable($IDENTIFIANT.text, $TYPE.text);
    }
	)*;

args
	returns[ String code, int size ]
	@init { $code = ""; $size = 0; }:
	(
		expression { 
        $code += $expression.code;
		$size += AdresseType.getSize($expression.type);
    } (
			COMMA expression { 
        $code += $expression.code;
		$size += AdresseType.getSize($expression.type);
    }
		)*
	)?;

expression
	returns[ String code, String type ]
	@init { $type = "int"; }:
	O_ROUND_BRACKETS expression C_ROUND_BRACKETS {
		$code = $expression.code;
		$type = $expression.type;
	}
	| IDENTIFIANT O_ROUND_BRACKETS args C_ROUND_BRACKETS // appel de fonction  
	{
		String functionType = utils.getFunction($IDENTIFIANT.text);
		$type = functionType;
		if(utils.isFloat(functionType)){ // on réserve l'espace pour la valeur de retour
			$code = "  PUSHF 0.0\n";
		} else {
			$code = "  PUSHI 0\n";
		}
		$code += $args.code; // on empile les valeurs pour les arguments
		$code += "  CALL " + $IDENTIFIANT.text + "\n";
		for(int i = 0; i < $args.size; i++){ // on supprime les arguments de la fonction
			$code += "  POP\n";
		}
    }
	| b = expression op1 = (DIV | MUL) c = expression {
		$type = utils.getFinalExpressionType($b.type, $c.type);
		boolean isFloat = utils.isFloat($type);

		$code = $b.code;
		if(isFloat){ // conversion implicite vers un flottant
			if(!utils.isFloat($b.type)){
				$code += "  ITOF\n";
				System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
			}
		}
		$code += $c.code;
		if(isFloat){ // conversion implicite vers un flottant
			if(!utils.isFloat($c.type)){
				$code += "  ITOF\n";
				System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
			}
		}

		$code += "  " + (isFloat ? "F" : "") + ($op1.text.equals("*") ? "MUL\n" : "DIV\n");
	}
	| d = expression op2 = (ADD | SUB) e = expression {
		$type = utils.getFinalExpressionType($d.type, $e.type);
		boolean isFloat = utils.isFloat($type);

		$code = $d.code;
		if(isFloat){ // conversion implicite vers un flottant
			if(!utils.isFloat($d.type)){
				$code += "  ITOF\n";
				System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
			}
		}
		$code += $e.code;
		if(isFloat){ // conversion implicite vers un flottant
			if(!utils.isFloat($e.type)){
				$code += "  ITOF\n";
				System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
			}
		}

		$code += "  " + (isFloat ? "F" : "") + ($op2.text.equals("+") ? "ADD\n" : "SUB\n");
	}
	| op3 = (SUB | ADD) expression {
		$type = $expression.type;
        if($op3.text.equals("-")){ // on fait un calcul pour avoir l'opposé
			if(utils.isFloat($type)){
            	$code = "  PUSHF 0.0\n" + $expression.code + "  FSUB\n";
			} else {
            	$code = "  PUSHI 0\n" + $expression.code + "  SUB\n";
			}
        } else { // pas besoin de rajouter qqch
            $code = $expression.code;
        }
    }
	// | condition { $type = "bool"; $code = $condition.code; }
	| O_ROUND_BRACKETS TYPE C_ROUND_BRACKETS expression { // cast explicite
		$type = $TYPE.text;
		$code = $expression.code;
		if(utils.isFloat($type) && !utils.isFloat($expression.type)){
				$code += "  ITOF\n"; // conversion vers un flottant
		} else {
			if(utils.isFloat($expression.type)){
				$code += "  FTOI\n"; // conversion vers un entier
			}
			if(utils.isBool($type)){
				$code += utils.convertToBool(); // conversion vers un booléen
			}
		}
	}
	| IDENTIFIANT { // utilisation de variable
		AdresseType at = utils.getAdresseType($IDENTIFIANT.text);
		$type = at.type;
		$code = utils.getTypeOfActionWithAddress(at, "PUSH");
		if(utils.isFloat(at)) {
			AdresseType at2 = new AdresseType(at.adresse + 1, at.type);
			$code += utils.getTypeOfActionWithAddress(at2, "PUSH");
		}
	}
	| FLOAT {
		$type = "float";
		$code = "  PUSHF " + $FLOAT.text + "\n";
	}
	| INTEGER {
		$type = "int";
		$code = "  PUSHI " + $INTEGER.text + "\n";
	};

declaration
	returns[ String code ]:
	// simple declaration
	TYPE IDENTIFIANT {
		utils.putVariable($IDENTIFIANT.text, $TYPE.text);
		if(utils.isFloat($TYPE.text)){
			$code = "  PUSHF 0.0\n";
		} else {
			$code = "  PUSHI 0\n";
		}
	} (
		// assignation possible pour simple déclaration
		ASSIGN expression {
			boolean isFloat = utils.isFloat($TYPE.text);
			$code += $expression.code;
			if(isFloat){
				if(!$TYPE.text.equals($expression.type)){ // conversion implicite vers un flottant
					$code += "  ITOF\n";
					System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
				}
			} else {
				if(utils.isFloat($expression.type)){ // conversion implicite vers un entier
					$code += "  FTOI\n";
					System.err.println("Warning : les types ne matchent pas -> conversion vers entier implcite");
				}
				if(utils.isBool($TYPE.text) && !utils.isBool($expression.type)){ // conversion implicite vers un booléen
					$code += utils.convertToBool();
					System.err.println("Warning : les types ne matchent pas -> conversion vers booléen implcite");
				}
			}
			AdresseType at = utils.getAdresseType($IDENTIFIANT.text);
			if(isFloat){
				AdresseType at2 = new AdresseType(at.adresse + 1, at.type);
				$code += utils.getTypeOfActionWithAddress(at2, "STORE");
			}
			$code += utils.getTypeOfActionWithAddress(at, "STORE");
		}
	)? (
		// déclaration multiple disponible
		COMMA IDENTIFIANT {
			utils.putVariable($IDENTIFIANT.text, $TYPE.text);
			if(utils.isFloat($TYPE.text)){
				$code += "  PUSHF 0.0\n";
			} else {
				$code += "  PUSHI 0\n";
			}
		} (
			// assignation aux déclarations possibles
			ASSIGN expression {
				boolean isFloat = utils.isFloat($TYPE.text);
				$code += $expression.code;
				if(isFloat){
					if(!$TYPE.text.equals($expression.type)){ // conversion implicite vers un flottant
						$code += "  ITOF\n";
						System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
					}
				} else {
					if(utils.isFloat($expression.type)){ // conversion implicite vers un entier
						$code += "  FTOI\n";
						System.err.println("Warning : les types ne matchent pas -> conversion vers entier implcite");
					}
					if(utils.isBool($TYPE.text) && !utils.isBool($expression.type)){ // conversion implicite vers un booléen
						$code += utils.convertToBool();
						System.err.println("Warning : les types ne matchent pas -> conversion vers booléen implcite");
					}
				}
				AdresseType at = utils.getAdresseType($IDENTIFIANT.text);
				if(isFloat){
					AdresseType at2 = new AdresseType(at.adresse + 1, at.type);
					$code += utils.getTypeOfActionWithAddress(at2, "STORE");
				}
				$code += utils.getTypeOfActionWithAddress(at, "STORE");
			}
		)?
	)* endInstruction;

assignment
	returns[ String code ]:
	(
		// assignement simple
		IDENTIFIANT ASSIGN expression {
			AdresseType at = utils.getAdresseType($IDENTIFIANT.text);
			boolean isFloat = utils.isFloat(at);

			$code = $expression.code;
			if(utils.isFloat(at.type)){
				if(!at.type.equals($expression.type)){ // conversion implicite vers un flottant
					$code += "  ITOF\n";
					System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
				}
			} else {
				if(utils.isFloat($expression.type)){ // conversion implicite vers un entier
					$code += "  FTOI\n";
					System.err.println("Warning : les types ne matchent pas -> conversion vers entier implcite");
				}
				if(utils.isBool(at) && !utils.isBool($expression.type)){ // conversion implicite vers un booléen
					$code += utils.convertToBool();
					System.err.println("Warning : les types ne matchent pas -> conversion vers booléen implcite");
				}
			}
			if(isFloat){
				AdresseType at2 = new AdresseType(at.adresse + 1, at.type);
				$code += utils.getTypeOfActionWithAddress(at2, "STORE");
			}
			$code += utils.getTypeOfActionWithAddress(at, "STORE");
	}
	) (
		// assignement multiple 
		COMMA IDENTIFIANT ASSIGN expression {
			AdresseType at = utils.getAdresseType($IDENTIFIANT.text);
			boolean isFloat = utils.isFloat(at);

			$code += $expression.code;
			if(utils.isFloat(at.type)){
				if(!at.type.equals($expression.type)){ // conversion implicite vers un flottant
					$code += "  ITOF\n";
					System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
				}
			} else {
				if(utils.isFloat($expression.type)){ // conversion implicite vers un entier
					$code += "  FTOI\n";
					System.err.println("Warning : les types ne matchent pas -> conversion vers entier implcite");
				}
				if(utils.isBool(at) && !utils.isBool($expression.type)){ // conversion implicite vers un booléen
					$code += utils.convertToBool();
					System.err.println("Warning : les types ne matchent pas -> conversion vers booléen implcite");
				}
			}
			if(isFloat){
				AdresseType at2 = new AdresseType(at.adresse + 1, at.type);
				$code += utils.getTypeOfActionWithAddress(at2, "STORE");
			}
			$code += utils.getTypeOfActionWithAddress(at, "STORE");
	}
	)*
	| IDENTIFIANT op = (
		MUL_EQUAL
		| DIV_EQUAL
		| SUB_EQUAL
		| ADD_EQUAL
	) expression {
		AdresseType at = utils.getAdresseType($IDENTIFIANT.text);
		if(utils.isBool(at)){
			System.err.println("Erreur: un booléen ne peut être assigné par ce type d'assignation");
			System.exit(1);
		}
		boolean isFloat = utils.isFloat(at.type);

		$code = utils.getTypeOfActionWithAddress(at, "PUSH");
		if(isFloat){
			AdresseType at2 = new AdresseType(at.adresse + 1, at.type);
			$code += utils.getTypeOfActionWithAddress(at2, "PUSH");
		}
		$code += $expression.code;
		if(isFloat){
			if(!at.type.equals($expression.type)){ // conversion implicite vers un floattant
				$code += "  ITOF\n";
				System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
			}
		} else {
			if(utils.isFloat($expression.type)){ // conversion implicite vers un entier
				$code += "  FTOI\n";
				System.err.println("Warning : les types ne matchent pas -> conversion vers entier implcite");
			}
		}
		$code += (isFloat ? "  F" : "  ");
		if($op.text.contains("*")){
			$code += "MUL\n";
		} else if($op.text.contains("/")){
			$code += "DIV\n";
		} else if($op.text.contains("+")){
			$code += "ADD\n";
		} else {
			$code += "SUB\n";
		}
		if(isFloat){
			AdresseType at2 = new AdresseType(at.adresse + 1, at.type);
			$code += utils.getTypeOfActionWithAddress(at2, "STORE");
		}
		$code += utils.getTypeOfActionWithAddress(at, "STORE");
	}
	| // pre et post-incrémentation
	(IDENTIFIANT INCREMENT | INCREMENT IDENTIFIANT) {
		AdresseType at = utils.getAdresseType($IDENTIFIANT.text);
		boolean isFloat = utils.isFloat(at.type);
		AdresseType at2 = new AdresseType(at.adresse + 1, at.type);

		$code = utils.getTypeOfActionWithAddress(at, "PUSH");
		if(isFloat){
			$code += utils.getTypeOfActionWithAddress(at2, "PUSH");
		}
		if(isFloat){
			$code += "  PUSHF 1.0\n  FADD\n";
		} else {
			$code += "  PUSHI 1\n  ADD\n";
		}
		if(isFloat){
			$code += utils.getTypeOfActionWithAddress(at2, "STORE");
		}
		$code += utils.getTypeOfActionWithAddress(at, "STORE");
	}
	| // pre et post-décrémentation
	(IDENTIFIANT DECREMENT | DECREMENT IDENTIFIANT) {
		AdresseType at = utils.getAdresseType($IDENTIFIANT.text);
		boolean isFloat = utils.isFloat(at.type);
		AdresseType at2 = new AdresseType(at.adresse + 1, at.type);

		$code = utils.getTypeOfActionWithAddress(at, "PUSH");
		if(isFloat){
			$code += utils.getTypeOfActionWithAddress(at2, "PUSH");
		}
		if(isFloat){
			$code += "  PUSHF 1.0\n  FSUB\n";
		} else {
			$code += "  PUSHI 1\n  SUB\n";
		}
		if(isFloat){
			$code += utils.getTypeOfActionWithAddress(at2, "STORE");
		}
		$code += utils.getTypeOfActionWithAddress(at, "STORE");
	};

ioFunctions
	returns[ String code ]:
	inputFunction {
		$code = $inputFunction.code;
	}
	| outputFunction {
		$code = $outputFunction.code;
	};

outputFunction
	returns[ String code ]:
	// affichage d'expression
	WRITE_FUNCTION_NAME O_ROUND_BRACKETS expression C_ROUND_BRACKETS {
		$code = $expression.code;
		if(utils.isFloat($expression.type)){
			$code += "  WRITEF\n";
		} else {
			$code += "  WRITE\n";
		}
		$code += utils.generatePopFromType($expression.type);
	}
	// affichage de condition
	| WRITE_FUNCTION_NAME O_ROUND_BRACKETS condition C_ROUND_BRACKETS {
		$code = $condition.code;
		$code += "  WRITE\n";
		$code += utils.generatePopFromType("bool");
	};

inputFunction
	returns[ String code ]:
	// lecture de flottant ou d'entier et affectation à une variable
	READ_FUNCTION_NAME O_ROUND_BRACKETS IDENTIFIANT C_ROUND_BRACKETS {
		AdresseType at = utils.getAdresseType($IDENTIFIANT.text);
		if(utils.isFloat(at)){
			$code = "  READF\n";
			AdresseType at2 = new AdresseType(at.adresse + 1, at.type);
			$code += utils.getTypeOfActionWithAddress(at2, "STORE");
		} else {
			$code = "  READ\n";
		}
		$code += utils.getTypeOfActionWithAddress(at, "STORE");
	};

conditionalOperator
	returns[ String code ]:
	EQUALS { $code = "EQUAL"; }
	| NEQUALS { $code = "NEQ"; }
	| LT { $code = "INF"; }
	| LTEQUALS { $code = "INFEQ"; }
	| GT { $code = "SUP"; }
	| GTEQUALS { $code = "SUPEQ"; };

condition
	returns[ String code ]:
	O_ROUND_BRACKETS condition C_ROUND_BRACKETS { $code = $condition.code; }
	| NOT condition {
		/*
			On vérifie si le résultat de la condition est égal à 0:
				- si oui: ça se transforme en 1
				- sinon: ça se transforme en 0
		 */
		$code = $condition.code;
		$code += "  PUSHI 0\n  EQUAL\n";
	}
	| a = condition AND b = condition {
		/*
			On vérifie si le résultat de la condition 'a' est égal à 0:
				- si oui: on continue l'exécution (pc+2), on ajoute un 0 et on saute à la fin
				- sinon: on saute au 'elseLabel', on exécute la condition 'b'
		 */
		String elseLabel = utils.getNewLabel();
		String endLabel = utils.getNewLabel();
		$code = $a.code;
		$code += "  PUSHI 0\n  EQUAL\n  JUMPF " + elseLabel + "\n";
		$code += "  PUSHI 0\n  JUMP " + endLabel + "\n";
		$code += "LABEL " + elseLabel + "\n";
		$code += $b.code;
		$code += "LABEL " + endLabel + "\n";
	}
	| c = condition OR d = condition {
		/*
			On vérifie si le résultat de la condition 'c' est égal à 1:
				- si oui: on continue l'exécution (pc+2), on ajoute un 1 et on saute à la fin
				- sinon: on saute au 'elseLabel', on exécute la condition 'd'
		 */
		String elseLabel = utils.getNewLabel();
		String endLabel = utils.getNewLabel();
		$code = $c.code;
		$code += "  JUMPF " + elseLabel + "\n";
		$code += "  PUSHI 1\n  JUMP " + endLabel + "\n";
		$code += "LABEL " + elseLabel + "\n";
		$code += $d.code;
		$code += "LABEL " + endLabel + "\n";
	}
	| e = expression conditionalOperator f = expression {
		String type = utils.getFinalExpressionType($e.type, $f.type);
		boolean isFloat = utils.isFloat(type);

		$code = $e.code;
		if(isFloat && !utils.isFloat($e.type)){ // conversion implicite vers un floattant
			System.out.println("ici");
			$code += "  ITOF\n";
			System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
		}
		$code += $f.code;
		if(isFloat && !utils.isFloat($f.type)){ // conversion implicite vers un floattant
			System.out.println("ici");
			$code += "  ITOF\n";
			System.err.println("Warning : les types ne matchent pas -> conversion vers flottant implcite");
		}
		$code += "  " + (isFloat ? "F" : "") + $conditionalOperator.code + "\n";
	}
	| TRUE { $code = "  PUSHI 1\n"; }
	| FALSE { $code = "  PUSHI 0\n"; };

conditionStatement
	returns[ String code ]
	@init {
		$code = "";
		String endLabel = utils.getNewLabel();
		String nextLabel = utils.getNewLabel();
	}
	@after { $code += "LABEL " + endLabel + "\n"; }:
	// simple condition
	IF O_ROUND_BRACKETS condition C_ROUND_BRACKETS instruction {
		$code = $condition.code;
		$code += "  JUMPF " + nextLabel + "\n";
		$code += $instruction.code;
		$code += "  JUMP " + endLabel + "\n";
		$code += "LABEL " + nextLabel + "\n";
	} (
		// sinon optionnel (else if compris aussi ici)
		ELSE a = instruction {
		$code += $a.code;
	}
	)?;

loopStatement
	returns[ String code ]:
	whileLoop {
		$code = $whileLoop.code;
	}
	| forLoop {
		$code = $forLoop.code;
	}
	| repeatUntil {
		$code = $repeatUntil.code;
	};

whileLoop
	returns[ String code ]:
	WHILE O_ROUND_BRACKETS condition C_ROUND_BRACKETS instruction {
		String beginLabel = utils.getNewLabel();
		String endLabel = utils.getNewLabel();
		$code = "LABEL " + beginLabel + "\n";
		$code += $condition.code;
		$code += "  JUMPF " + endLabel + "\n";
		$code += $instruction.code;
		$code += "  JUMP " + beginLabel + "\n";
		$code += "LABEL " + endLabel + "\n";
	};

forLoop
	returns[ String code ]:
	FOR O_ROUND_BRACKETS a = assignment SEMICOLON condition SEMICOLON b = assignment
		C_ROUND_BRACKETS instruction {
		String l1 = utils.getNewLabel();
		String l2 = utils.getNewLabel();
		$code = $a.code;
		$code += "LABEL " + l1 + "\n";
		$code += $condition.code;
		$code += "  JUMPF " + l2 + "\n";
		$code += $instruction.code;
		$code += $b.code;
		$code += "  JUMP " + l1 + "\n";
		$code += "LABEL " + l2 + "\n";
	};

repeatUntil
	returns[ String code]:
	// boucle "répété jusqu'à"
	REPEAT instruction UNTIL O_ROUND_BRACKETS condition C_ROUND_BRACKETS {
		String startLabel = utils.getNewLabel();
		$code = "LABEL " + startLabel + "\n";
		$code += $instruction.code;
		$code += $condition.code;
		$code += "  JUMPF " + startLabel + "\n";
	};

block
	returns[ String code ]
	@init { $code = ""; }:
	O_CURLY_BRACKETS (instruction { $code += $instruction.code; })* C_CURLY_BRACKETS NEWLINE*;

// lexer

// types
TYPE: INTEGER_TYPE | FLOAT_TYPE | BOOL_TYPE;
INTEGER_TYPE: 'int';
FLOAT_TYPE: 'float';
BOOL_TYPE: 'bool';

// default functions name
READ_FUNCTION_NAME: 'read';
WRITE_FUNCTION_NAME: 'write';

// reserved word
IF: 'if';
ELSE: 'else';
RETURN: 'return';
BREAK: 'break';
CONTINUE: 'continue';
FOR: 'for';
WHILE: 'while';
DO: 'do';
REPEAT: 'repeat';
UNTIL: 'until';
AND: '&&';
OR: '||';
NOT: '!';
TRUE: 'true';
FALSE: 'false';

// some token often used;
SEMICOLON: ';';
COMMA: ',';
ASSIGN: '=';
EQUALS: '==';
NEQUALS: '!=' | '<>';
GTEQUALS: '>=';
GT: '>';
LTEQUALS: '<=';
LT: '<';
MUL: '*';
MUL_EQUAL: '*=';
DIV: '/';
DIV_EQUAL: '/=';
ADD: '+';
ADD_EQUAL: '+=';
SUB: '-';
SUB_EQUAL: '-=';
DECREMENT: '--';
INCREMENT: '++';
O_CURLY_BRACKETS: '{';
C_CURLY_BRACKETS: '}';
O_ROUND_BRACKETS: '(';
C_ROUND_BRACKETS: ')';

// other things
IDENTIFIANT: ('a' ..'z' | 'A' ..'Z' | '_') (
		'a' ..'z'
		| 'A' ..'Z'
		| '_'
		| '0' ..'9'
	)*;

INTEGER: ('0' ..'9')+;

BOOLEAN: TRUE | FALSE;

fragment EXPOSANT: ('e' | 'E') ('+' | '-')? INTEGER;
FLOAT: INTEGER (('.') ('0' ..'9')*)? EXPOSANT?;

NEWLINE: '\r'? '\n';

WS: (' ' | '\t')+ -> skip;

MULTIPLE_LINES_COMMENT: '/*' .*? '*/' -> skip;

SIGNLE_LINE_COMMENT: ('//' | '#') ~[\r\n]* -> skip;

UNMATCH: . -> skip;
