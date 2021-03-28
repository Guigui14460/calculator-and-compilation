import java.util.*;

/**
 * Classe permettant d'effectuer des actions pour la calculette.
 */
class CalculetteUtils {
    /**
     * Table de symboles (pour variables globales et locales, et fonctions).
     */
    private TablesSymboles tablesSymboles = new TablesSymboles();

    /**
     * Prochain numero de label à utiliser.
     */
    private int currentLabel = 1;

    /**
     * Liste contenant les noms des variables globales créées.
     */
    private List<String> globalVariables = new ArrayList<>();

    /**
     * Liste contenant les noms des variables locales créées.
     */
    private List<String> localVariables = new ArrayList<>();

    /**
     * Booléen permettant de savoir si une table locale est initialisée.
     */
    private boolean localTableEnabled = false;

    /**
     * Permet de savoir quelle fonction on déclare.
     */
    private String currentFunctionDefinition = null;

    /**
     * Récupère les tables de symboles.
     * 
     * @return tables de symboles
     */
    public TablesSymboles getTablesSymboles() {
        return this.tablesSymboles;
    }

    /**
     * Renvoie le label suivant (pour un branchement ou un boucle par exemple)
     * 
     * @return nouveau label
     */
    public String getNewLabel() {
        return "B" + (this.currentLabel++);
    }

    /**
     * Vérifie si le paramètre @code{type} est un flottant
     * 
     * @param type type de la variable ou de l'expression
     * @return est un flottant ou non
     */
    public static boolean isFloat(String type) {
        return type.equals("float");
    }

    /**
     * Vérifie si le paramètre @code{type} est un entier
     * 
     * @param type type de la variable ou de l'expression
     * @return est un entier ou non
     */
    public static boolean isInteger(String type) {
        return type.equals("int");
    }

    /**
     * Vérifie si le paramètre @code{type} est un booléen
     * 
     * @param type type de la variable ou de l'expression
     * @return est un booléen ou non
     */
    public static boolean isBool(String type) {
        return type.equals("bool");
    }

    /**
     * Vérifie si le paramètre @code{at} est identifiant de type flottant
     * 
     * @param at adresse de la variable
     * @return est un flottant ou non
     */
    public static boolean isFloat(AdresseType at) {
        return at.type.equals("float");
    }

    /**
     * Vérifie si le paramètre @code{at} est identifiant de type entier
     * 
     * @param at adresse de la variable
     * @return est un entier ou non
     */
    public static boolean isInteger(AdresseType at) {
        return at.type.equals("int");
    }

    /**
     * Vérifie si le paramètre @code{at} est identifiant de type booléen
     * 
     * @param at adresse de la variable
     * @return est un booléen ou non
     */
    public static boolean isBool(AdresseType at) {
        return at.type.equals("bool");
    }

    /**
     * Récupère l'adresse et le type d'une certaine variable
     * 
     * @param id identifiant de la variable
     * @return adresse-type
     */
    public AdresseType getAdresseType(String id) {
        return this.tablesSymboles.getAdresseType(id);
    }

    /**
     * Calcule le type final d'un calcul entre 2 expressions
     * 
     * @param a première expression
     * @param b deuxième expression
     * @return type final
     */
    public static String getFinalExpressionType(String a, String b) {
        if (a.equals("float") || b.equals("float")) {
            return "float";
        }
        return (a.equals("int") || b.equals("int") ? "int" : "bool");
    }

    /**
     * Génère le code MVaP pour dépiler la variable
     * 
     * @param name identifiant de la variable
     * @return code MVaP pour dépiler
     */
    public String generatePopForVariable(String name) {
        return generatePopFromType(this.tablesSymboles.getAdresseType(name).type);
    }

    /**
     * Génère le code MVaP pour dépiler en fonction du type
     * 
     * @param type type pour connaître le nombre de POP à générer
     * @return code MVaP pour dépiler
     */
    public String generatePopFromType(String type) {
        String res = "";
        for (int i = 0; i < AdresseType.getSize(type); i++) {
            res += "  POP\n";
        }
        return res;
    }

