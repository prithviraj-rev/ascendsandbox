/******************************************************************************
// File Name:       SoftValidationCriterion
// Summary:         This class allows to evaluate a logical criterion, which consists of Left Expression, Operator and Right Expression and returns TRUE or FALSE.
//                  Supported expression types: see SoftValidationFormulaExpression class EXPRESSION_TYPES constant
//                  Supported data types: see SoftValidationFormulaExpression class DATA_TYPES constant
//                  Supported operators: see OPERATORS constant
// Test Class:      SoftValidationCriterionTest
// Created On:      07/29/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 07/29/2021 - created class
*******************************************************************************/

public without sharing class SoftValidationCriterion {
    private static final Set<Type> CUSTOM_EXCEPTION_TYPES = new Set<Type>{
        SoftValidationFormulaExpression.SoftValidationFormulaExpressionParseException.class,
        SoftValidationFormulaExpression.SoftValidationFormulaExpressionEvaluateException.class
    };

    private static final Set<String> OPERATORS = new Set<String>{
        '=', '==', 'EQUALS',
        '!=', '<>', 'NOT EQUAL TO',
        '<', 'LESS THAN',
        '>', 'GREATER THAN',
        '<=', 'LESS OR EQUAL',
        '>=', 'GREATER OR EQUAL',
        'CONTAINS', 'DOES NOT CONTAIN', 'STARTS WITH', 'ENDS WITH',
        'INCLUDES', 'DOES NOT INCLUDE'
    };

    private static final Map<String, String> OPERATOR_SHORTCUT = new Map<String, String>{
        'EQUALS' => '=',
        'NOT EQUAL TO' => '!=',
        'LESS THAN' => '<',
        'GREATER THAN' => '>',
        'LESS OR EQUAL' => '<=',
        'GREATER OR EQUAL' => '>='
    };

    private static final Map<String, Set<String>> COMPATIBLE_TYPES = new Map<String, Set<String>>{
        'INTEGER' => new Set<String>{'INTEGER', 'DECIMAL'},
        'DECIMAL' => new Set<String>{'DECIMAL', 'INTEGER'},
        'DATE' => new Set<String>{'DATE', 'DATETIME'},
        'DATETIME' => new Set<String>{'DATETIME', 'DATE'}
    };


    public String leftExpressionType {get; private set;}
    public String leftExpressionString {get; private set;}
    public String operator {get; private set;}
    public String rightExpressionType {get; private set;}
    public String rightExpressionString {get; private set;}

    public SoftValidationFormulaExpression leftExpression {get; private set;}
    public SoftValidationFormulaExpression rightExpression {get; private set;}
    public Boolean evaluationResult {get; private set;}

    private List<String> evaluationLog {get; set;}

    /*
    * Constructor, which inits criterion and parses given expressions right away.
     */
    public SoftValidationCriterion(String leftExpressionType, String leftExpressionString, String operator, String rightExpressionType, String rightExpressionString){
        this.validateInputParams(leftExpressionType, leftExpressionString, operator, rightExpressionType, rightExpressionString);

        this.leftExpressionType = leftExpressionType.toUpperCase();
        this.leftExpressionString = leftExpressionString;
        this.operator = operator.toUpperCase();
        this.rightExpressionType = rightExpressionType.toUpperCase();
        this.rightExpressionString = rightExpressionString;

        this.leftExpression = this.getExpressionInstance(this.leftExpressionString, 'left', this.leftExpressionType);
        this.rightExpression = this.getExpressionInstance(this.rightExpressionString, 'right', this.rightExpressionType);
    }

    /*
    * Populates given @fieldsForQuery parameter with list of fields (for SOQL query), grouped by SObject Name.
    * If it's not a special object, where we know its name in advance, the Object Name will be "PRIMARY"
    * Map key - SObject Name
    * Map value - Set of fields
     */
    public void getFieldsForQuery(Map<String, Set<String>> fieldsForQuery){
        if (this.leftExpression == null || this.rightExpression == null) throw new SoftValidationCriterionParseException('criterion expressions are not parsed.');
        if (fieldsForQuery == null) return;

        this.leftExpression.getFieldsForQuery(fieldsForQuery);
        this.rightExpression.getFieldsForQuery(fieldsForQuery);
    }

    /*
    * Calculates left and right expressions, performs an action on results (based on given operator) and returns TRUE or FALSE.
    * @dataSourceObject - optional, can be an SObject or IDataSourceObject. If an expression references some fields/properties then a run-time error will occur if dataSourceObject is not provided.
    * @fieldValueCache - optional, key1 - Object Name (for context object "PRIMARY" is used), key2 - Field Name, value - [field value + type] (SoftValidationUtils.SoftValidationFieldValue object).
    * @params (not in use - reserved for future) - optional, arbitrary set of params. May, for example, contain data-source records for other subsidiary SObject types.
     */
    public Boolean evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params){
        if (this.leftExpression == null || this.rightExpression == null) throw new SoftValidationCriterionEvaluateException('criterion expressions are not parsed.');

        if (fieldValueCache == null) fieldValueCache = new Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>>();
        if (!fieldValueCache.containsKey('PRIMARY')) fieldValueCache.put('PRIMARY', new Map<String, SoftValidationUtils.SoftValidationFieldValue>());

        this.evaluationLog = new List<String>();

        SoftValidationFormulaExpression.ExpressionEvaluationResult leftEvaluationResult = this.evaluateExpression('left', this.leftExpression, dataSourceObject, fieldValueCache, params);
        SoftValidationFormulaExpression.ExpressionEvaluationResult rightEvaluationResult = this.evaluateExpression('right', this.rightExpression, dataSourceObject, fieldValueCache, params);
        this.evaluationResult = this.evaluateCriterion(leftEvaluationResult, rightEvaluationResult);

        return this.evaluationResult;
    }

    /*
    * helper method that can be used for troubleshooting or analyzing how the passed expression was parsed
     */
    public Map<String, String> getParsingResultsJSON(){
        if (this.leftExpression == null || this.rightExpression == null) throw new SoftValidationCriterionParseException('criterion expressions are not parsed.');

        return new Map<String, String>{
            'left' => this.leftExpression.getParsingResultsJSON(),
            'right' => this.rightExpression.getParsingResultsJSON()
        };
    }

    /*
    * helper method that can be used for troubleshooting or analyzing how the passed expression was evaluated
     */
    public Map<String, List<String>> getEvaluationLog(){
        if (this.leftExpression == null || this.rightExpression == null) throw new SoftValidationCriterionParseException('criterion expressions are not parsed.');

        return new Map<String, List<String>>{
            'left' => this.leftExpression.getEvaluationLog(),
            'right' => this.rightExpression.getEvaluationLog(),
            'own' => this.evaluationLog
        };
    }

    /*
    * Helper method, which ensures that all input parameters are provided and valid
     */
    private void validateInputParams(String leftExpressionType, String leftExpressionString, String operator, String rightExpressionType, String rightExpressionString){
        Set<String> supportedExpressionTypes = SoftValidationFormulaExpression.getSupportedExpressionTypes();

        if (String.isBlank(leftExpressionType)) throw new SoftValidationCriterionParseException('left expression type is not provided.');
        leftExpressionType = leftExpressionType.toUpperCase();
        if (!supportedExpressionTypes.contains(leftExpressionType)) throw new SoftValidationCriterionParseException('unsupported left expression type provided - "' + leftExpressionType + '".');

        if (String.isBlank(leftExpressionString)) throw new SoftValidationCriterionParseException('left expression is not provided.');

        if (String.isBlank(operator)) throw new SoftValidationCriterionParseException('operator is not provided.');
        operator = operator.toUpperCase();
        if (!OPERATORS.contains(operator)) throw new SoftValidationCriterionParseException('unsupported operator provided - "' + operator + '".');

        if (String.isBlank(rightExpressionType)) throw new SoftValidationCriterionParseException('right expression type is not provided.');
        rightExpressionType = rightExpressionType.toUpperCase();
        if (!supportedExpressionTypes.contains(rightExpressionType)) throw new SoftValidationCriterionParseException('unsupported right expression type provided - "' + rightExpressionType + '".');

        if (String.isBlank(rightExpressionString)) throw new SoftValidationCriterionParseException('right expression is not provided.');
    }

    /*
    * Creates and returns instance of SoftValidationFormulaExpression class, catches exceptions and re-throws them with adding info of expression type (left/right)
     */
    private SoftValidationFormulaExpression getExpressionInstance(String expressionString, String positionInCriterion, String expressionType){
        SoftValidationFormulaExpression expression;

        try{
            expression = new SoftValidationFormulaExpression(expressionString, expressionType);
        }
        catch(Exception ex){
            Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
            String errMsg = positionInCriterion + ' expression: ' + ex.getMessage();
            if (!isCustomException) errMsg += ', Stack String: ' + ex.getStackTraceString();

            throw new SoftValidationCriterionParseException(errMsg);
        }

        return expression;
    }

    /*
    * Evaluates given expression, catches exceptions and re-throws them with adding info of expression type (left/right)
    * @dataSourceObject, @fieldValueCache, @params - see description of the parent "evaluate" method
     */
    private SoftValidationFormulaExpression.ExpressionEvaluationResult evaluateExpression(String positionInCriterion, SoftValidationFormulaExpression expression, Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params){
        SoftValidationFormulaExpression.ExpressionEvaluationResult evaluationResult;

        try{
            evaluationResult = expression.evaluate(dataSourceObject, null, fieldValueCache, params);
        }
        catch(Exception ex){
            Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
            String errMsg = positionInCriterion + ' expression: ' + ex.getMessage();
            if (!isCustomException) errMsg += ', Stack String: ' + ex.getStackTraceString();

            throw new SoftValidationCriterionEvaluateException(errMsg);
        }

        return evaluationResult;
    }

    /*
    * Evaluates this Criterion using provided operator and returns TRUE/FALSE
     */
    private Boolean evaluateCriterion(SoftValidationFormulaExpression.ExpressionEvaluationResult leftEvaluationResult, SoftValidationFormulaExpression.ExpressionEvaluationResult rightEvaluationResult){
        Boolean evaluationResult = false;

        this.evaluationLog.add('LEFT EVALUATION RESULT: [' + leftEvaluationResult.value + ']:' + leftEvaluationResult.type);
        this.evaluationLog.add('OPERATOR: ' + this.operator);
        this.evaluationLog.add('RIGHT EVALUATION RESULT: [' + rightEvaluationResult.value + ']:' + rightEvaluationResult.type);

        switch on this.operator{
            when '=', '==', 'EQUALS', '!=', '<>', 'NOT EQUAL TO'{
                this.checkTypesCompatibility('equality', leftEvaluationResult, rightEvaluationResult);
                Boolean isEqualsOperator = (this.operator == '=' || this.operator == '==' || this.operator == 'EQUALS');

                if (leftEvaluationResult.value != null && rightEvaluationResult.value != null && leftEvaluationResult.type == 'STRING'){
                    String leftValue = (String) leftEvaluationResult.value;
                    String rightValue = String.valueOf(rightEvaluationResult.value);
                    evaluationResult = (isEqualsOperator
                        ? leftValue == rightValue
                        : leftValue != rightValue);
                }
                else{
                    evaluationResult = (isEqualsOperator
                        ? leftEvaluationResult.value == rightEvaluationResult.value
                        : leftEvaluationResult.value != rightEvaluationResult.value);
                }
            }
            when '<', 'LESS THAN', '>', 'GREATER THAN', '<=', 'LESS OR EQUAL', '>=', 'GREATER OR EQUAL'{
                this.checkTypesCompatibility('inequality', leftEvaluationResult, rightEvaluationResult);

                if (leftEvaluationResult.value != null && rightEvaluationResult.value != null){
                    switch on leftEvaluationResult.type{
                        when 'INTEGER', 'DECIMAL'{
                            Decimal leftValue = (Decimal) leftEvaluationResult.value;
                            Decimal rightValue = (Decimal) rightEvaluationResult.value;

                            switch on this.operator{
                                when '<', 'LESS THAN'{
                                    evaluationResult = (leftValue < rightValue);
                                }
                                when '>', 'GREATER THAN'{
                                    evaluationResult = (leftValue > rightValue);
                                }
                                when '<=', 'LESS OR EQUAL'{
                                    evaluationResult = (leftValue <= rightValue);
                                }
                                when '>=', 'GREATER OR EQUAL'{
                                    evaluationResult = (leftValue >= rightValue);
                                }
                            }
                        }
                        when 'DATE', 'DATETIME'{
                            Datetime leftValue = (Datetime) leftEvaluationResult.value;
                            Datetime rightValue = (Datetime) rightEvaluationResult.value;

                            switch on this.operator{
                                when '<', 'LESS THAN'{
                                    evaluationResult = (leftValue < rightValue);
                                }
                                when '>', 'GREATER THAN'{
                                    evaluationResult = (leftValue > rightValue);
                                }
                                when '<=', 'LESS OR EQUAL'{
                                    evaluationResult = (leftValue <= rightValue);
                                }
                                when '>=', 'GREATER OR EQUAL'{
                                    evaluationResult = (leftValue >= rightValue);
                                }
                            }
                        }
                    }
                }
            }
            when 'CONTAINS', 'DOES NOT CONTAIN', 'STARTS WITH', 'ENDS WITH', 'INCLUDES', 'DOES NOT INCLUDE'{
                this.checkTypesCompatibility('text', leftEvaluationResult, rightEvaluationResult);

                if (leftEvaluationResult.value != null && rightEvaluationResult.value != null){
                    String leftValue = (String) leftEvaluationResult.value;
                    String rightValue = String.valueOf(rightEvaluationResult.value);

                    switch on this.operator{
                        when 'CONTAINS', 'DOES NOT CONTAIN'{
                            Boolean containsSubStr = leftValue.containsIgnoreCase(rightValue);
                            evaluationResult = (this.operator == 'CONTAINS' ? containsSubStr : !containsSubStr);
                        }
                        when 'STARTS WITH', 'ENDS WITH'{
                            evaluationResult = (this.operator == 'STARTS WITH' ? leftValue.startsWithIgnoreCase(rightValue) : leftValue.endsWithIgnoreCase(rightValue));
                        }
                        when 'INCLUDES', 'DOES NOT INCLUDE'{
                            Set<String> leftValueOptions = new Set<String>(leftValue.split(';'));
                            Set<String> rightValueOptions = new Set<String>(rightValue.split(';'));

                            Boolean includes = leftValueOptions.containsAll(rightValueOptions);
                            evaluationResult = (this.operator == 'INCLUDES' ? includes : !includes);
                        }
                    }
                }
            }
        }

        this.evaluationLog.add('CRITERION EVALUATION RESULT: [' + evaluationResult + ']');

        return evaluationResult;
    }

    /*
    * Checks if data types are compatible with the operator and if not - throws an exception
     */
    private void checkTypesCompatibility(String operatorType, SoftValidationFormulaExpression.ExpressionEvaluationResult leftEvaluationResult, SoftValidationFormulaExpression.ExpressionEvaluationResult rightEvaluationResult){
        if (operatorType == 'equality'){
            if (leftEvaluationResult.value != null && rightEvaluationResult.value != null){
                if (leftEvaluationResult.type != rightEvaluationResult.type){
                    if (leftEvaluationResult.type != 'STRING'){ //whatever type on the right side will be converted to String
                        Boolean typeAreCompatible = false;
                        Set<String> compatibleTypes = COMPATIBLE_TYPES.get(leftEvaluationResult.type);
                        if (compatibleTypes != null) typeAreCompatible = compatibleTypes.contains(rightEvaluationResult.type);
                        if (!typeAreCompatible) throw new SoftValidationCriterionEvaluateException('types ' + leftEvaluationResult.type + ' & ' + rightEvaluationResult.type + ' are not compatible for operator "' + this.operator + '" .');
                    }
                }
            }
        }
        else if (operatorType == 'inequality'){
            if (leftEvaluationResult.value != null && rightEvaluationResult.value != null){
                Set<String> allowedTypes = new Set<String>{'INTEGER', 'DECIMAL', 'DATE', 'DATETIME'}; //not adding STRING intentionally, though inequality operators can be run against strings
                if (!allowedTypes.contains(leftEvaluationResult.type)) throw new SoftValidationCriterionEvaluateException('type ' + leftEvaluationResult.type + ' (left expression) is not allowed for operator "' + this.operator + '" .');
                if (!allowedTypes.contains(rightEvaluationResult.type)) throw new SoftValidationCriterionEvaluateException('type ' + rightEvaluationResult.type + ' (right expression) is not allowed for operator "' + this.operator + '" .');
                if (!COMPATIBLE_TYPES.get(leftEvaluationResult.type).contains(rightEvaluationResult.type)) throw new SoftValidationCriterionEvaluateException('types ' + leftEvaluationResult.type + ' & ' + rightEvaluationResult.type + ' are not compatible for operator "' + this.operator + '" .');
            }
        }
        else if (operatorType == 'text'){
            if (leftEvaluationResult.value != null && rightEvaluationResult.value != null){
                if (leftEvaluationResult.type != 'STRING') throw new SoftValidationCriterionEvaluateException('type ' + leftEvaluationResult.type + ' (left expression) is not allowed for operator "' + this.operator + '" .');

                //it probably makes more sense just to cast Right Expression Value to String, no matter what real data type is behind
                //if (rightEvaluationResult.type != 'STRING') throw new SoftValidationCriterionEvaluateException('type ' + rightEvaluationResult.type + ' (right expression) is not allowed for operator "' + this.operator + '" .');
            }
        }
    }

    /************************** PUBLIC STATIC METHODS **************************/

    /*
    * Returns short version for an operator (e.g. short version for "EQUALS" is "=")
     */
    public static String getOperatorShortcut(String operator){
        String operatorShortcut;

        if (String.isNotBlank(operator)){
            String operatorUpper = operator.toUpperCase();
            operatorShortcut = OPERATOR_SHORTCUT.get(operatorUpper);
        }

        return (String.isBlank(operatorShortcut) ? operator : operatorShortcut);
    }

    /************************** HELPER CLASSES **************************/

    public class SoftValidationCriterionParseException extends Exception {}
    public class SoftValidationCriterionEvaluateException extends Exception {}
}