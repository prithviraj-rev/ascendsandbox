/******************************************************************************
// File Name:       SoftValidationLogicExpression
// Summary:         This class allows to evaluate string logic expressions, like "1 AND 2", "(1 AND 2) OR (3 AND 4)", "1 AND NOT 2" etc.
//                  Supported operators: see OPERATORS constant, round brackets are supported
// Test Class:      SoftValidationLogicExpressionTest
// Created On:      07/28/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 07/28/2021 - created class
*******************************************************************************/

public without sharing class SoftValidationLogicExpression {
    private static final Set<String> OPERATORS = new Set<String>{'AND', 'OR', 'NOT'};

    //this list ensures proper precedence of operators. Any operator not mentioned in this list will be processed normally (i.e. from left to right)
    private static final List<Set<String>> OPERATOR_PRECEDENCE = new List<Set<String>>{
        new Set<String>{'NOT'}, //first goes 'NOT'
        new Set<String>{'AND'} //then goes 'AND' and last goes 'OR'
    };

    public String expressionString {get; private set;}
    public Expression expression {get; private set;}
    public Boolean evaluationResult {get; private set;}

    private List<String> evaluationLog {get; set;}

    /************************** PUBLIC METHODS **************************/

    /*
    * Constructor, which parses given expression right away.
     */
    public SoftValidationLogicExpression(String expressionString){
        if (String.isBlank(expressionString)) throw new SoftValidationLogicExpressionParseException('expression is not provided.');

        this.expressionString = expressionString.replaceAll('\r\n|\n|\r', ' ').normalizeSpace();
        if (String.isBlank(expressionString)) throw new SoftValidationLogicExpressionParseException('expression is not provided.');
        validateExpression();

        this.expression = new Expression(this.expressionString, false);
    }

    /*
    * Calculates given Logic Expression and returns Boolean.
    * @booleanItems - required, list of Booleans, which parsed logic will be applied to.
    * @params - optional, arbitrary set of params, which may change evaluation logic in some way. Two params are currently supported:
    *           #1 - allowInvalidIndices (Boolean) - if set to "true" then invalid index (index that exceeds @booleanItems bounds) will be evaluated to "false", otherwise exception will be thrown.
    *                By default, if index is invalid then exception is thrown.
    *           #2 - allowNulls (Boolean) - if set to "true" then if an index is evaluated to "null" (@booleanItems list has nulls instead of true/false) then it will be treated as "false", otherwise exception will be thrown.
    *                By default, if index is evaluated to "null" then exception is thrown.
     */
    public Boolean evaluate(List<Boolean> booleanItems, Map<String, Object> params){
        if (this.expression == null) throw new SoftValidationLogicExpressionEvaluateException('expression is not parsed.');
        if (booleanItems == null || booleanItems.isEmpty()) throw new SoftValidationLogicExpressionEvaluateException('list of Boolean items was not provided.');

        Boolean allowInvalidIndices = false;
        Boolean allowNulls = false;

        if (params != null){
            Object allowInvalidIndicesObj = params.get('allowInvalidIndices');
            Object allowNullsObj = params.get('allowNulls');

            if (allowInvalidIndicesObj instanceof Boolean) allowInvalidIndices = (Boolean) allowInvalidIndicesObj;
            if (allowNullsObj instanceof Boolean) allowNulls = (Boolean) allowNullsObj;
        }

        this.evaluationLog = new List<String>();

        List<Integer> allIndices = this.getAllIndices();
        Map<Integer, Boolean> valueByIndex = new Map<Integer, Boolean>();

        for (Integer i = 0; i < allIndices.size(); i++){
            Integer index = allIndices.get(i);
            Integer listIndex = index - 1;

            if (listIndex < 0 || listIndex >= booleanItems.size()){
                if (allowInvalidIndices == false) throw new SoftValidationLogicExpressionEvaluateException('criterion #' + index + ' does not exist.');
                valueByIndex.put(index, false);

                this.evaluationLog.add('INDEX: [' + index + '] = "FALSE" (INVALID INDEX)');
            }
            else{
                Boolean indexValue = booleanItems.get(listIndex);

                if (indexValue == null){
                    if (allowNulls == false) throw new SoftValidationLogicExpressionEvaluateException('expected Boolean value for expression item "' + index + '", actual value - NULL.');
                    indexValue = false;
                    this.evaluationLog.add('INDEX: [' + index + '] = "FALSE" (ACTUAL VALUE = NULL)');
                }
                else{
                    this.evaluationLog.add('INDEX: [' + index + '] = "' + String.valueOf(indexValue).toUpperCase() + '"');
                }

                valueByIndex.put(index, indexValue);
            }
        }

        this.evaluationResult = this.expression.evaluate(valueByIndex, params, this.evaluationLog).value;

        return this.evaluationResult;
    }

    /*
    * Returns sorted list of all indices in the expression.
    * Can be used for additional custom validation (e.g. to check if an index references some non-existent source) or debug/troubleshooting purposes
     */
    public List<Integer> getAllIndices(){
        if (this.expression == null) throw new SoftValidationLogicExpressionParseException('expression is not parsed.');

        Set<Integer> allIndices = new Set<Integer>();
        this.expression.getAllIndices(allIndices);
        List<Integer> allIndicesList = new List<Integer>(allIndices);

        allIndicesList.sort();

        return allIndicesList;
    }

    /*
    * helper method that can be used for troubleshooting or analyzing how the passed expression was parsed
     */
    public String getParsingResultsJSON(){
        if (this.expression == null) throw new SoftValidationLogicExpressionParseException('expression is not parsed.');

        Map<String, Object> results = new Map<String, Object>();
        this.expression.getParsingResults(results);

        return JSON.serialize(results);
    }

    /*
    * helper method that can be used for troubleshooting or analyzing how the passed expression was evaluated
     */
    public List<String> getEvaluationLog(){
        if (this.expression == null) throw new SoftValidationLogicExpressionParseException('expression is not parsed.');

        return this.evaluationLog;
    }

    /************************** PRIVATE METHODS **************************/

    /*
    * helper method, which ensures that given expression is "well-formatted" in terms of opening/closing round brackets and characters
     */
    private void validateExpression(){
        Boolean isValid = Pattern.matches('[a-zA-Z0-9() ]+', this.expressionString);
        if (isValid == false) throw new SoftValidationLogicExpressionParseException('only alphanumeric characters, spaces and round brackets are allowed.');

        Integer openingRoundBracketOccurrenceCount = 0;

        for (Integer i = 0; i < this.expressionString.length(); i++){
            String character = this.expressionString.substring(i, i + 1);

            if (character == '(') openingRoundBracketOccurrenceCount++;
            if (character == ')') openingRoundBracketOccurrenceCount--;
        }

        if (openingRoundBracketOccurrenceCount != 0) throw new SoftValidationLogicExpressionParseException('number of opening and closing round brackets does not match.');
    }

    /************************** HELPER CLASSES **************************/

    /*
    * Main class that parses an expression and builds Expression Stack - a list of integer indices, which alternate with operators.
     */
    private class Expression {
        public String expressionString {get; private set;}
        public Boolean isSubExpression {get; private set;}
        public List<Object> expressionStack {get; private set;} //contains instances of Expression class or Integers (item index) or Strings - operators

        /*
        * Constructor, which parses the given @expressionString and generates "expressionStack"
         */
        public Expression(String expressionString, Boolean isSubExpression){
            this.expressionString = expressionString.trim();
            this.isSubExpression = isSubExpression;
            this.expressionStack = new List<Object>();

            //expression may start with both - index or 'NOT' operator, so sending "null" as searchType
            this.parseExpressionRecursive(this.expressionString, this.expressionStack);
            this.validateExpressionStack();
        }

        /*
        * Calculates value for this expression and returns ExpressionItemEvaluated object, which stores original expression and evaluated value (Boolean).
         */
        public ExpressionItemEvaluated evaluate(Map<Integer, Boolean> valueByIndex, Map<String, Object> params, List<String> evaluationLog){
            ExpressionItemEvaluated evaluationResult;

            //all items that are not Operators, need to be evaluated and converted to ExpressionItemEvaluated
            List<Object> evaluationResultStack = new List<Object>();

            for (Object expressionStackItem : this.expressionStack){
                if (expressionStackItem instanceof Expression){
                    Expression expression = (Expression) expressionStackItem;
                    evaluationResultStack.add(expression.evaluate(valueByIndex, params, evaluationLog));
                }
                else if (expressionStackItem instanceof Integer){
                    Integer index = ((Integer) expressionStackItem);
                    Boolean indexValue = valueByIndex.get(index);

                    evaluationResultStack.add(new ExpressionItemEvaluated(String.valueOf(expressionStackItem), indexValue));
                }
                else{ //OPERATOR
                    evaluationResultStack.add(expressionStackItem);
                }
            }

            Integer operatorPrecedenceItemIndex = 0;
            Set<String> currentPriorityOperators = (operatorPrecedenceItemIndex < OPERATOR_PRECEDENCE.size() ? OPERATOR_PRECEDENCE.get(operatorPrecedenceItemIndex) : null);

            while (evaluationResultStack.size() > 1){
                Boolean priorityOperatorFound = false;

                for (Integer i = 0; i < evaluationResultStack.size(); i++){
                    Object expressionStackItem = evaluationResultStack.get(i);

                    if (expressionStackItem instanceof String){
                        String operator = (String) expressionStackItem;

                        if (currentPriorityOperators == null || currentPriorityOperators.contains(operator)){
                            this.evaluateOperatorAndReduceStack(evaluationResultStack, i, params, evaluationLog);

                            if (currentPriorityOperators != null) priorityOperatorFound = true;
                            break;
                        }
                    }
                }

                if (currentPriorityOperators != null && priorityOperatorFound == false){
                    operatorPrecedenceItemIndex++;
                    currentPriorityOperators = (operatorPrecedenceItemIndex < OPERATOR_PRECEDENCE.size() ? OPERATOR_PRECEDENCE.get(operatorPrecedenceItemIndex) : null);
                }
            }

            evaluationResult = (ExpressionItemEvaluated) evaluationResultStack.get(0);

            if (this.isSubExpression){
                evaluationResult = new ExpressionItemEvaluated('(' + evaluationResult.expressionString + ')', evaluationResult.value);
            }
            else if (evaluationLog != null){
                evaluationLog.add('EXPRESSION EVALUATED TO: "' + String.valueOf(evaluationResult.value).toUpperCase() + '"');
            }

            return evaluationResult;
        }

        /*
        * Returns list of all indices in the expression.
        * Can be used for additional custom validation (e.g. to check if an index references some non-existent source) or debug/troubleshooting purposes
         */
        public void getAllIndices(Set<Integer> allIndices){
            for (Object expressionStackItem : this.expressionStack){
                if (expressionStackItem instanceof Expression){
                    Expression expression = (Expression) expressionStackItem;
                    expression.getAllIndices(allIndices);
                }
                else if (expressionStackItem instanceof Integer){
                    Integer index = (Integer) expressionStackItem;
                    allIndices.add(index);
                }
            }
        }

        /*
        * Helper method, can be used for troubleshooting or analyzing how the passed expression was parsed
         */
        public void getParsingResults(Map<String, Object> results){
            results.put('type', 'EXPRESSION');
            results.put('expressionRawString', this.expressionString);

            List<Object> expressionStackItems = new List<Object>();

            for (Object expressionStackItem : this.expressionStack){
                if (expressionStackItem instanceof Expression){
                    Expression expression = (Expression) expressionStackItem;
                    Map<String, Object> expressionResults = new Map<String, Object>();

                    expression.getParsingResults(expressionResults);

                    expressionStackItems.add(expressionResults);
                }
                else if (expressionStackItem instanceof Integer){
                    Map<String, Object> indexResults = new Map<String, Object>();

                    indexResults.put('type', 'INDEX');
                    indexResults.put('value', expressionStackItem);

                    expressionStackItems.add(indexResults);
                }
                else if (expressionStackItem instanceof String){
                    Map<String, Object> operatorResults = new Map<String, Object>();

                    operatorResults.put('type', 'OPERATOR');
                    operatorResults.put('operator', expressionStackItem);

                    expressionStackItems.add(operatorResults);
                }
            }

            results.put('expressionStackItems', expressionStackItems);
        }

        /*
        * This recursive method analyzes the given expression and splits it in separate items (EXPRESSION / INTEGER (Index) / OPERATOR).
        * Items in the @expressionStack List are alternated ("NOT" is exception): EXPRESSION => OPERATOR => EXPRESSION => OPERATOR => ...
         */
        private void parseExpressionRecursive(String expressionString, List<Object> expressionStack){
            if (String.isBlank(expressionString)) return;

            String firstChar = expressionString.left(1);
            String searchType = (Pattern.matches('[0-9()]+', firstChar) ? 'EXPRESSION' : 'OPERATOR');

            if (searchType == 'EXPRESSION'){
                if (firstChar.isNumeric()){
                    Integer expEndIndex = 1;

                    for (Integer i = 1; i < expressionString.length(); i++){
                        String character = expressionString.substring(i, i + 1);

                        if (character.isNumeric()){
                            expEndIndex++;
                        }
                        else{
                            break;
                        }
                    }

                    String indexExpression = expressionString.substring(0, expEndIndex).trim();
                    if (indexExpression.startsWith('0')) throw new SoftValidationLogicExpressionParseException('invalid item index - "' + indexExpression + '".');

                    expressionStack.add(Integer.valueOf(indexExpression));
                    this.parseExpressionRecursive(expressionString.substring(expEndIndex).trim(), expressionStack);
                }
                else if (firstChar == '('){ //expecting a sub-expression between round brackets (e.g. '(1 AND 2) OR (3 AND NOT 4)')
                    Integer closingBracketIndex = SoftValidationUtils.findClosingCharacterIndex(expressionString.substring(1), '(', ')');

                    String subExpressionString = expressionString.substring(1, closingBracketIndex + 1);
                    if (String.isBlank(subExpressionString)) throw new SoftValidationLogicExpressionParseException('no expression was found between round brackets.');
                    expressionStack.add(new Expression(subExpressionString, true));
                    this.parseExpressionRecursive(expressionString.substring(closingBracketIndex + 2).trim(), expressionStack);
                }
                else{
                    throw new SoftValidationLogicExpressionParseException('expression cannot start with "' + firstChar + '" character.');
                }
            }
            else if (searchType == 'OPERATOR'){
                Integer operatorEndIndex = 0;

                for (Integer i = 0; i < expressionString.length(); i++){
                    String character = expressionString.substring(i, i + 1);

                    if (character.isAlpha() == false){
                        break;
                    }
                    else{
                        operatorEndIndex++;
                    }
                }

                String operator = expressionString.substring(0, operatorEndIndex).trim();
                String operatorUpper = operator.toUpperCase();
                if (!OPERATORS.contains(operatorUpper)) throw new SoftValidationLogicExpressionParseException('unsupported operator "' + operator + '".');
                expressionStack.add(operatorUpper);
                this.parseExpressionRecursive(expressionString.substring(operatorEndIndex).trim(), expressionStack);
            }
        }

        /*
        * Helper method, which ensures that generated Stack after parsing the expression is valid.
         */
        private void validateExpressionStack(){
            if (this.expressionStack == null || this.expressionStack.isEmpty()) throw new SoftValidationLogicExpressionParseException('parsing result is null or empty.');

            for (Integer i = 0; i < this.expressionStack.size(); i++){
                Object currentStackItem = this.expressionStack.get(i);
                Boolean currentIsIndex = (currentStackItem instanceof Integer);
                Boolean currentIsExpression = (currentStackItem instanceof Expression);
                Boolean currentIsOperator = !(currentIsIndex || currentIsExpression);
                Boolean currentIsNot = (currentIsOperator ? ((String) currentStackItem) == 'NOT' : false);

                if (i == 0){
                    if (currentIsOperator && currentIsNot == false){
                        throw new SoftValidationLogicExpressionParseException('expression cannot begin with "' + currentStackItem + '" operator.');
                    }
                }
                else{
                    Object previousStackItem = this.expressionStack.get(i - 1);
                    Boolean previousIsIndex = (previousStackItem instanceof Integer);
                    Boolean previousIsExpression = (previousStackItem instanceof Expression);
                    Boolean previousIsOperator = !(previousIsIndex || previousIsExpression);
                    Boolean previousIsNot = (previousIsOperator ? ((String) previousStackItem) == 'NOT' : false);

                    if (previousIsOperator && currentIsOperator){
                        //only "AND NOT" and "OR NOT" combinations are allowed
                        if (previousIsNot || (previousIsNot == false && currentIsNot == false)){
                            throw new SoftValidationLogicExpressionParseException('two consecutive operators found "' + previousStackItem + ' ' + currentStackItem + '".');
                        }
                    }
                    else if (previousIsOperator == false && currentIsNot){
                        String leftExpressionString = (previousIsExpression ? '(' + ((Expression) previousStackItem).expressionString + ')' : String.valueOf(previousStackItem));
                        throw new SoftValidationLogicExpressionParseException('"NOT" operator cannot go right after an index/expression "' + leftExpressionString + ' NOT".');
                    }
                    else if (previousIsOperator == false && currentIsOperator == false){
                        String leftExpressionString = (previousIsExpression ? '(' + ((Expression) previousStackItem).expressionString + ')' : String.valueOf(previousStackItem));
                        String rightExpressionString = (currentIsExpression ? '(' + ((Expression) currentStackItem).expressionString + ')' : String.valueOf(currentStackItem));
                        throw new SoftValidationLogicExpressionParseException('missing operator between two indices/expressions "' + leftExpressionString + '" "' + rightExpressionString + '".');
                    }
                }

                if (i + 1 == this.expressionStack.size()){
                    if (currentIsOperator){
                        throw new SoftValidationLogicExpressionParseException('missing index/expression after "' + currentStackItem + '" operator.');
                    }
                }
            }
        }

        /*
        * This method evaluates 2 expressions (it's already calculated expression - ExpressionItemEvaluated) with an operator in between.
        * All 3 items (left expression, operator and right expression) are removed from the given @evaluationResultStack and replaced with 1 item - ExpressionItemEvaluated.
        * Note: in case of "NOT" operator we operate only with 2 items: operator and right expression
         */
        private void evaluateOperatorAndReduceStack(List<Object> evaluationResultStack, Integer operatorIndex, Map<String, Object> params, List<String> evaluationLog){
            ExpressionItemEvaluated operatorRightExpression = (ExpressionItemEvaluated) evaluationResultStack.remove(operatorIndex + 1);
            String operator = (String) evaluationResultStack.remove(operatorIndex);
            ExpressionItemEvaluated operatorLeftExpression;
            if (operator != 'NOT') operatorLeftExpression = (ExpressionItemEvaluated) evaluationResultStack.remove(operatorIndex - 1);

            String currentExpressionString = (operatorLeftExpression != null ? operatorLeftExpression.expressionString + ' ' : '') + operator + ' ' + operatorRightExpression.expressionString;
            ExpressionItemEvaluated evaluationResult;

            switch on operator{
                when 'NOT' {
                    evaluationResult = new ExpressionItemEvaluated(currentExpressionString, !operatorRightExpression.value);
                }
                when 'AND' {
                    evaluationResult = new ExpressionItemEvaluated(currentExpressionString, (operatorLeftExpression.value && operatorRightExpression.value));
                }
                when else { //'OR'
                    evaluationResult = new ExpressionItemEvaluated(currentExpressionString, (operatorLeftExpression.value || operatorRightExpression.value));
                }
            }

            if (evaluationLog != null){
                evaluationLog.add('EXPRESSION WITH OPERATOR "' + operator + '": ' + (operatorLeftExpression != null ? '[' + operatorLeftExpression.expressionString + '] ' : '') + '<<' + operator + '>> [' + operatorRightExpression.expressionString + ']');
                evaluationLog.add('EVALUATION RESULT: ' + String.valueOf(evaluationResult.value).toUpperCase());
            }

            if (evaluationResultStack.size() == operatorIndex - (operatorLeftExpression == null ? 0 : 1)){
                evaluationResultStack.add(evaluationResult);
            }
            else{
                evaluationResultStack.add(operatorIndex - (operatorLeftExpression == null ? 0 : 1), evaluationResult);
            }
        }
    }

    /*
    * Helper class used during evaluation of an expression to store a link between original expression and value that it returned.
    * Example: "1" => true, "2" => false, "1 AND 2" => false
     */
    private class ExpressionItemEvaluated{
        public String expressionString {get; private set;}
        public Boolean value {get; private set;}

        public ExpressionItemEvaluated(String expressionString, Boolean value){
            this.expressionString = expressionString;
            this.value = value;
        }
    }

    public class SoftValidationLogicExpressionParseException extends Exception {}
    public class SoftValidationLogicExpressionEvaluateException extends Exception {}
}