    /**
     * Dépile toute la pile (en fonction des variables globales déclarées)
     * 
     * @return code MVaP pour dépiler
     */
    public String unstackWholeStack() {
        int res = 0;
        for (String variable : this.globalVariables) {
            res += AdresseType.getSize(this.tablesSymboles.getAdresseType(variable).type);
        }
        this.globalVariables = new ArrayList<>();
        return "  FREE " + res + "\n";
    }

    /**
     * Génère un type d'action en fonction de si c'est une variable locale ou
     * globale.
     * 
     * @param name       identifiant de la variable
     * @param actionName nom de l'action
     * @return code MVaP
     */
    public String getTypeOfAction(String name, String actionName) {
        AdresseType at = this.tablesSymboles.getAdresseType(name);
        return getTypeOfActionWithAddress(at, actionName);
    }

    /**
     * Génère un type d'action en fonction de si c'est une variable locale ou
     * globale.
     * 
     * @param at         adresse-type de la variable
     * @param actionName nom de l'action
     * @return code MVaP
     */
    public static String getTypeOfActionWithAddress(AdresseType at, String actionName) {
        if (at.adresse < 0) {
            return "  " + actionName + "L " + at.adresse + "\n";
        }
        return "  " + actionName + "G " + at.adresse + "\n";
    }

    /**
     * Met une variable dans la table de symboles
     * 
     * @param name identifiant de la variable
     * @param type type de la variable
     */
    public void putVariable(String name, String type) {
        this.tablesSymboles.putVar(name, type);
        if (!this.localTableEnabled) {
            this.globalVariables.add(name);
        } else {
            this.localVariables.add(name);
        }
    }

    /**
     * Ajout d'une fonction dans la table de symboles
     * 
     * @param name identifiant de la fonction
     * @param type type de retour de la fonction
     * @return si elle n'existe pas (=true), si elle existe déjà (=false)
     */
    public boolean newFunction(String name, String type) {
        this.currentFunctionDefinition = name;
        return this.tablesSymboles.newFunction(name, type);
    }

    /**
     * Récupère l'adresse-type de la fonction qui est en train d'être déclarée.
     * 
     * @return adresse-type de la fonction déclarée actuellement
     */
    public String getAdresseTypeOfCurrentFunction() {
        return this.getFunction(this.currentFunctionDefinition);
    }

    /**
     * Récupère le type de retour de la fonction.
     * 
     * @param name identifiant de la fonction
     * @return type de retour de la fonction
     */
    public String getFunction(String name) {
        return this.tablesSymboles.getFunction(name);
    }

    /**
     * Créer la table locale.
     */
    public void newLocaleTable() {
        this.tablesSymboles.newTableLocale();
        this.localTableEnabled = true;
    }

    /**
     * Détruit la table locale.
     */
    public void dropLocaleTable() {
        this.tablesSymboles.dropTableLocale();
        this.localTableEnabled = false;
        this.localVariables = new ArrayList<>();
    }

    /**
     * Génère la taille prise par l'ensemble des variables locales (arguments de la
     * fonction). Utilisé pour le token return.
     * 
     * @return taille prise par les variables locales
     */
    public int generateStoreLocalToFunction() {
        int res = 0;
        for (String variable : localVariables) {
            res += AdresseType.getSize(tablesSymboles.getAdresseType(variable).type);
        }
        return res;
    }

    /**
     * Génère le code MVaP pour convertir un entier en booléen (modulo 2). Gère les
     * entiers négatifs.
     * 
     * @return code MVaP pour convertir un entier en booléen
     */
    public String convertToBool() {
        // String modulo2 = " DUP\n PUSHI 2\n DIV\n PUSHI 2\n MUL\n SUB\n";
        // String label = this.getNewLabel();
        // return modulo2 + " DUP\n PUSHI 0\n INF\n JUMPF " + label + "\n PUSHI -1\n
        // MUL\nLABEL " + label + "\n";
        return "  PUSHI 0\n  NEQ\n";
    }
}
