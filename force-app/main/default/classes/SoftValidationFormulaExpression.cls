/******************************************************************************
// File Name:       SoftValidationFormulaExpression
// Summary:         This class allows to evaluate string formula expressions, which are built in similar format as SF Formula Fields, like:
//                  1) (2 + 3) * 10
//                  2) DATEVALUE(BLANKVALUE(CreatedDate, NOW())) + 2
//                  3) "$" & TEXT(ROUND(Product__r.Price__c, 2)) & " (tax included)"
//                  Supported data types: see DATA_TYPES constant
//                  Supported operators: see OPERATORS constant, round brackets are supported
//                  Supported functions: see FUNCTIONS constant
// Test Class:      SoftValidationFormulaExpressionTest
// Created On:      07/24/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 07/24/2021 - created class
Konstantin Ermolenko - 11/03/2021 - added support for logical operators and functions
*******************************************************************************/

public without sharing class SoftValidationFormulaExpression {
    private static final Set<String> DATA_TYPES = new Set<String>{'STRING', 'INTEGER', 'DECIMAL', 'DATE', 'DATETIME', 'BOOLEAN'};
    private static final Set<String> EXPRESSION_TYPES = new Set<String>{
        'FIELD', //lookup fields are supported, i.e. "Account__r.Name"
        'STATIC', //if passed value can be converted to a number - it will be converted. To ensure text data type, use Expression Type = FORMULA and wrap value in double quotes, e.g. ["123"] will be treated as [123] string, not number. TRUE, FALSE and NULL will be treated as boolean/null.
        'FORMULA' //any formula expression, like [Account__r.Name & " - some text"] or [(2 + 2) * 2], etc.
    };
    private static final Set<String> OPERATORS = new Set<String>{'+', '-', '*', '/', '&', '=', '==', '!=', '<>', '<', '<=', '>', '>=', '&&', '||'};
    private static final Set<String> FUNCTIONS = new Set<String>{
        'VALUE', 'ROUND', 'TRUNC', // Math functions
        'TODAY', 'NOW', 'DATE', 'DATEVALUE', 'DATETIMEVALUE', 'YEAR', 'MONTH', 'DAY', 'HOUR', 'MINUTE', 'SECOND', 'WEEKDAY', 'ADDMONTHS', // Date & Datetime functions
        'TEXT', 'LOWER', 'UPPER', 'TRIM', 'LEN', 'LEFT', 'RIGHT', 'MID', //Text functions
        'AND', 'OR', 'NOT', 'CASE', 'IF', 'ISBLANK', 'BLANKVALUE', 'ISNUMBER' // Logical functions
    };
    private static final Set<String> SPECIAL_EXPRESSIONS = new Set<String>{'TRUE', 'FALSE', 'NULL'};

    //this list ensures proper precedence of operators. Any operator not mentioned in this list will be processed normally (i.e. from left to right)
    private static final List<Set<String>> OPERATOR_PRECEDENCE = new List<Set<String>>{
        new Set<String>{'*', '/'}, //first go multiplicative operators
        new Set<String>{'+', '-'}, //then additive
        new Set<String>{'<', '<=', '>', '>='}, //then relational
        new Set<String>{'=', '==', '!=', '<>'}, //then equality
        new Set<String>{'&&'} //last - logical AND
    };

    private static final Map<String, Set<String>> COMPATIBLE_TYPES = new Map<String, Set<String>>{
        'INTEGER' => new Set<String>{'INTEGER', 'DECIMAL'},
        'DECIMAL' => new Set<String>{'DECIMAL', 'INTEGER'},
        'DATE' => new Set<String>{'DATE', 'DATETIME'},
        'DATETIME' => new Set<String>{'DATETIME', 'DATE'}
    };

    public String expressionString {get; private set;}
    public ExpressionEvaluationResult evaluationResult {get; private set;}
    private Expression expression {get; set;}
    private List<String> evaluationLog {get; set;}

    /************************** PUBLIC PROPERTIES **************************/

    /*
    * If Expression is parsed then returns one of the 3 values: FIELD, STATIC, FORMULA, otherwise returns null
     */
    public String expressionType{
        get{
            if (expressionType == null && this.expression != null){
                expressionType = 'FORMULA';

                if (this.expression.expressionStack.size() == 1){
                    Object expressionStackItem = this.expression.expressionStack.get(0);

                    if (expressionStackItem instanceof ExpressionItemParsed){
                        expressionType = ((ExpressionItemParsed) expressionStackItem).expressionItemParsedType;
                    }
                }
            }

            return expressionType;
        }
        private set;
    }

    /************************** PUBLIC METHODS **************************/

    /*
    * Constructor, which parses given expression right away.
    * @expressionType - value from EXPRESSION_TYPES, if not set then is determined automatically.
    * E.g. if you just need a text or number, then you can set @expressionType = STATIC and save some resources for analyzing the expression
     */
    public SoftValidationFormulaExpression(String expressionString, String expressionType){
        if (String.isBlank(expressionString)) throw new SoftValidationFormulaExpressionParseException('expression is not provided.');
        if (String.isNotBlank(expressionType) && !EXPRESSION_TYPES.contains(expressionType)) throw new SoftValidationFormulaExpressionParseException('unsupported expression type provided - "' + expressionType + '".');

        this.expressionString = expressionString.replace('\\"', '&quot;').replaceAll('\r\n|\n|\r', ' '); //replacing escaped double quotes (\") with &quot; for working with text literals easier
        if (String.isBlank(expressionString)) throw new SoftValidationFormulaExpressionParseException('expression is not provided.');
        validateExpression(expressionType);

        this.expression = new Expression(this.expressionString, expressionType);
    }

    /*
    * Populates given @fieldsForQuery parameter with list of fields (for SOQL query), grouped by SObject Name.
    * If it's not a special object, where we know its name in advance, the Object Name will be "PRIMARY"
    * Map key - SObject Name
    * Map value - Set of fields
     */
    public void getFieldsForQuery(Map<String, Set<String>> fieldsForQuery){
        if (this.expression == null) throw new SoftValidationFormulaExpressionEvaluateException('expression is not parsed.');
        if (fieldsForQuery == null) return;

        this.expression.getFieldsForQuery(fieldsForQuery);
    }

    /*
    * Calculates given Formula Expression and returns a value of the given Type.
    * @dataSourceObject - optional, can be an SObject or IDataSourceObject. If formula references some fields/properties then a run-time error will occur if dataSourceObject is not provided.
    * @expectedDataType - optional (from DATA_TYPES), the expected type of value returned by the method. If expected type is set and it does not match actual type (except cases when value & type are nulls) then an exception is thrown.
    * @fieldValueCache - optional, key1 - Object Name (for context object "PRIMARY" is used), key2 - Field Name, value - [field value + type] (SoftValidationUtils.SoftValidationFieldValue object).
    * @params (not in use - reserved for future) - optional, arbitrary set of params. May, for example, contain data-source records for other subsidiary SObject types.
     */
    public ExpressionEvaluationResult evaluate(Object dataSourceObject, String expectedDataType, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params){
        if (this.expression == null) throw new SoftValidationFormulaExpressionEvaluateException('expression is not parsed.');
        if (String.isNotBlank(expectedDataType) && !DATA_TYPES.contains(expectedDataType)) throw new SoftValidationFormulaExpressionEvaluateException('unsupported expected type provided - "' + expectedDataType + '".');

        if (fieldValueCache == null) fieldValueCache = new Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>>();
        if (!fieldValueCache.containsKey('PRIMARY')) fieldValueCache.put('PRIMARY', new Map<String, SoftValidationUtils.SoftValidationFieldValue>());

        this.evaluationLog = new List<String>();

        this.evaluationResult = this.expression.evaluate(dataSourceObject, fieldValueCache, params, evaluationLog);

        if (String.isNotBlank(expectedDataType) && evaluationResult.value != null && expectedDataType != evaluationResult.type){
            if (expectedDataType == 'DECIMAL' && evaluationResult.type == 'INTEGER'){
                evaluationResult = new ExpressionEvaluationResult(Decimal.valueOf((Integer) evaluationResult.value), 'DECIMAL');
            }
            else{
                throw new SoftValidationFormulaExpressionEvaluateException('wrong formula result type. Expected type is "' + expectedDataType + '", actual type - "' + evaluationResult.type + '".');
            }
        }

        return this.evaluationResult;
    }

    /*
    * helper method that can be used for troubleshooting or analyzing how the passed expression was parsed
     */
    public String getParsingResultsJSON(){
        if (this.expression == null) throw new SoftValidationFormulaExpressionParseException('expression is not parsed.');

        Map<String, Object> results = new Map<String, Object>();
        this.expression.getParsingResults(results);

        return JSON.serialize(results);
    }

    /*
    * helper method that can be used for troubleshooting or analyzing how the passed expression was evaluated
     */
    public List<String> getEvaluationLog(){
        if (this.expression == null) throw new SoftValidationFormulaExpressionEvaluateException('expression is not parsed.');

        return this.evaluationLog;
    }

    /************************** PRIVATE METHODS **************************/

    /*
    * helper method, which ensures that given expression is "well-formatted" in terms of opening/closing double quotes and round brackets
     */
    private void validateExpression(String expressionType){
        Integer openingRoundBracketOccurrenceCount = 0;
        Boolean isTextLiteral = false;

        if (String.isBlank(expressionType) || expressionType == 'FORMULA'){
            for (Integer i = 0; i < this.expressionString.length(); i++){
                String character = this.expressionString.substring(i, i + 1);

                if (character == '"'){
                    isTextLiteral = !isTextLiteral;
                }
                else if (isTextLiteral == false){
                    if (character == '(') openingRoundBracketOccurrenceCount++;
                    if (character == ')') openingRoundBracketOccurrenceCount--;
                }
            }

            if (isTextLiteral) throw new SoftValidationFormulaExpressionParseException('number of opening and closing double quotes does not match.');
            if (openingRoundBracketOccurrenceCount != 0) throw new SoftValidationFormulaExpressionParseException('number of opening and closing round brackets does not match.');
        }
    }

    /************************** UTILITY STATIC METHODS **************************/

    /*
    * Method to expose set of supported expression types so that it cannot be modified outside this class
     */
    public static Set<String> getSupportedExpressionTypes(){
        return new Set<String>(EXPRESSION_TYPES);
    }

    /*
    * Method to expose set of supported data types so that it cannot be modified outside this class
     */
    public static Set<String> getSupportedDataTypes(){
        return new Set<String>(DATA_TYPES);
    }

    /*
    * Helper method, which formats and throws exception when an inadmissible action is performed
     */
    private static void throwTypeMismatchException(String leftExpressionType, String rightExpressionType, String operator){
        Set<String> typesSet = new Set<String>();
        if (leftExpressionType != null) typesSet.add(leftExpressionType);
        if (rightExpressionType != null) typesSet.add(rightExpressionType);

        List<String> typesList = new List<String>(typesSet);
        String typesMsg = (typesList.size() == 1 ? typesList.get(0) + ' type.' : typesList.get(0) + ' and ' + typesList.get(1) + ' types.');

        throw new SoftValidationFormulaExpressionEvaluateException('operator "' + operator + '" cannot be used in conjunction with variables of ' + typesMsg);
    }

    /************************** PRIVATE CLASSES **************************/

    /*
    * This interface unites regular expressions (e.g. [2 + 2+ * 2]) or functions (e.g. [TODAY()]).
     */
    private interface IExpression {
        ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog);
        void getFieldsForQuery(Map<String, Set<String>> fieldsForQuery);
        void getParsingResults(Map<String, Object> results);
    }

    /*
    * Main class that parses an expression and builds Expression Stack - a list of single Expression Items (a field, a static value or expression/function),
    * which alternate with operators.
     */
    private class Expression implements IExpression{
        public String expressionString {get; private set;}
        public List<Object> expressionStack {get; private set;} //contains objects of ExpressionItemParsed, IExpression or String (operators) types

        /*
        * Constructor, which parses the given @expressionString and generates "expressionStack"
         */
        public Expression(String expressionString){
            this(expressionString, null);
        }

        /*
        * Constructor, which parses the given @expressionString and generates "expressionStack"
        * @expressionType - value from EXPRESSION_TYPES, if not set then is determined automatically.
        * E.g. if you just need a text or number, then you can set @expressionType = STATIC and save some resources for analyzing the expression
         */
        public Expression(String expressionString, String expressionType){
            this.expressionString = expressionString.trim();
            this.expressionStack = new List<Object>();

            if (expressionType == 'FIELD' || expressionType == 'STATIC'){
                this.expressionStack.add(new ExpressionItemParsed(this.expressionString, expressionType));
            }
            else{
                this.parseExpressionRecursive(this.expressionString, 'EXPRESSION', this.expressionStack);
            }

            this.validateExpressionStack();
        }

        /*
        * IExpression interface method.
        * Calculates value for this expression and returns value + type as ExpressionEvaluationResult object.
         */
        public ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;

            //all items that are not Operators (i.e. sub-expressions, functions or simple expression items), need to be converted into ExpressionEvaluationResult object
            List<Object> evaluationResultStack = new List<Object>();

            for (Object expressionStackItem : this.expressionStack){
                if (expressionStackItem instanceof IExpression){
                    IExpression expression = (IExpression) expressionStackItem;
                    evaluationResultStack.add(expression.evaluate(dataSourceObject, fieldValueCache, params, evaluationLog));
                }
                else if (expressionStackItem instanceof ExpressionItemParsed){
                    ExpressionItemParsed expressionItemParsed = (ExpressionItemParsed) expressionStackItem;
                    evaluationResultStack.add(expressionItemParsed.evaluate(dataSourceObject, fieldValueCache, params, evaluationLog));
                }
                else{ //OPERATOR
                    evaluationResultStack.add(expressionStackItem);
                }
            }

            Boolean evaluationResultStackHasMoreThanOneItem = (evaluationResultStack.size() > 1);

            Integer operatorPrecedenceItemIndex = 0;
            Set<String> currentPriorityOperators = (operatorPrecedenceItemIndex < OPERATOR_PRECEDENCE.size() ? OPERATOR_PRECEDENCE.get(operatorPrecedenceItemIndex) : null);

            while (evaluationResultStack.size() > 1){
                Boolean priorityOperatorFound = false;

                for (Integer i = 0; i < evaluationResultStack.size(); i++){
                    Object evaluationResultItem = evaluationResultStack.get(i);

                    if (evaluationResultItem instanceof String){
                        String operator = (String) evaluationResultItem;

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

            evaluationResult = (ExpressionEvaluationResult) evaluationResultStack.get(0);

            //if expression consists only of one item then there is no need to duplicate log records
            if (evaluationLog != null && evaluationResultStackHasMoreThanOneItem){
                evaluationLog.add('EXPRESSION: [' + this.expressionString + ']');
                evaluationLog.add('EVALUATION RESULT: [' + evaluationResult.value + ']:' + evaluationResult.type);
            }

            return evaluationResult;
        }

        /*
        * Populates given @fieldsForQuery parameter with list of fields (for SOQL query), grouped by SObject Name.
        * If it's not a special object, where we know its name in advance, the Object Name will be "PRIMARY"
        * Map key - SObject Name
        * Map value - Set of fields
         */
        public void getFieldsForQuery(Map<String, Set<String>> fieldsForQuery){
            for (Object expressionStackItem : this.expressionStack){
                if (expressionStackItem instanceof IExpression){
                    IExpression expression = (IExpression) expressionStackItem;
                    expression.getFieldsForQuery(fieldsForQuery);
                }
                else if (expressionStackItem instanceof ExpressionItemParsed){
                    ExpressionItemParsed expressionItemParsed = (ExpressionItemParsed) expressionStackItem;
                    expressionItemParsed.getFieldsForQuery(fieldsForQuery);
                }
            }
        }

        /*
        * IExpression interface method.
        * Can be used for troubleshooting or analyzing how the passed expression was parsed
         */
        public void getParsingResults(Map<String, Object> results){
            results.put('type', 'EXPRESSION');
            results.put('expressionRawString', this.expressionString);

            List<Object> expressionStackItems = new List<Object>();

            for (Object expressionStackItem : this.expressionStack){
                if (expressionStackItem instanceof IExpression){
                    IExpression expression = (IExpression) expressionStackItem;
                    Map<String, Object> expressionResults = new Map<String, Object>();

                    expression.getParsingResults(expressionResults);

                    expressionStackItems.add(expressionResults);
                }
                else if (expressionStackItem instanceof ExpressionItemParsed){
                    ExpressionItemParsed expressionItemParsed = (ExpressionItemParsed) expressionStackItem;
                    Map<String, Object> expressionItemParsedResults = new Map<String, Object>();

                    expressionItemParsedResults.put('type', 'EXPRESSION ITEM');
                    expressionItemParsedResults.put('expressionItemType', expressionItemParsed.expressionItemParsedType);
                    expressionItemParsedResults.put('expressionItemRawString', expressionItemParsed.expressionItemString);

                    expressionStackItems.add(expressionItemParsedResults);
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
        * This recursive method analyzes the given expression and splits it in separate items (EXPRESSION ITEM / EXPRESSION / FUNCTION / OPERATOR).
        * Items in the @expressionStack List are alternated: EXPRESSION => OPERATOR => EXPRESSION => OPERATOR => ...
         */
        private void parseExpressionRecursive(String expressionString, String searchType, List<Object> expressionStack){
            if (String.isBlank(expressionString)) return;

            if (searchType == 'EXPRESSION'){
                String firstChar = expressionString.left(1);

                if (firstChar == '-'){ //-Number__c, -(2 + 5)
                    expressionStack.add(new ExpressionItemParsed('-1'));
                    expressionStack.add('*');
                    this.parseExpressionRecursive(expressionString.substring(1), 'EXPRESSION', expressionStack);
                }
                else if (firstChar.isAlphanumeric() || firstChar == '"' || firstChar == '('){
                    if (firstChar.isAlphanumeric()){ //expecting a Field Name, Number or some reserved word (true/false/null) here
                        Integer expEndIndex = 1;
                        Boolean isFunction = false;

                        for (Integer i = 1; i < expressionString.length(); i++){
                            String character = expressionString.substring(i, i + 1);

                            if (character.isAlphanumeric() || character == '.' || character == '_'){
                                expEndIndex++;
                            }
                            else{
                                isFunction = (character == '(');
                                break;
                            }
                        }

                        if (isFunction){
                            String fnName = expressionString.substring(0, expEndIndex);
                            Integer closingBracketIndex = SoftValidationUtils.findClosingCharacterIndex(expressionString.substring(expEndIndex + 1), '(', ')');
                            String fnBodyString = expressionString.substring(expEndIndex + 1, expEndIndex + closingBracketIndex + 1);

                            expressionStack.add(getFunctionInstance(fnName, fnBodyString));
                            this.parseExpressionRecursive(expressionString.substring(expEndIndex + closingBracketIndex + 2), 'OPERATOR', expressionStack);
                        }
                        else{
                            expressionStack.add(new ExpressionItemParsed(expressionString.substring(0, expEndIndex)));
                            this.parseExpressionRecursive(expressionString.substring(expEndIndex), 'OPERATOR', expressionStack);
                        }
                    }
                    else if (firstChar == '"'){ //expecting a text literal here (e.g. "Some Static Text")
                        Integer closingQuoteIndex = expressionString.indexOf('"', 1);

                        expressionStack.add(new ExpressionItemParsed(expressionString.substring(0, closingQuoteIndex + 1)));
                        this.parseExpressionRecursive(expressionString.substring(closingQuoteIndex + 1), 'OPERATOR', expressionStack);
                    }
                    else if (firstChar == '('){ //expecting sub-expression between round brackets (e.g. '(2 + 3) * 4')
                        Integer closingBracketIndex = SoftValidationUtils.findClosingCharacterIndex(expressionString.substring(1), '(', ')');

                        String subExpressionString = expressionString.substring(1, closingBracketIndex + 1);
                        if (String.isBlank(subExpressionString)) throw new SoftValidationFormulaExpressionParseException('no expression was found between round brackets.');
                        expressionStack.add(new Expression(subExpressionString));
                        this.parseExpressionRecursive(expressionString.substring(closingBracketIndex + 2), 'OPERATOR', expressionStack);
                    }
                }
                else{
                    throw new SoftValidationFormulaExpressionParseException('expression cannot start with "' + firstChar + '" character.');
                }
            }
            else if (searchType == 'OPERATOR'){
                Integer operatorEndIndex = 0;

                for (Integer i = 0; i < expressionString.length(); i++){
                    String character = expressionString.substring(i, i + 1);

                    if (character.isAlphanumeric() || character == '(' || character == '"'){
                        break;
                    }
                    else{
                        operatorEndIndex++;
                    }
                }

                String operator = expressionString.substring(0, operatorEndIndex).trim();
                if (String.isBlank(operator)) throw new SoftValidationFormulaExpressionParseException('no operator was found before this expression "' + expressionString.trim() + '".');
                if (!OPERATORS.contains(operator)) throw new SoftValidationFormulaExpressionParseException('unsupported operator "' + operator + '".');
                expressionStack.add(operator);
                this.parseExpressionRecursive(expressionString.substring(operatorEndIndex), 'EXPRESSION', expressionStack);
            }
        }

        /*
        * This method evaluates 2 expressions (it's already calculated expression - instance of ExpressionEvaluationResult class) with an operator in between.
        * All 3 items (left expression, operator and right expression) are removed from the given @evaluationResultStack and replaced with 1 item - instance of ExpressionEvaluationResult.
         */
        private void evaluateOperatorAndReduceStack(List<Object> evaluationResultStack, Integer operatorIndex, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult operatorRightExpression = (ExpressionEvaluationResult) evaluationResultStack.remove(operatorIndex + 1);
            String operator = (String) evaluationResultStack.remove(operatorIndex);
            ExpressionEvaluationResult operatorLeftExpression = (ExpressionEvaluationResult) evaluationResultStack.remove(operatorIndex - 1);

            ExpressionEvaluationResult evaluationResult = this.evaluateOperator(operatorLeftExpression, operatorRightExpression, operator, params, evaluationLog);

            if (evaluationResultStack.size() == operatorIndex - 1){
                evaluationResultStack.add(evaluationResult);
            }
            else{
                evaluationResultStack.add(operatorIndex - 1, evaluationResult);
            }
        }

        /*
        * This method accepts 2 expressions and runs an action on them, which depends on the given operator, i.e. it can be addition, multiplication, concatenation, etc.
         */
        private ExpressionEvaluationResult evaluateOperator(ExpressionEvaluationResult leftExpression, ExpressionEvaluationResult rightExpression, String operator, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;

            if (leftExpression.value == null && rightExpression.value == null){
                evaluationResult = new ExpressionEvaluationResult(null, null);
            }
            else{
                switch on operator{
                    when '+', '-', '*', '/' {
                        if ((leftExpression.type == 'INTEGER' || leftExpression.value == null)
                            && (rightExpression.type == 'INTEGER' || rightExpression.value == null)){

                            Integer leftExpressionValue = (leftExpression.value == null ? 0 : (Integer) leftExpression.value);
                            Integer rightExpressionValue = (rightExpression.value == null ? 0 : (Integer) rightExpression.value);

                            Object resultValue;
                            String resultType = 'INTEGER';

                            switch on operator{
                                when '+' {
                                    resultValue = leftExpressionValue + rightExpressionValue;
                                }
                                when '-' {
                                    resultValue = leftExpressionValue - rightExpressionValue;
                                }
                                when '*' {
                                    resultValue = leftExpressionValue * rightExpressionValue;
                                }
                                when '/' {
                                    if (rightExpressionValue == 0){
                                        if (evaluationLog != null) evaluationLog.add('DIVIDING BY ZERO - RETURNING NULL');
                                    }
                                    else{
                                        if (Math.mod(leftExpressionValue, rightExpressionValue) == 0){
                                            resultValue = (Integer) (leftExpressionValue / rightExpressionValue);
                                        }
                                        else{
                                            resultValue = (Decimal) leftExpressionValue / (Decimal) rightExpressionValue;
                                            resultType = 'DECIMAL';
                                        }
                                    }
                                }
                            }

                            evaluationResult = new ExpressionEvaluationResult(resultValue, resultType);
                        }
                        else if ((leftExpression.type == 'INTEGER' || leftExpression.type == 'DECIMAL' || leftExpression.value == null)
                            && (rightExpression.type == 'INTEGER' || rightExpression.type == 'DECIMAL' || rightExpression.value == null)){

                            Decimal leftExpressionValue = (leftExpression.value == null ? 0 : (Decimal) leftExpression.value);
                            Decimal rightExpressionValue = (rightExpression.value == null ? 0 : (Decimal) rightExpression.value);

                            Decimal resultValue;
                            String resultType = 'DECIMAL';

                            switch on operator{
                                when '+' {
                                    resultValue = leftExpressionValue + rightExpressionValue;
                                }
                                when '-' {
                                    resultValue = leftExpressionValue - rightExpressionValue;
                                }
                                when '*' {
                                    resultValue = leftExpressionValue * rightExpressionValue;
                                }
                                when '/' {
                                    if (rightExpressionValue == 0){
                                        if (evaluationLog != null) evaluationLog.add('DIVIDING BY ZERO - RETURNING NULL');
                                    }
                                    else{
                                        resultValue = leftExpressionValue / rightExpressionValue;
                                    }
                                }
                            }

                            evaluationResult = new ExpressionEvaluationResult(resultValue, resultType);
                        }
                        else if((leftExpression.type == 'DATE' && (rightExpression.type == 'INTEGER' || rightExpression.value == null))
                            || ((leftExpression.type == 'INTEGER' || leftExpression.value == null) && rightExpression.type == 'DATE')){
                            if (operator == '+' || operator == '-'){
                                if (leftExpression.type == 'DATE'){
                                    Date leftExpressionValue = (Date) leftExpression.value;
                                    Integer rightExpressionValue = (Integer) (rightExpression.value == null ? 0 : rightExpression.value);

                                    if (rightExpressionValue != 0) leftExpressionValue = leftExpressionValue.addDays(rightExpressionValue * (operator == '+' ? 1 : -1));
                                    evaluationResult = new ExpressionEvaluationResult(leftExpressionValue, 'DATE');
                                }
                                else{
                                    throw new SoftValidationFormulaExpressionEvaluateException('expressions like [INTEGER + DATE] or [INTEGER - DATE] are not valid. On the contrary, [DATE + INTEGER] and [DATE - INTEGER] are supported.');
                                }
                            }
                            else{
                                throwTypeMismatchException(leftExpression.type, rightExpression.type, operator);
                            }
                        }
                        else if((leftExpression.type == 'DATETIME' && (rightExpression.type == 'INTEGER' || rightExpression.value == null))
                            || ((leftExpression.type == 'INTEGER' || leftExpression.value == null) && rightExpression.type == 'DATETIME')){
                            if (operator == '+' || operator == '-'){
                                if (leftExpression.type == 'DATETIME'){
                                    Datetime leftExpressionValue = (Datetime) leftExpression.value;
                                    Integer rightExpressionValue = (Integer) (rightExpression.value == null ? 0 : rightExpression.value);

                                    if (rightExpressionValue != 0) leftExpressionValue = leftExpressionValue.addDays(rightExpressionValue * (operator == '+' ? 1 : -1));
                                    evaluationResult = new ExpressionEvaluationResult(leftExpressionValue, 'DATETIME');
                                }
                                else{
                                    throw new SoftValidationFormulaExpressionEvaluateException('expressions like [INTEGER + DATETIME] or [INTEGER - DATETIME] are not valid. On the contrary, [DATETIME + INTEGER] and [DATETIME - INTEGER] are supported.');
                                }
                            }
                            else{
                                throwTypeMismatchException(leftExpression.type, rightExpression.type, operator);
                            }
                        }
                        else if (((leftExpression.type == 'DATETIME' || leftExpression.type == 'DATE') && (rightExpression.type == 'DATETIME' || rightExpression.type == 'DATE'))){
                            if (operator == '-'){
                                Datetime leftExpressionValue = (Datetime) leftExpression.value;
                                Datetime rightExpressionValue = (Datetime) rightExpression.value;

                                Long leftExpressionValueTime = leftExpressionValue.getTime();
                                Long rightExpressionValueTime = rightExpressionValue.getTime();
                                Long diffInMs = leftExpressionValueTime - rightExpressionValueTime;

                                Long mins = (diffInMs - Math.mod(diffInMs, 60000)) / 60000;
                                Long minsRemainder = Math.mod(mins, 60);
                                Long hours = (mins - minsRemainder) / 60;
                                Long hoursRemainder = Math.mod(hours, 24);
                                Long days = (hours - hoursRemainder) / 24;

                                if (hoursRemainder != 0 || minsRemainder != 0){
                                    Decimal resultDecimal = Decimal.valueOf(days) + Decimal.valueOf(hoursRemainder) / 24 + Decimal.valueOf(minsRemainder) / 1440;
                                    evaluationResult = new ExpressionEvaluationResult(resultDecimal.setScale(2), 'DECIMAL');
                                }
                                else{
                                    evaluationResult = new ExpressionEvaluationResult(Integer.valueOf(days), 'INTEGER');
                                }
                            }
                            else{
                                throwTypeMismatchException(leftExpression.type, rightExpression.type, operator);
                            }
                        }
                        else{
                            throwTypeMismatchException(leftExpression.type, rightExpression.type, operator);
                        }
                    }
                    when '&' {
                        if ((leftExpression.type == 'STRING' || leftExpression.value == null)
                            && (rightExpression.type == 'STRING' || rightExpression.value == null)) {

                            String leftExpressionValue = (leftExpression.value == null ? '' : (String) leftExpression.value);
                            String rightExpressionValue = (rightExpression.value == null ? '' : (String) rightExpression.value);

                            String resultValue = leftExpressionValue + rightExpressionValue;
                            evaluationResult = new ExpressionEvaluationResult(resultValue, 'STRING');
                        }
                        else{
                            throwTypeMismatchException(leftExpression.type, rightExpression.type, operator);
                        }
                    }
                    when '=', '==', '!=', '<>' {
                        Boolean result = false;
                        Boolean isEqualsOperator = (operator == '=' || operator == '==');

                        if (leftExpression.value != null && rightExpression.value != null){
                            Boolean typeAreCompatible = (leftExpression.type == rightExpression.type);

                            if (!typeAreCompatible){
                                Set<String> compatibleTypes = COMPATIBLE_TYPES.get(leftExpression.type);
                                if (compatibleTypes != null) typeAreCompatible = compatibleTypes.contains(rightExpression.type);
                            }

                            if (typeAreCompatible == false) throwTypeMismatchException(leftExpression.type, rightExpression.type, operator);

                            result = (isEqualsOperator
                                ? leftExpression.value == rightExpression.value
                                : leftExpression.value != rightExpression.value);
                        }
                        else{
                            result = (isEqualsOperator
                                ? leftExpression.value == rightExpression.value
                                : leftExpression.value != rightExpression.value);
                        }

                        evaluationResult = new ExpressionEvaluationResult(result, 'BOOLEAN');
                    }
                    when '<', '<=', '>', '>='{
                        Boolean result = false;

                        if (leftExpression.value != null && rightExpression.value != null){
                            Set<String> allowedTypes = new Set<String>{'INTEGER', 'DECIMAL', 'DATE', 'DATETIME'}; //not adding STRING intentionally, though inequality operators can be run against strings
                            if (!allowedTypes.contains(leftExpression.type) || !allowedTypes.contains(rightExpression.type)) throwTypeMismatchException(leftExpression.type, rightExpression.type, operator);
                            if (!COMPATIBLE_TYPES.get(leftExpression.type).contains(rightExpression.type)) throwTypeMismatchException(leftExpression.type, rightExpression.type, operator);

                            switch on leftExpression.type{
                                when 'INTEGER', 'DECIMAL'{
                                    Decimal leftValue = (Decimal) leftExpression.value;
                                    Decimal rightValue = (Decimal) rightExpression.value;

                                    switch on operator{
                                        when '<'{
                                            result = (leftValue < rightValue);
                                        }
                                        when '>'{
                                            result = (leftValue > rightValue);
                                        }
                                        when '<='{
                                            result = (leftValue <= rightValue);
                                        }
                                        when '>='{
                                            result = (leftValue >= rightValue);
                                        }
                                    }
                                }
                                when 'DATE', 'DATETIME'{
                                    Datetime leftValue = (Datetime) leftExpression.value;
                                    Datetime rightValue = (Datetime) rightExpression.value;

                                    switch on operator{
                                        when '<'{
                                            result = (leftValue < rightValue);
                                        }
                                        when '>'{
                                            result = (leftValue > rightValue);
                                        }
                                        when '<='{
                                            result = (leftValue <= rightValue);
                                        }
                                        when '>='{
                                            result = (leftValue >= rightValue);
                                        }
                                    }
                                }
                            }
                        }

                        evaluationResult = new ExpressionEvaluationResult(result, 'BOOLEAN');
                    }
                    when '&&', '||'{
                        Boolean result = false;

                        if (leftExpression.value != null && rightExpression.value != null){
                            if (leftExpression.type != 'BOOLEAN' || rightExpression.type != 'BOOLEAN') throwTypeMismatchException(leftExpression.type, rightExpression.type, operator);

                            Boolean leftValue = (Boolean) leftExpression.value;
                            Boolean rightValue = (Boolean) rightExpression.value;

                            switch on operator{
                                when '&&'{
                                    result = (leftValue && rightValue);
                                }
                                when '||'{
                                    result = (leftValue || rightValue);
                                }
                            }
                        }

                        evaluationResult = new ExpressionEvaluationResult(result, 'BOOLEAN');
                    }
                }
            }

            if (evaluationLog != null){
                evaluationLog.add('EXPRESSION WITH OPERATOR: [' + leftExpression.value + ']:' + leftExpression.type + ' ' + operator + ' [' + rightExpression.value + ']:' + rightExpression.type);
                evaluationLog.add('EVALUATION RESULT: [' + evaluationResult.value + ']:' + evaluationResult.type);
            }

            return evaluationResult;
        }

        /*
        * This method creates an instance of a Function class by the given Function Name.
        * If Function Name is not among the list of the supported functions, then an exception is thrown.
         */
        private AbstractFunction getFunctionInstance(String fnName, String fnBodyString){
            String fnNameUpperCase = fnName.toUpperCase();
            if (!FUNCTIONS.contains(fnNameUpperCase)) throw new SoftValidationFormulaExpressionParseException('unsupported Function: "' + fnName + '"');

            Type fnType = Type.forName('SoftValidationFormulaExpression.' + fnNameUpperCase + '_Function');
            if (fnType == null) throw new SoftValidationFormulaExpressionParseException('class is not implemented or is private for Function: "' + fnName + '"');

            AbstractFunction fnInstance = (AbstractFunction) fnType.newInstance();
            fnInstance.init(fnBodyString);

            return fnInstance;
        }

        /*
        * Helper method, which ensures that generated Stack after parsing the expression is valid.
         */
        private void validateExpressionStack(){
            if (this.expressionStack == null || this.expressionStack.isEmpty()) throw new SoftValidationFormulaExpressionParseException('parsing result is null or empty.');

            //most of the validation is done in parser itself, which ensures that:
            //#1 - Expression cannot start with Operator.
            //#2 - Expressions and Operators must rotate (EXP => OP => EXP => OP => ...) and there cannot be consecutive Expressions or Operators.
            //if criteria for #1 or #2 is not met, then an exception is thrown.
            //so, we just need to ensure that the whole chain of actions is not ended with an Operator
            Object lastItemInStack = this.expressionStack.get(this.expressionStack.size() - 1);
            if (lastItemInStack instanceof String) throw new SoftValidationFormulaExpressionParseException('expression cannot end with operator (' + lastItemInStack + ').');
        }
    }

    /*
    * This class represents a "simple expression part", which can be a field name or a static text/number value.
     */
    private class ExpressionItemParsed{
        public String expressionItemString {get; private set;}
        public String expressionItemParsedType {get; private set;} //FIELD, STATIC
        public String requestedExpressionType {get; private set;}

        public ExpressionItemParsed(String expressionItemString){
            this(expressionItemString, null);
        }

        public ExpressionItemParsed(String expressionItemString, String requestedExpressionType){
            this.expressionItemString = expressionItemString.trim();
            this.requestedExpressionType = requestedExpressionType;

            if ((requestedExpressionType == null || requestedExpressionType == 'FORMULA') && this.expressionItemString.startsWith('"')){
                this.expressionItemString = this.expressionItemString.replace('&quot;', '"');
                this.expressionItemParsedType = 'STATIC';
            }
            else{
                String expressionItemStringUpperCase = this.expressionItemString.toUpperCase();

                if ((requestedExpressionType == null || requestedExpressionType == 'FORMULA' || requestedExpressionType == 'STATIC') && SPECIAL_EXPRESSIONS.contains(expressionItemStringUpperCase)){
                    this.expressionItemString = expressionItemStringUpperCase;
                    this.expressionItemParsedType = 'STATIC';
                }
                else{
                    if (requestedExpressionType == 'FIELD' || requestedExpressionType == 'STATIC'){
                        this.expressionItemParsedType = requestedExpressionType;
                        if (requestedExpressionType == 'STATIC') this.expressionItemString = this.expressionItemString.replace('&quot;', '"');
                    }
                    else{
                        Boolean isNumber = false;

                        //checking if "this.expressionItemString" can be parsed as a Number
                        try{
                            Decimal val = Decimal.valueOf(this.expressionItemString);
                            isNumber = true;
                        }
                        catch(Exception ex){}

                        this.expressionItemParsedType = (isNumber ? 'STATIC' : 'FIELD');
                    }

                    if (this.expressionItemParsedType == 'FIELD'){
                        Map<String, Object> validationResults = SoftValidationUtils.validateFieldExpressionSoft(this.expressionItemString);
                        if ((Boolean) validationResults.get('isValid') == false){
                            throw new SoftValidationFormulaExpressionParseException((String) validationResults.get('errorMsg'));
                        }
                    }
                }
            }
        }

        /*
        * Populates given @fieldsForQuery parameter with list of fields (for SOQL query), grouped by SObject Name.
        * If it's not a special object, where we know its name in advance, the Object Name will be "PRIMARY"
        * Map key - SObject Name
        * Map value - Set of fields
         */
        public void getFieldsForQuery(Map<String, Set<String>> fieldsForQuery){
            if (this.expressionItemParsedType == 'FIELD') SoftValidationUtils.registerFieldForQuery(fieldsForQuery, 'PRIMARY', this.expressionItemString);
        }

        /*
        * Returns either a static value or a field value - depends on "expressionItemParsedType" property.
        * @dataSourceObject - required for ParsedType = "FIELD", can be an SObject or IDataSourceObject.
        * @fieldValueCache - required, key1 - Object Name (for context object "PRIMARY" is used), key2 - Field Name, value - field value + type (SoftValidationUtils.SoftValidationFieldValue object)
        * @params - optional, arbitrary set of params. May, for example, contain data-source records for other subsidiary SObject types.
        * @evaluationLog - optional, if provided then this list will be filled with evaluation results for each item in the expression. Needed for debugging/troubleshooting purposes.
         */
        public ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;

            if (this.expressionItemParsedType == 'STATIC'){
                if (SPECIAL_EXPRESSIONS.contains(this.expressionItemString)){
                    switch on this.expressionItemString {
                        when 'TRUE', 'FALSE' {
                            evaluationResult = new ExpressionEvaluationResult((this.expressionItemString == 'TRUE' ? true : false), 'BOOLEAN');
                        }
                        when else {
                            evaluationResult = new ExpressionEvaluationResult(null, null);
                        }
                    }
                }
                else{
                    Integer integerVal;
                    Decimal decimalVal;

                    try{
                        integerVal = Integer.valueOf(this.expressionItemString);
                    }
                    catch(Exception ex){}

                    if (integerVal == null){
                        try{
                            decimalVal = Decimal.valueOf(this.expressionItemString);
                        }
                        catch(Exception ex){}
                    }

                    if (integerVal != null){
                        evaluationResult = new ExpressionEvaluationResult(integerVal, 'INTEGER');
                    }
                    else if (decimalVal != null){
                        evaluationResult = new ExpressionEvaluationResult(decimalVal, 'DECIMAL');
                    }
                    else{
                        if (this.requestedExpressionType == 'STATIC'){
                            evaluationResult = new ExpressionEvaluationResult(this.expressionItemString, 'STRING');
                        }
                        else{
                            //getting substring between double quotes
                            evaluationResult = new ExpressionEvaluationResult(this.expressionItemString.substring(1, this.expressionItemString.length() - 1), 'STRING');
                        }
                    }
                }
            }
            else{
                if (dataSourceObject == null) throw new SoftValidationFormulaExpressionEvaluateException('data-source object is not provided.');

                if (dataSourceObject instanceof SObject){
                    SoftValidationUtils.SoftValidationFieldValue fieldValue;

                    String fieldNameLower = this.expressionItemString.toLowerCase();
                    Map<String, SoftValidationUtils.SoftValidationFieldValue> cachedPrimaryFieldValues = fieldValueCache.get('PRIMARY');

                    fieldValue = cachedPrimaryFieldValues.get(fieldNameLower);

                    if (!cachedPrimaryFieldValues.containsKey(fieldNameLower)){
                        fieldValue = SoftValidationUtils.getFieldValue((SObject) dataSourceObject, this.expressionItemString);

                        if (fieldValue != null){ //the only case when it's null should be a "null" lookup field in the chain of fields
                            SoftValidationUtils.SoftValidationFieldTypeDetails fieldTypeDetails = fieldValue.fieldTypeDetails;

                            if (fieldTypeDetails.describeFieldResult == null) throw new SoftValidationFormulaExpressionEvaluateException('field with name "' + fieldTypeDetails.fieldName + '" does not exist in ' + fieldTypeDetails.objectName + ' object.');
                            if (!DATA_TYPES.contains(fieldTypeDetails.type)) throw new SoftValidationFormulaExpressionEvaluateException('unsupported field type "' + fieldTypeDetails.type + '" (object - ' + fieldTypeDetails.objectName + ', field - ' + fieldTypeDetails.fieldName + ').');
                        }

                        cachedPrimaryFieldValues.put(fieldNameLower, fieldValue);
                    }

                    evaluationResult = new ExpressionEvaluationResult((fieldValue != null ? fieldValue.value : null), (fieldValue != null ? fieldValue.fieldTypeDetails.type : null));
                }
                else if (dataSourceObject instanceof IDataSourceObject){
                    DataSourceObjectGetValueResult getValueResult = ((IDataSourceObject) dataSourceObject).get(this.expressionItemString);

                    if (getValueResult == null){
                        evaluationResult = new ExpressionEvaluationResult(null, null);
                    }
                    else{
                        evaluationResult = new ExpressionEvaluationResult(getValueResult.value, getValueResult.type);
                    }
                }
                else{
                    throw new SoftValidationFormulaExpressionEvaluateException('provided data-source object does not match known types (should be SObject or IDataSourceObject).');
                }
            }

            if (evaluationLog != null){
                evaluationLog.add('SIMPLE EXPRESSION: [' + this.expressionItemString + ']:' + this.expressionItemParsedType);
                evaluationLog.add('EVALUATION RESULT: [' + evaluationResult.value + ']:' + evaluationResult.type);
            }

            return evaluationResult;
        }
    }

    /************************** PUBLIC CLASSES **************************/

    /*
    * This class represents a result of evaluation of a "simple expression part" (if it's a field or static value) or evaluation of the 2 "simple expression parts" using an operator in between
     */
    public class ExpressionEvaluationResult{
        public Object value {get; private set;}
        public String type {get; private set;} //one of the "DATA_TYPES" values

        public ExpressionEvaluationResult(Object value, String type){
            if (value != null){
                if (String.isBlank(type)) throw new SoftValidationFormulaExpressionEvaluateException('type is not provided.');
                if (!DATA_TYPES.contains(type)) throw new SoftValidationFormulaExpressionEvaluateException('unsupported type - "' + type + '".');

                this.value = value;
                this.type = type;
            }
        }
    }

    /*
    * This interface ensures that target DataSource Object has "get" method, which returns "DataSourceObjectGetValueResult"
    * Is needed in cases, when a Custom Formula needs to be run against a custom Object - not an SObject.
    * Property name has the same requirements as an SObject Field Name, i.e. it should be alpha-numeric with only '.' and '_' allowed as special characters.
     */
    public interface IDataSourceObject {
        DataSourceObjectGetValueResult get(String propertyName);
    }

    /*
    * Helper class, which describes what properties should IDataSourceObject.get() method return.
    * Is needed in cases, when a Custom Formula needs to be run against a custom Object - not an SObject.
     */
    public class DataSourceObjectGetValueResult{
        public Object value {get; private set;}
        public String type {get; private set;} //one of the "DATA_TYPES" values

        public DataSourceObjectGetValueResult(Object value, String type){
            this.value = value;
            this.type = type;

            if (value != null){
                if (String.isBlank(type)) throw new SoftValidationFormulaExpressionEvaluateException('type is not provided.');
                if (!DATA_TYPES.contains(type)) throw new SoftValidationFormulaExpressionEvaluateException('unsupported type - "' + type + '".');
            }
            else{
                this.type = null;
            }
        }
    }

    /*
    * Generic class which implements IDataSourceObject and accepts a Map<String, DataSourceObjectGetValueResult> as input data
    * Can be used instead of SObject, when evaluating formulas
     */
    public class DataSourceObjectGeneric implements IDataSourceObject{
        private Map<String, DataSourceObjectGetValueResult> data {get; set;}

        public DataSourceObjectGeneric(Map<String, DataSourceObjectGetValueResult> data){
            this.data = data;
        }

        public DataSourceObjectGetValueResult get(String propertyName){
            return this.data.get(propertyName);
        }
    }

    public class SoftValidationFormulaExpressionParseException extends Exception {}
    public class SoftValidationFormulaExpressionEvaluateException extends Exception {}

    /************************** FUNCTION CLASSES **************************/

    /*
    * Abstract class, which represents a "function" and implements a number of generic methods.
    * This class and all its child classes must be public in order "Type.forName" could create an instance of a function (Type.forName does not see private classes).
     */
    public abstract class AbstractFunction implements IExpression{
        private String fnBodyString {get; set;}
        private List<Expression> fnParams {get; set;}

        /*
        * Abstract method. Must be implemented in the child class.
        * Returns current function name.
         */
        public abstract String getFnName();

        /*
        * Abstract method, must be implemented in the child class.
        * Inits function instance and parses given expression. This method must be manually called after creating an instance of a function.
        * Reason of why a constructor cannot be used here is Type.forName method, which requires a constructor without parameters.
         */
        public abstract void init(String fnBodyString);

        /*
        * Abstract IExpression interface method. Must be implemented in the child class.
        * Calculates value for this function and returns value + type as ExpressionEvaluationResult object.
         */
        public abstract ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog);

        /*
        * IExpression interface method.
        * Populates given @fieldsForQuery parameter with list of fields (for SOQL query), grouped by SObject Name.
        * If it's not a special object, where we know its name in advance, the Object Name will be "PRIMARY"
        * Map key - SObject Name
        * Map value - Set of fields
         */
        public virtual void getFieldsForQuery(Map<String, Set<String>> fieldsForQuery){
            if (this.fnParams != null){
                for (Expression fnParam : this.fnParams){
                    fnParam.getFieldsForQuery(fieldsForQuery);
                }
            }
        }

        /*
        * IExpression interface method.
        * Can be used for troubleshooting or analyzing how the passed expression was parsed
         */
        public virtual void getParsingResults(Map<String, Object> results){
            results.put('type', 'FUNCTION');
            results.put('functionName', this.getFnName());
            results.put('functionRawBody', this.fnBodyString);

            if (this.fnParams != null){
                for (Integer i = 0; i < this.fnParams.size(); i++){
                    Expression fnParam = this.fnParams.get(i);

                    Map<String, Object> fnParamParsingResults = new Map<String, Object>();
                    fnParam.getParsingResults(fnParamParsingResults);
                    results.put('param' + (i + 1), fnParamParsingResults);
                }
            }
        }

        /*
        * This method tries to split a function's raw string (all between '(' and ')' characters) into the input parameters.
         */
        private List<String> parseFnBodyString(String fnBodyString){
            List<String> fnParams = new List<String>();
            if (String.isBlank(fnBodyString)) return fnParams;

            //before splitting string by comma we need temporarily get rid of all text literals and other expressions in round brackets.
            //starting with text literals:
            Integer textLiteralIndex = 0;
            Map<String, String> textLiteralByMergeField = new Map<String, String>();
            while (true){
                Integer openingQuoteIndex = fnBodyString.indexOf('"');

                if (openingQuoteIndex == -1){
                    break;
                }
                else{
                    Integer closingQuoteIndex = fnBodyString.indexOf('"', openingQuoteIndex + 1);

                    String mergeField = '{TXT-' + textLiteralIndex + '}';
                    String mergeFieldValue = fnBodyString.substring(openingQuoteIndex, closingQuoteIndex + 1);
                    textLiteralByMergeField.put(mergeField, mergeFieldValue);
                    textLiteralIndex++;

                    fnBodyString = fnBodyString.substring(0, openingQuoteIndex) + mergeField + fnBodyString.substring(closingQuoteIndex + 1);
                }
            }

            //next removing expressions:
            Integer expressionIndex = 0;
            Map<String, String> expressionByMergeField = new Map<String, String>();
            while (true){
                Integer openingBracketIndex = fnBodyString.indexOf('(');

                if (openingBracketIndex == -1){
                    break;
                }
                else{
                    Integer closingBracketIndex = SoftValidationUtils.findClosingCharacterIndex(fnBodyString.substring(openingBracketIndex + 1), '(', ')');

                    String mergeField = '{EXP-' + expressionIndex + '}';
                    String mergeFieldValue = fnBodyString.substring(openingBracketIndex, openingBracketIndex + closingBracketIndex + 2);
                    expressionByMergeField.put(mergeField, mergeFieldValue);
                    expressionIndex++;

                    fnBodyString = fnBodyString.substring(0, openingBracketIndex) + mergeField + fnBodyString.substring(openingBracketIndex + closingBracketIndex + 2);
                }
            }

            //now we can safely split the function body by comma and get function parameters
            fnParams = fnBodyString.split(',');

            //finally we need to restore all removed expressions and literals
            for (Integer i = 0; i < fnParams.size(); i++){
                String fnParam = fnParams.get(i).trim();

                //1st expressions
                for (String expMergeField : expressionByMergeField.keySet()){
                    fnParam = fnParam.replace(expMergeField, expressionByMergeField.get(expMergeField));
                }

                //last - literals
                for (String txtMergeField : textLiteralByMergeField.keySet()){
                    fnParam = fnParam.replace(txtMergeField, textLiteralByMergeField.get(txtMergeField));
                }

                fnParams.set(i, fnParam);
            }

            return fnParams;
        }

        /*
        * Generic helper method, which ensures that given number of input parameters matches the expected number of parameters.
         */
        private void assertParamsCount(Integer expectedParamsCount, Integer actualParamsCount){
            if (expectedParamsCount != actualParamsCount){
                throw new SoftValidationFormulaExpressionParseException('"' + this.getFnName() + '" function parameters number mismatch. Expected "' + expectedParamsCount + '" parameter(s), actual number - "' + actualParamsCount + '".');
            }
        }

        /*
        * Generic helper method, which puts function evaluation results into the log
         */
        private void updateLogWithEvaluationResults(ExpressionEvaluationResult evaluationResult, List<String> evaluationLog){
            if (evaluationLog != null){
                evaluationLog.add('FUNCTION (' + this.getFnName() + '): [' + this.fnBodyString + ']');
                evaluationLog.add('EVALUATION RESULT: [' + evaluationResult.value + ']:' + evaluationResult.type);
            }
        }

        /*
        * Iterates over the function's input parameters and evaluates them.
         */
        private List<ExpressionEvaluationResult> evaluateFnParams(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            List<ExpressionEvaluationResult> evaluationResults;

            if (this.fnParams != null){
                evaluationResults = new List<ExpressionEvaluationResult>();

                for (Integer i = 0; i < this.fnParams.size(); i++){
                    Expression fnParam = this.fnParams.get(i);

                    ExpressionEvaluationResult fnParamEvaluationResult = fnParam.evaluate(dataSourceObject, fieldValueCache, params, evaluationLog);
                    evaluationResults.add(fnParamEvaluationResult);
                }
            }

            return evaluationResults;
        }

        /*
        * Helper method to check if input parameter type is valid. Otherwise an exception will be thrown.
         */
        private void validateFnParamType(ExpressionEvaluationResult resultToValidate, Integer fnParamNum, Set<String> expectedTypes){
            if (resultToValidate.value != null) {
                if (!expectedTypes.contains(resultToValidate.type)) {
                    String expectedTypesStr = String.join(new List<String>(expectedTypes), '/');
                    throw new SoftValidationFormulaExpressionEvaluateException('input parameter #' + fnParamNum + ' type mismatch for "' + this.getFnName() + '" function. Expected type - ' + expectedTypesStr + ', actual type - ' + resultToValidate.type + '.');
                }
            }
        }
    }

    /************************** MATH FUNCTIONS **************************/

    /*
    * Name: VALUE
    * Return type: INTEGER/DECIMAL
    * Expected parameters: 1 - text to convert
     */
    public class VALUE_Function extends AbstractFunction {
        public override String getFnName(){return 'VALUE';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(1, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);

            String textNumber = (String) param1EvaluationResult.value;

            if (textNumber == null){
                evaluationResult = new ExpressionEvaluationResult(null, null);
            }
            else{
                if (String.isBlank(textNumber)) textNumber = '0';

                try{
                    Integer val = Integer.valueOf(textNumber);
                    evaluationResult = new ExpressionEvaluationResult(val, 'INTEGER');
                }
                catch(Exception ex){}

                if (evaluationResult == null){
                    try{
                        Decimal val = Decimal.valueOf(textNumber);
                        evaluationResult = new ExpressionEvaluationResult(val, 'DECIMAL');
                    }
                    catch(Exception ex){}
                }
            }

            if (evaluationResult == null){
                //throw new SoftValidationFormulaExpressionEvaluateException("' + this.getFnName() + '" function could not convert given string to a number. "' + textNumber + '" is not a valid number.');
                evaluationResult = new ExpressionEvaluationResult(null, null);
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);
            this.validateFnParamType(param1EvaluationResult, 1, new Set<String>{'STRING'});
        }
    }

    /*
    * Name: ROUND
    * Return type: INTEGER/DECIMAL
    * Expected parameters: 2 - 1) number to round, 2) scale
     */
    public class ROUND_Function extends AbstractFunction {
        public override String getFnName(){return 'ROUND';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(2, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);
            ExpressionEvaluationResult param2EvaluationResult = evaluationResults.get(1);

            if (param1EvaluationResult.value == null || param2EvaluationResult.value == null){
                evaluationResult = new ExpressionEvaluationResult(null, null);
            }
            else{
                if (param1EvaluationResult.type == 'INTEGER'){
                    evaluationResult = new ExpressionEvaluationResult(param1EvaluationResult.value, 'INTEGER');
                }
                else{
                    Decimal decimalVal = (Decimal) param1EvaluationResult.value;
                    Integer scale = (Integer) param2EvaluationResult.value;

                    if (scale == 0){
                        evaluationResult = new ExpressionEvaluationResult((Integer) decimalVal.round(), 'INTEGER');
                    }
                    else{
                        evaluationResult = new ExpressionEvaluationResult(decimalVal.setScale(scale), 'DECIMAL');
                    }
                }
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);
            ExpressionEvaluationResult param2EvaluationResult = evaluationResults.get(1);

            if (param1EvaluationResult.value != null){
                this.validateFnParamType(param1EvaluationResult, 1, new Set<String>{'DECIMAL', 'INTEGER'});

                if (param2EvaluationResult.value != null){
                    this.validateFnParamType(param2EvaluationResult, 2, new Set<String>{'INTEGER'});

                    Integer scale = (Integer) param2EvaluationResult.value;
                    if (scale < -33 || scale > 33) throw new SoftValidationFormulaExpressionEvaluateException('input parameter #2 value for "' + this.getFnName() + '" function is not valid. The value of scale must be between –33 and 33.');
                }
            }
        }
    }

    /*
    * Name: TRUNC
    * Return type: INTEGER
    * Expected parameters: 1 - number
     */
    public class TRUNC_Function extends AbstractFunction {
        public override String getFnName(){return 'TRUNC';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(1, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);

            if (param1EvaluationResult.value == null){
                evaluationResult = new ExpressionEvaluationResult(null, null);
            }
            else{
                if (param1EvaluationResult.type == 'INTEGER'){
                    evaluationResult = new ExpressionEvaluationResult(param1EvaluationResult.value, 'INTEGER');
                }
                else{
                    Decimal paramVal = (Decimal) param1EvaluationResult.value;
                    Integer resultVal = (Integer) (paramVal >= 0 ? Math.floor(paramVal) : Math.ceil(paramVal));

                    evaluationResult = new ExpressionEvaluationResult(resultVal, 'INTEGER');
                }
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);
            this.validateFnParamType(param1EvaluationResult, 1, new Set<String>{'DECIMAL', 'INTEGER'});
        }
    }

    /************************** DATE AND TIME FUNCTIONS **************************/

    /*
    * Name: TODAY
    * Return type: DATE
    * Expected parameters: none
     */
    public class TODAY_Function extends AbstractFunction {
        public override String getFnName(){return 'TODAY';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(0, fnLiteralParams.size());
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult = new ExpressionEvaluationResult(Date.today(), 'DATE');
            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }
    }

    /*
    * Name: NOW
    * Return type: DATETIME
    * Expected parameters: none
     */
    public class NOW_Function extends AbstractFunction {
        public override String getFnName(){return 'NOW';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(0, fnLiteralParams.size());
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult = new ExpressionEvaluationResult(Datetime.now(), 'DATETIME');
            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }
    }

    /*
    * Name: DATE
    * Return type: DATE
    * Expected parameters: 3 - 1) year, 2) month, 3) day
     */
    public class DATE_Function extends AbstractFunction {
        public override String getFnName(){return 'DATE';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(3, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            Integer year = (Integer) evaluationResults.get(0).value;
            Integer month = (Integer) evaluationResults.get(1).value;
            Integer day = (Integer) evaluationResults.get(2).value;

            try{
                Date dateVal = Date.newInstance(year, month, day);
                evaluationResult = new ExpressionEvaluationResult(dateVal, 'DATE');
            }
            catch(Exception ex){
                evaluationResult = new ExpressionEvaluationResult(null, null);
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            for (Integer i = 0; i < evaluationResults.size(); i++){
                ExpressionEvaluationResult paramEvaluationResult = evaluationResults.get(i);
                this.validateFnParamType(paramEvaluationResult, i + 1, new Set<String>{'INTEGER'});
            }
        }
    }

    /*
    * Name: DATEVALUE
    * Return type: DATE
    * Expected parameters: 1 - datetime or string in format "2005-11-15"
     */
    public class DATEVALUE_Function extends AbstractFunction {
        public override String getFnName(){return 'DATEVALUE';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(1, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult paramEvaluationResult = evaluationResults.get(0);

            if (paramEvaluationResult.type == 'DATE'){
                evaluationResult = new ExpressionEvaluationResult(paramEvaluationResult.value, 'DATE');
            }
            else if (paramEvaluationResult.type == 'DATETIME'){
                Datetime datetimeVal = (Datetime) paramEvaluationResult.value;
                evaluationResult = new ExpressionEvaluationResult(datetimeVal.date(), 'DATE');
            }
            else{
                try{
                    String stringVal = (String) paramEvaluationResult.value;
                    Date dateVal = Date.valueOf(stringVal);
                    evaluationResult = new ExpressionEvaluationResult(dateVal, 'DATE');
                }
                catch(Exception ex){
                    evaluationResult = new ExpressionEvaluationResult(null, null);
                }
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            ExpressionEvaluationResult paramEvaluationResult = evaluationResults.get(0);
            this.validateFnParamType(paramEvaluationResult, 1, new Set<String>{'DATETIME', 'DATE', 'STRING'});
        }
    }

    /*
    * Name: DATETIMEVALUE
    * Return type: DATETIME
    * Expected parameters: 1 - date or string in format "2005-11-15 17:00:00"
     */
    public class DATETIMEVALUE_Function extends AbstractFunction {
        public override String getFnName(){return 'DATETIMEVALUE';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(1, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult paramEvaluationResult = evaluationResults.get(0);

            if (paramEvaluationResult.type == 'DATETIME'){
                evaluationResult = new ExpressionEvaluationResult(paramEvaluationResult.value, 'DATETIME');
            }
            else if (paramEvaluationResult.type == 'DATE'){
                Date dateVal = (Date) paramEvaluationResult.value;
                evaluationResult = new ExpressionEvaluationResult(Datetime.newInstance(dateVal, Time.newInstance(0, 0, 0, 0)), 'DATETIME');
            }
            else{
                try{
                    String stringVal = (String) paramEvaluationResult.value;
                    Datetime datetimeVal = Datetime.valueOf(stringVal);
                    evaluationResult = new ExpressionEvaluationResult(datetimeVal, 'DATETIME');
                }
                catch(Exception ex){
                    evaluationResult = new ExpressionEvaluationResult(null, null);
                }
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            ExpressionEvaluationResult paramEvaluationResult = evaluationResults.get(0);
            this.validateFnParamType(paramEvaluationResult, 1, new Set<String>{'DATE', 'DATETIME', 'STRING'});
        }
    }

    /*
    * Abstract function that normally requires a single input parameter of date/datetime type and does something simple with it, like finding year/month/day, etc.
    * Return type: ANY
    * Expected parameters: 1 - date or datetime
     */
    public abstract class AbstractSimpleDatetimeFunction extends AbstractFunction {
        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(1, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult paramEvaluationResult = evaluationResults.get(0);

            if (paramEvaluationResult.value == null){
                evaluationResult = new ExpressionEvaluationResult(null, null);
            }
            else if (paramEvaluationResult.type == 'DATETIME'){
                Datetime datetimeVal = (Datetime) paramEvaluationResult.value;

                switch on this.getFnName(){
                    when 'YEAR'{
                        evaluationResult = new ExpressionEvaluationResult(datetimeVal.year(), 'INTEGER');
                    }
                    when 'MONTH' {
                        evaluationResult = new ExpressionEvaluationResult(datetimeVal.month(), 'INTEGER');
                    }
                    when 'DAY' {
                        evaluationResult = new ExpressionEvaluationResult(datetimeVal.day(), 'INTEGER');
                    }
                    when 'HOUR' {
                        evaluationResult = new ExpressionEvaluationResult(datetimeVal.hour(), 'INTEGER');
                    }
                    when 'MINUTE' {
                        evaluationResult = new ExpressionEvaluationResult(datetimeVal.minute(), 'INTEGER');
                    }
                    when 'SECOND' {
                        evaluationResult = new ExpressionEvaluationResult(datetimeVal.second(), 'INTEGER');
                    }
                    when 'WEEKDAY' { //1 for Sunday, 2 for Monday, through 7 for Saturday
                        Integer weekDay = Integer.valueOf(datetimeVal.format('u')) + 1;
                        if (weekDay > 7) weekDay = 1;
                        evaluationResult = new ExpressionEvaluationResult(weekDay, 'INTEGER');
                    }
                    when else{
                        throw new SoftValidationFormulaExpressionEvaluateException('unsupported Function: "' + this.getFnName() + '"');
                    }
                }
            }
            else{
                Date dateVal = (Date) paramEvaluationResult.value;

                switch on this.getFnName(){
                    when 'YEAR'{
                        evaluationResult = new ExpressionEvaluationResult(dateVal.year(), 'INTEGER');
                    }
                    when 'MONTH' {
                        evaluationResult = new ExpressionEvaluationResult(dateVal.month(), 'INTEGER');
                    }
                    when 'DAY' {
                        evaluationResult = new ExpressionEvaluationResult(dateVal.day(), 'INTEGER');
                    }
                    when 'HOUR', 'MINUTE', 'SECOND' {
                        evaluationResult = new ExpressionEvaluationResult(0, 'INTEGER');
                    }
                    when 'WEEKDAY' { //1 for Sunday, 2 for Monday, through 7 for Saturday
                        Datetime datetimeVal = Datetime.newInstance(dateVal, Time.newInstance(0, 0, 0, 0));
                        Integer weekDay = Integer.valueOf(datetimeVal.format('u')) + 1;
                        if (weekDay > 7) weekDay = 1;
                        evaluationResult = new ExpressionEvaluationResult(weekDay, 'INTEGER');
                    }
                    when else{
                        throw new SoftValidationFormulaExpressionEvaluateException('unsupported Function: "' + this.getFnName() + '"');
                    }
                }
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            ExpressionEvaluationResult paramEvaluationResult = evaluationResults.get(0);
            this.validateFnParamType(paramEvaluationResult, 1, new Set<String>{'DATE', 'DATETIME'});
        }
    }

    //see description for AbstractSimpleDatetimeFunction class
    public class YEAR_Function extends AbstractSimpleDatetimeFunction {public override String getFnName() {return 'YEAR';}}
    public class MONTH_Function extends AbstractSimpleDatetimeFunction {public override String getFnName() {return 'MONTH';}}
    public class DAY_Function extends AbstractSimpleDatetimeFunction {public override String getFnName() {return 'DAY';}}
    public class HOUR_Function extends AbstractSimpleDatetimeFunction {public override String getFnName() {return 'HOUR';}}
    public class MINUTE_Function extends AbstractSimpleDatetimeFunction {public override String getFnName() {return 'MINUTE';}}
    public class SECOND_Function extends AbstractSimpleDatetimeFunction {public override String getFnName() {return 'SECOND';}}
    public class WEEKDAY_Function extends AbstractSimpleDatetimeFunction {public override String getFnName() {return 'WEEKDAY';}}

    /*
    * Name: ADDMONTHS
    * Return type: DATE/DATETIME
    * Expected parameters: 2 - 1) date/datetime 2) number
     */
    public class ADDMONTHS_Function extends AbstractFunction {
        public override String getFnName(){return 'ADDMONTHS';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(2, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);
            ExpressionEvaluationResult param2EvaluationResult = evaluationResults.get(1);

            if (param1EvaluationResult.value == null || param2EvaluationResult.value == null){
                evaluationResult = new ExpressionEvaluationResult(null, null);
            }
            else if (param1EvaluationResult.type == 'DATETIME'){
                Datetime datetimeVal = (Datetime) param1EvaluationResult.value;
                Integer monthsToAdd = (Integer) param2EvaluationResult.value;

                evaluationResult = new ExpressionEvaluationResult(datetimeVal.addMonths(monthsToAdd), 'DATETIME');
            }
            else {
                Date dateVal = (Date) param1EvaluationResult.value;
                Integer monthsToAdd = (Integer) param2EvaluationResult.value;

                evaluationResult = new ExpressionEvaluationResult(dateVal.addMonths(monthsToAdd), 'DATE');
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            this.validateFnParamType(evaluationResults.get(0), 1, new Set<String>{'DATE', 'DATETIME'});
            this.validateFnParamType(evaluationResults.get(1), 2, new Set<String>{'INTEGER'});
        }
    }

    /************************** TEXT FUNCTIONS **************************/

    /*
    * Name: TEXT
    * Return type: STRING
    * Expected parameters: 1 - object to convert into a text
     */
    public class TEXT_Function extends AbstractFunction {
        public override String getFnName(){return 'TEXT';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(1, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            ExpressionEvaluationResult paramEvaluationResult = evaluationResults.get(0);
            evaluationResult = new ExpressionEvaluationResult(String.valueOf(paramEvaluationResult.value), 'STRING');

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }
    }

    /*
    * Abstract function that normally requires a single input parameter of string type and does something simple with it, like getting length, trimming, etc.
    * Return type: ANY
    * Expected parameters: 1 - string
     */
    public abstract class AbstractSimpleTextFunction extends AbstractFunction {
        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);

            switch on this.getFnName(){
                when 'LEFT', 'RIGHT'{
                    this.assertParamsCount(2, fnLiteralParams.size());
                }
                when 'MID'{
                    this.assertParamsCount(3, fnLiteralParams.size());
                }
                when else{
                    this.assertParamsCount(1, fnLiteralParams.size());
                }
            }

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);

            if (param1EvaluationResult.value == null){
                evaluationResult = new ExpressionEvaluationResult(null, null);
            }
            else{
                String stringVal = (String) param1EvaluationResult.value;

                switch on this.getFnName(){
                    when 'LOWER'{
                        evaluationResult = new ExpressionEvaluationResult(stringVal.toLowerCase(), 'STRING');
                    }
                    when 'UPPER'{
                        evaluationResult = new ExpressionEvaluationResult(stringVal.toUpperCase(), 'STRING');
                    }
                    when 'TRIM'{
                        evaluationResult = new ExpressionEvaluationResult(stringVal.trim(), 'STRING');
                    }
                    when 'LEN'{
                        evaluationResult = new ExpressionEvaluationResult(stringVal.length(), 'INTEGER');
                    }
                    when 'LEFT', 'RIGHT'{
                        ExpressionEvaluationResult param2EvaluationResult = evaluationResults.get(1);

                        try{
                            Integer numChars = (Integer) param2EvaluationResult.value;

                            String resultString = (this.getFnName() == 'LEFT' ? stringVal.left(numChars) : stringVal.right(numChars));
                            evaluationResult = new ExpressionEvaluationResult(resultString, 'STRING');
                        }
                        catch(Exception ex){
                            evaluationResult = new ExpressionEvaluationResult(null, null);
                        }
                    }
                    when 'MID'{
                        ExpressionEvaluationResult param2EvaluationResult = evaluationResults.get(1);
                        ExpressionEvaluationResult param3EvaluationResult = evaluationResults.get(2);

                        try{
                            Integer startIndex = (Integer) param2EvaluationResult.value;
                            Integer numChars = (Integer) param3EvaluationResult.value;

                            String resultString = (startIndex + numChars >= stringVal.length() ? stringVal.substring(startIndex) : stringVal.substring(startIndex, startIndex + numChars));
                            evaluationResult = new ExpressionEvaluationResult(resultString, 'STRING');
                        }
                        catch(Exception ex){
                            evaluationResult = new ExpressionEvaluationResult(null, null);
                        }
                    }
                    when else{
                        throw new SoftValidationFormulaExpressionEvaluateException('unsupported Function: "' + this.getFnName() + '"');
                    }
                }
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            this.validateFnParamType(evaluationResults.get(0), 1, new Set<String>{'STRING'});

            switch on this.getFnName(){
                when 'LEFT', 'RIGHT', 'MID'{
                    for (Integer i = 1; i < evaluationResults.size(); i++){
                        this.validateFnParamType(evaluationResults.get(i), i + 1, new Set<String>{'INTEGER'});
                    }
                }
            }
        }
    }

    //see description for AbstractSimpleTextFunction class
    public class LOWER_Function extends AbstractSimpleTextFunction {public override String getFnName() {return 'LOWER';}}
    public class UPPER_Function extends AbstractSimpleTextFunction {public override String getFnName() {return 'UPPER';}}
    public class TRIM_Function extends AbstractSimpleTextFunction {public override String getFnName() {return 'TRIM';}}
    public class LEN_Function extends AbstractSimpleTextFunction {public override String getFnName() {return 'LEN';}}
    public class LEFT_Function extends AbstractSimpleTextFunction {public override String getFnName() {return 'LEFT';}}
    public class RIGHT_Function extends AbstractSimpleTextFunction {public override String getFnName() {return 'RIGHT';}}
    public class MID_Function extends AbstractSimpleTextFunction {public override String getFnName() {return 'MID';}}

    /************************** LOGICAL FUNCTIONS **************************/

    /*
    * Name: BLANKVALUE
    * Return type: depends on left or right expression (whatever was picked up)
    * Expected parameters: 2 - 1) expression, 2) substitute_expression
     */
    public class BLANKVALUE_Function extends AbstractFunction {
        public override String getFnName(){return 'BLANKVALUE';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(2, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);
            ExpressionEvaluationResult param2EvaluationResult = evaluationResults.get(1);

            Boolean param1IsBlank = (param1EvaluationResult.value == null);
            if (param1EvaluationResult.type == 'STRING'){
                param1IsBlank = String.isBlank((String) param1EvaluationResult.value);
            }

            evaluationResult = (param1IsBlank ? param2EvaluationResult : param1EvaluationResult);
            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }
    }

    /*
    * Name: ISBLANK
    * Return type: BOOLEAN
    * Expected parameters: 1 - expression
     */
    public class ISBLANK_Function extends AbstractFunction {
        public override String getFnName(){return 'ISBLANK';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(1, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);

            Boolean param1IsBlank = (param1EvaluationResult.value == null);
            if (param1EvaluationResult.type == 'STRING'){
                param1IsBlank = String.isBlank((String) param1EvaluationResult.value);
            }

            evaluationResult = new ExpressionEvaluationResult(param1IsBlank, 'BOOLEAN');
            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }
    }

    /*
    * Abstract function that normally requires a number of input parameter of boolean type
    * Return type: BOOLEAN
    * Expected parameters: minimum 1 - boolean
     */
    public abstract class AbstractSimpleLogicFunction extends AbstractFunction {
        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);

            switch on this.getFnName(){
                when 'NOT'{
                    this.assertParamsCount(1, fnLiteralParams.size());
                }
                when else{
                    if (fnLiteralParams.size() == 0) throw new SoftValidationFormulaExpressionParseException('"' + this.getFnName() + '" function parameters number mismatch. Expected minimum "1" parameter, actual number - "0".');
                }
            }

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            Boolean evaluationResultBoolean = false;
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            switch on this.getFnName(){
                when 'NOT'{
                    ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);

                    if (param1EvaluationResult.value != null){
                        evaluationResultBoolean = !((Boolean) param1EvaluationResult.value);
                    }
                }
                when 'AND'{
                    Boolean result = true;

                    for (ExpressionEvaluationResult paramEvaluationResult : evaluationResults){
                        if (paramEvaluationResult.value == null || ((Boolean) paramEvaluationResult.value) == false){
                            result = false;
                            break;
                        }
                    }

                    evaluationResultBoolean = result;
                }
                when 'OR'{
                    Boolean result = false;

                    for (ExpressionEvaluationResult paramEvaluationResult : evaluationResults){
                        if (paramEvaluationResult.value != null && ((Boolean) paramEvaluationResult.value) == true){
                            result = true;
                            break;
                        }
                    }

                    evaluationResultBoolean = result;
                }
            }

            evaluationResult = new ExpressionEvaluationResult(evaluationResultBoolean, 'BOOLEAN');
            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            for (Integer i = 0; i < evaluationResults.size(); i++){
                ExpressionEvaluationResult evaluationResult = evaluationResults.get(i);

                this.validateFnParamType(evaluationResult, i + 1, new Set<String>{'BOOLEAN'});
            }
        }
    }

    //see description for AbstractSimpleLogicFunction class
    public class AND_Function extends AbstractSimpleLogicFunction {public override String getFnName() {return 'AND';}}
    public class OR_Function extends AbstractSimpleLogicFunction {public override String getFnName() {return 'OR';}}
    public class NOT_Function extends AbstractSimpleLogicFunction {public override String getFnName() {return 'NOT';}}

    /*
    * Name: CASE
    * Return type: ANY
    * Expected parameters: minimum 4, 1 - expression, 2 - value1, 3 - result1, result_else
     */
    public class CASE_Function extends AbstractFunction {
        public override String getFnName(){return 'CASE';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            if (fnLiteralParams.size() < 4) throw new SoftValidationFormulaExpressionParseException('"' + this.getFnName() + '" function parameters number mismatch. Expected minimum "4" parameters, actual number - "' + fnLiteralParams.size() + '".');
            if (Math.mod(fnLiteralParams.size(), 2) > 0) throw new SoftValidationFormulaExpressionParseException('"' + this.getFnName() + '" function parameters number mismatch. Expected "' + (fnLiteralParams.size() - 1) + '" parameters, actual number - "' + fnLiteralParams.size() + '".');

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            ExpressionEvaluationResult expressionEvaluationResult = evaluationResults.get(0);
            ExpressionEvaluationResult elseEvaluationResult = evaluationResults.get(evaluationResults.size() - 1);

            for (Integer i = 1; i < evaluationResults.size() - 1; i++){
                if (Math.mod(i, 2) == 0) continue;

                ExpressionEvaluationResult valueEvaluationResult = evaluationResults.get(i);
                ExpressionEvaluationResult resultEvaluationResult = evaluationResults.get(i + 1);

                if (equals(expressionEvaluationResult, valueEvaluationResult)){
                    evaluationResult = new ExpressionEvaluationResult(resultEvaluationResult.value, resultEvaluationResult.type);

                    if (evaluationLog != null) evaluationLog.add('FUNCTION (' + this.getFnName() + '): USING VALUE+RESULT PAIR #' + (i == 1 ? 1 : i - 1));
                    break;
                }
            }

            if (evaluationResult == null){
                evaluationResult = new ExpressionEvaluationResult(elseEvaluationResult.value, elseEvaluationResult.type);
                if (evaluationLog != null) evaluationLog.add('FUNCTION (' + this.getFnName() + '): USING ELSE');
            }

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private Boolean equals(ExpressionEvaluationResult leftExpression, ExpressionEvaluationResult rightExpression){
            Boolean result = false;

            if (leftExpression.value != null && rightExpression.value != null){
                Boolean typeAreCompatible = (leftExpression.type == rightExpression.type);

                if (!typeAreCompatible){
                    Set<String> compatibleTypes = COMPATIBLE_TYPES.get(leftExpression.type);
                    if (compatibleTypes != null) typeAreCompatible = compatibleTypes.contains(rightExpression.type);
                }

                if (typeAreCompatible == false) throwTypeMismatchException(leftExpression.type, rightExpression.type, 'EQUALS (CASE FN)');

                result = leftExpression.value == rightExpression.value;
            }
            else{
                result = (leftExpression.value == rightExpression.value);
            }

            return result;
        }
    }

    /*
    * Name: IF
    * Return type: ANY
    * Expected parameters: 3, 1 - logical_test, 2 - value_if_true, 3 - value_if_false
     */
    public class IF_Function extends AbstractFunction {
        public override String getFnName(){return 'IF';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(3, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult logicalEvaluationResult = evaluationResults.get(0);
            ExpressionEvaluationResult valueIfTrueEvaluationResult = evaluationResults.get(1);
            ExpressionEvaluationResult valueIfFalseLogicalEvaluationResult = evaluationResults.get(2);

            Boolean logicalExpressionIsTrue = (logicalEvaluationResult.value == true);
            ExpressionEvaluationResult valueToApplyEvaluationResult = (logicalExpressionIsTrue ? valueIfTrueEvaluationResult : valueIfFalseLogicalEvaluationResult);

            if (evaluationLog != null) evaluationLog.add('FUNCTION (' + this.getFnName() + '): USING ' + (logicalExpressionIsTrue ? 'VALUE_IF_TRUE' : 'VALUE_IF_FALSE'));

            evaluationResult = new ExpressionEvaluationResult(valueToApplyEvaluationResult.value, valueToApplyEvaluationResult.type);

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            this.validateFnParamType(evaluationResults.get(0), 1, new Set<String>{'BOOLEAN'});
        }
    }

    /*
    * Name: ISNUMBER
    * Return type: BOOLEAN
    * Expected parameters: 1 - string
     */
    public class ISNUMBER_Function extends AbstractFunction {
        public override String getFnName(){return 'ISNUMBER';}

        public override void init(String fnBodyString){
            this.fnBodyString = fnBodyString.trim();

            List<String> fnLiteralParams = this.parseFnBodyString(fnBodyString);
            this.assertParamsCount(1, fnLiteralParams.size());

            this.fnParams = new List<Expression>();

            for (String fnLiteralParam : fnLiteralParams){
                this.fnParams.add(new Expression(fnLiteralParam));
            }
        }

        public override ExpressionEvaluationResult evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params, List<String> evaluationLog){
            Boolean evaluationResultBoolean = false;
            ExpressionEvaluationResult evaluationResult;
            List<ExpressionEvaluationResult> evaluationResults = this.evaluateFnParams(dataSourceObject, fieldValueCache, params, evaluationLog);

            this.validateInputParameters(evaluationResults);

            ExpressionEvaluationResult param1EvaluationResult = evaluationResults.get(0);

            if (param1EvaluationResult.value != null){
                try{
                    Decimal val = Decimal.valueOf((String) param1EvaluationResult.value);
                    evaluationResultBoolean = true;
                }
                catch(Exception ex){}
            }

            evaluationResult = new ExpressionEvaluationResult(evaluationResultBoolean, 'BOOLEAN');

            this.updateLogWithEvaluationResults(evaluationResult, evaluationLog);

            return evaluationResult;
        }

        private void validateInputParameters(List<ExpressionEvaluationResult> evaluationResults){
            this.validateFnParamType(evaluationResults.get(0), 1, new Set<String>{'STRING'});
        }
    }
}