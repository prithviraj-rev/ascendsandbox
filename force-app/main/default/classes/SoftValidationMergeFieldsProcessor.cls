/******************************************************************************
// File Name:       SoftValidationMergeFieldsProcessor
// Summary:         This class allows to parse given text, extract merge fields in it and then evaluate them
// Test Class:      SoftValidationMergeFieldsProcessorTest
// Created On:      10/26/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 10/26/2021 - created class
*******************************************************************************/

public without sharing class SoftValidationMergeFieldsProcessor {
    private static final Set<Type> CUSTOM_EXCEPTION_TYPES = new Set<Type>{
        SoftValidationFormulaExpression.SoftValidationFormulaExpressionParseException.class,
        SoftValidationFormulaExpression.SoftValidationFormulaExpressionEvaluateException.class
    };

    public String template {get; private set;}
    public Boolean isRichText {get; private set;}

    private List<Object> templateItems {get; set;} //String (text literals) or Integer (index of item in this.expressions list)
    private List<SoftValidationFormulaExpression> expressions {get; set;}
    private List<Object> expressionEvaluationResults {get; set;}

    /************************** PUBLIC METHODS **************************/

    /*
    * Constructor, which parses given template right away.
    * @isRichText - set it to "true" if value for @template is from a Rich Text field. In this case a merge field like '{!Name & "-test"}' will be escaped to 'Name & &quot;-test&quot;' by SF upon saving and code in this class will need to unescape it first - before evaluating an expression.
     */
    public SoftValidationMergeFieldsProcessor(String template, Boolean isRichText){
        if (String.isBlank(template)) throw new SoftValidationMergeFieldsProcessorParseException('template is not provided.');

        this.template = template;
        this.isRichText = isRichText;

        parseText();
    }

    /*
    * Populates given @fieldsForQuery parameter with list of fields (for SOQL query), grouped by SObject Name.
    * If it's not a special object, where we know its name in advance, the Object Name will be "PRIMARY"
    * Map key - SObject Name
    * Map value - Set of fields
     */
    public void getFieldsForQuery(Map<String, Set<String>> fieldsForQuery){
        if (this.expressions == null) throw new SoftValidationMergeFieldsProcessorParseException('template is not parsed.');
        if (fieldsForQuery == null) return;

        for (SoftValidationFormulaExpression expression : this.expressions){
            expression.getFieldsForQuery(fieldsForQuery);
        }
    }

    /*
    * Calculates expressions for all merge fields in the template and returns a string with all merge fields replaced with actual value.
    * @dataSourceObject - optional, can be an SObject or IDataSourceObject. If an expression references some fields/properties then a run-time error will occur if dataSourceObject is not provided.
    * @fieldValueCache - optional, key1 - Object Name (for context object "PRIMARY" is used), key2 - Field Name, value - [field value + type] (SoftValidationUtils.SoftValidationFieldValue object).
    * @params - optional, arbitrary set of params. Supports one parameter so far: "mergeFieldEvaluateOnError" with values
    *   1) "throwException" - if a run-time exception was thrown during evaluating an expression then this exception will bubble up
    *   2) "ignore" - (default) - if a run-time exception was thrown during evaluating an expression then merge field will be replaced with "{!#error}" and code will move to the next expression
     */
    public String evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params){
        if (this.expressions == null) throw new SoftValidationMergeFieldsProcessorParseException('template is not parsed.');

        if (fieldValueCache == null) fieldValueCache = new Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>>();
        if (!fieldValueCache.containsKey('PRIMARY')) fieldValueCache.put('PRIMARY', new Map<String, SoftValidationUtils.SoftValidationFieldValue>());
        if (params == null) params = new Map<String, Object>();

        this.expressionEvaluationResults = new List<Object>();
        for (SoftValidationFormulaExpression expression : this.expressions){
            this.expressionEvaluationResults.add(this.evaluateExpression(expression, dataSourceObject, fieldValueCache, params));
        }

        String result = '';

        for (Integer i = 0; i < this.templateItems.size(); i++){
            Object item = this.templateItems.get(i);
            String itemString;

            if (item instanceof String){
                itemString = (String) item;
            }
            else if (item instanceof Integer){
                Object evalResult = this.expressionEvaluationResults.get((Integer) item);
                itemString = '{!#error}';

                if (evalResult != null && evalResult instanceof SoftValidationFormulaExpression.ExpressionEvaluationResult){
                    SoftValidationFormulaExpression.ExpressionEvaluationResult expEvalResult = (SoftValidationFormulaExpression.ExpressionEvaluationResult) evalResult;
                    itemString = (expEvalResult.value == null ? '' : String.valueOf(expEvalResult.value));
                }

                if (this.isRichText) itemString = itemString.escapeHtml4();
            }

            result += itemString;
        }

        return result;
    }

    /*
    * helper method that can be used for troubleshooting or analyzing how the passed template was parsed
     */
    public List<SoftValidationFormulaExpression> getExpressions(){
        if (this.expressions == null) throw new SoftValidationMergeFieldsProcessorParseException('template is not parsed.');

        return new List<SoftValidationFormulaExpression>(this.expressions);
    }

    /*
    * helper method that can be used for troubleshooting or analyzing how the passed template was evaluated
     */
    public List<Object> getExpressionsEvaluationResults(){
        if (this.expressionEvaluationResults == null) throw new SoftValidationMergeFieldsProcessorEvaluateException('template is not evaluated.');

        return new List<Object>(this.expressionEvaluationResults);
    }

    /*
    * helper method to quickly understand whether given template has merge fields (expressions) or not
     */
    public Boolean hasMergeFields(){
        if (this.expressions == null) throw new SoftValidationMergeFieldsProcessorParseException('template is not parsed.');

        return (this.expressions.size() > 0);
    }

    /************************** PRIVATE METHODS **************************/

    private void parseText(){
        //there are no such escape sequences like "&crll;" or "&crlr;", but we need to allow to use "{" or "}" characters inside a merge field somehow, so "\{" will be replaced with "&crll;" and "\}" with "&crlr;"
        String template = this.template.replace('\\{', '&crll;').replace('\\}', '&crlr;');

        this.templateItems = new List<Object>();
        this.expressions = new List<SoftValidationFormulaExpression>();
        Map<String, Integer> mergeFieldExpressionIndices = new Map<String, Integer>();

        while (template.length() > 0){
            Integer expOpeningIndex = template.indexOf('{!');

            if (expOpeningIndex > -1){
                String textBeforeExp = template.substring(0, expOpeningIndex);
                if (String.isNotBlank(textBeforeExp)) this.templateItems.add(textBeforeExp.replace('&crll;', '{').replace('&crlr;', '}'));

                template = template.substring(expOpeningIndex + 2);
                Integer expClosingIndex = template.indexOf('}');
                Integer nextExpOpeningIndex = template.indexOf('{');

                if (expClosingIndex == -1 || (nextExpOpeningIndex != -1 && nextExpOpeningIndex < expClosingIndex)){
                    template = (nextExpOpeningIndex != -1 ? template.substring(0, nextExpOpeningIndex) : template).replace('&crll;', '{').replace('&crlr;', '}');
                    throw new SoftValidationMergeFieldsProcessorParseException('closing curly bracket is missing for the merge field "{!' + template + '".');
                }
                else{
                    String expression = template.substring(0, expClosingIndex).replace('&crll;', '{').replace('&crlr;', '}');
                    if (String.isBlank(expression)) throw new SoftValidationMergeFieldsProcessorParseException('merge field is empty.');

                    if (this.isRichText) expression = expression.unescapeHtml4();

                    if (!mergeFieldExpressionIndices.containsKey(expression)){
                        this.expressions.add(getExpressionInstance(expression));
                        mergeFieldExpressionIndices.put(expression, this.expressions.size() - 1);
                    }

                    this.templateItems.add(mergeFieldExpressionIndices.get(expression));

                    template = template.substring(expClosingIndex + 1);
                }
            }
            else{
                this.templateItems.add(template.replace('&crll;', '{').replace('&crlr;', '}'));
                template = '';
            }
        }
    }

    /*
    * Creates and returns instance of SoftValidationFormulaExpression class, catches exceptions and re-throws them with additional info (if needed)
     */
    private SoftValidationFormulaExpression getExpressionInstance(String expressionString){
        SoftValidationFormulaExpression expression;

        try{
            expression = new SoftValidationFormulaExpression(expressionString, null);
        }
        catch(Exception ex){
            Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
            String errMsg = 'expression "' + expressionString + '": ' + ex.getMessage();
            if (!isCustomException) errMsg += ', Stack String: ' + ex.getStackTraceString();

            throw new SoftValidationMergeFieldsProcessorParseException(errMsg);
        }

        return expression;
    }

    /*
    * Evaluates given expression, catches exceptions and re-throws them if needed
    * @dataSourceObject, @fieldValueCache, @params - see description of the parent "evaluate" method
     */
    private Object evaluateExpression(SoftValidationFormulaExpression expression, Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params){
        Object evaluationResult;
        String mergeFieldEvaluateOnError = (String) params.get('mergeFieldEvaluateOnError');

        try{
            evaluationResult = expression.evaluate(dataSourceObject, null, fieldValueCache, params);
        }
        catch(Exception ex){
            Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
            String errMsg = 'expression "' + expression.expressionString + '": ' + ex.getMessage();
            if (!isCustomException) errMsg += ', Stack String: ' + ex.getStackTraceString();

            evaluationResult = errMsg;
            if (mergeFieldEvaluateOnError == 'throwException' || Test.isRunningTest()) throw new SoftValidationMergeFieldsProcessorEvaluateException(errMsg);
        }

        return evaluationResult;
    }

    /************************** HELPER CLASSES **************************/

    public class SoftValidationMergeFieldsProcessorParseException extends Exception {}
    public class SoftValidationMergeFieldsProcessorEvaluateException extends Exception {}
}