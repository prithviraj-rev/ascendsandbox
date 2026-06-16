/******************************************************************************
// File Name:       SoftValidationRule
// Summary:         This class allows to evaluate a list of logical criterions and returns TRUE or FALSE.
// Test Class:      SoftValidationRuleTest
// Created On:      08/01/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/01/2021 - created class
*******************************************************************************/

public without sharing class SoftValidationRule {
    private static final Set<Type> CUSTOM_EXCEPTION_TYPES = new Set<Type>{
        SoftValidationCriterion.SoftValidationCriterionParseException.class,
        SoftValidationCriterion.SoftValidationCriterionEvaluateException.class,
        SoftValidationLogicExpression.SoftValidationLogicExpressionParseException.class,
        SoftValidationLogicExpression.SoftValidationLogicExpressionEvaluateException.class
    };

    public SoftValidationLogicExpression logicExpression {get; private set;}

    private List<SoftValidationCriterion> softValidationCriteria{
        get{
            if (softValidationCriteria == null){
                softValidationCriteria = new List<SoftValidationCriterion>();
            }

            return softValidationCriteria;
        }
        set;
    }

    /*
    * Constructor, which inits rule and parses given logic expression right away (if it's not blank).
    * @logicExpressionString - string in form "1 AND 2", "(1 AND 2) OR (3 AND 4)", "1 AND NOT 2" etc.
     */
    public SoftValidationRule(String logicExpressionString){
        if (String.isNotBlank(logicExpressionString)){
            try{
                this.logicExpression = new SoftValidationLogicExpression(logicExpressionString);
            }
            catch(Exception ex){
                Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
                String errMsg = 'logic expression: ' + ex.getMessage();
                if (!isCustomException) errMsg += ', Stack String: ' + ex.getStackTraceString();

                throw new SoftValidationRuleParseException(errMsg);
            }
        }
    }

    /*
    * Adds a criterion to this rule
     */
    public SoftValidationCriterion addCriterion(String leftExpressionType, String leftExpressionString, String operator, String rightExpressionType, String rightExpressionString){
        SoftValidationCriterion criterion;
        Integer criterionNum = this.softValidationCriteria.size() + 1;

        try{
            criterion = new SoftValidationCriterion(leftExpressionType, leftExpressionString, operator, rightExpressionType, rightExpressionString);
            this.softValidationCriteria.add(criterion);
        }
        catch(Exception ex){
            Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
            String errMsg = 'criterion #' + criterionNum + ': ' + ex.getMessage();
            if (!isCustomException) errMsg += ', Stack String: ' + ex.getStackTraceString();

            throw new SoftValidationRuleParseException(errMsg);
        }

        return criterion;
    }

    /*
    * Method to expose list of registered criteria so that it cannot be modified outside this class
     */
    public List<SoftValidationCriterion> getCriteria(){
        return new List<SoftValidationCriterion>(this.softValidationCriteria);
    }

    /*
    * Populates given @fieldsForQuery parameter with list of fields (for SOQL query), grouped by SObject Name.
    * If it's not a special object, where we know its name in advance, the Object Name will be "PRIMARY"
    * Map key - SObject Name
    * Map value - Set of fields
     */
    public void getFieldsForQuery(Map<String, Set<String>> fieldsForQuery){
        for (SoftValidationCriterion criterion : this.softValidationCriteria){
            criterion.getFieldsForQuery(fieldsForQuery);
        }
    }

    /*
    * Evaluates all registered criteria, applies Logic Expression to results (if Logic Expression is not set then "AND" is used) and returns TRUE or FALSE.
    * @dataSourceObject - optional, can be an SObject or IDataSourceObject. If an expression references some fields/properties then a run-time error will occur if dataSourceObject is not provided.
    * @fieldValueCache - optional, key1 - Object Name (for context object "PRIMARY" is used), key2 - Field Name, value - [field value + type] (SoftValidationUtils.SoftValidationFieldValue object).
    * @params (not in use - reserved for future) - optional, arbitrary set of params. May, for example, contain data-source records for other subsidiary SObject types.
     */
    public Boolean evaluate(Object dataSourceObject, Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>> fieldValueCache, Map<String, Object> params){
        if (this.softValidationCriteria.isEmpty()) throw new SoftValidationRuleEvaluateException('criteria for rule is not set.');

        if (fieldValueCache == null) fieldValueCache = new Map<String, Map<String, SoftValidationUtils.SoftValidationFieldValue>>();
        if (!fieldValueCache.containsKey('PRIMARY')) fieldValueCache.put('PRIMARY', new Map<String, SoftValidationUtils.SoftValidationFieldValue>());

        //if Logic Expression is provided then getting its all indices - we don't want to evaluate a criterion if it's not in the Logic Expression
        Set<Integer> logicExpressionIndices = new Set<Integer>();
        if (this.logicExpression != null) logicExpressionIndices.addAll(this.logicExpression.getAllIndices());

        List<Boolean> criterionEvaluationResults = new List<Boolean>();
        Integer criterionNum = 0;

        for (SoftValidationCriterion criterion : this.softValidationCriteria){
            criterionNum++;

            if (this.logicExpression != null && !logicExpressionIndices.contains(criterionNum)){
                criterionEvaluationResults.add(null);
                continue;
            }

            try{
                Boolean criterionEvaluationResult = criterion.evaluate(dataSourceObject, fieldValueCache, params);

                //if Logic Expression is not provided then using "AND" logic by default,
                // i.e. if at least one criterion returns FALSE, then the whole rule returns FALSE
                if (criterionEvaluationResult == false && this.logicExpression == null) return false;

                criterionEvaluationResults.add(criterionEvaluationResult);
            }
            catch(Exception ex){
                Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
                String errMsg = 'criterion #' + criterionNum + ': ' + ex.getMessage();
                if (!isCustomException) errMsg += ', Stack String: ' + ex.getStackTraceString();

                throw new SoftValidationRuleEvaluateException(errMsg);
            }
        }

        Boolean evaluationResult = true;

        if (this.logicExpression != null){
            try{
                evaluationResult = this.logicExpression.evaluate(criterionEvaluationResults, null);
            }
            catch(Exception ex){
                Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
                String errMsg = 'logic expression: ' + ex.getMessage();
                if (!isCustomException) errMsg += ', Stack String: ' + ex.getStackTraceString();

                throw new SoftValidationRuleEvaluateException(errMsg);
            }
        }

        return evaluationResult;
    }

    /************************** HELPER CLASSES **************************/

    public class SoftValidationRuleParseException extends Exception {}
    public class SoftValidationRuleEvaluateException extends Exception {}
}