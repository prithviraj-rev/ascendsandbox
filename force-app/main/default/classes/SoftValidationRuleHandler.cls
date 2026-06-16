/******************************************************************************
// File Name:       SoftValidationRuleHandler
// Summary:         Trigger Handler for the SoftValidationRule__c SObject. This class implements the ITrigger interface to help ensure the trigger code is bulkified and all in one place.
// Test Class:      SoftValidationRuleHandlerTest
// Created On:      08/01/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 08/01/2021 - created class
Konstantin Ermolenko - 10/28/2021 - added support for Merge Fields in Rule Message
Konstantin Ermolenko - 11/03/2021 - separated Rule Criteria and Message validation
Konstantin Ermolenko - 09/28/2022 - modified "validateRule" method to resolve "Non-selective query against large object type" error on some sObjects
*******************************************************************************/

public without sharing class SoftValidationRuleHandler /*implements ITrigger*/ {
    public static Boolean disableValidation = false;
    public static Boolean isMessageSave = false; //used by "softValidationMessageEditor" LWC and validates only Message upon saving

    private static final Set<Type> CUSTOM_EXCEPTION_TYPES = new Set<Type>{
        SoftValidationRuleHandlerException.class,
        SoftValidationLogicExpression.SoftValidationLogicExpressionParseException.class,
        SoftValidationLogicExpression.SoftValidationLogicExpressionEvaluateException.class,
        SoftValidationFormulaExpression.SoftValidationFormulaExpressionParseException.class,
        SoftValidationFormulaExpression.SoftValidationFormulaExpressionEvaluateException.class,
        SoftValidationCriterion.SoftValidationCriterionParseException.class,
        SoftValidationCriterion.SoftValidationCriterionEvaluateException.class,
        SoftValidationRule.SoftValidationRuleParseException.class,
        SoftValidationRule.SoftValidationRuleEvaluateException.class,
        SoftValidationMergeFieldsProcessor.SoftValidationMergeFieldsProcessorParseException.class,
        SoftValidationMergeFieldsProcessor.SoftValidationMergeFieldsProcessorEvaluateException.class
    };

    public void bulkBefore(){
        if (Trigger.isInsert || Trigger.isUpdate){
            for (SoftValidationRule__c rule : (List<SoftValidationRule__c>) Trigger.new){
                Boolean isValid = validateRule(rule);

                if (isValid){
                    updateCriteriaReview(rule);
                }
            }
        }
    }

    public void bulkAfter(){}

    public void beforeInsert(SObject so){}

    public void beforeUpdate(SObject oldSo, SObject so){}

    public void beforeDelete(SObject so){}

    public void afterInsert(SObject so){}

    public void afterUpdate(SObject oldSo, SObject so){}

    public void afterDelete(SObject so){}

    public void afterUndelete(SObject so){}

    public void andFinally(){}

    /*
    * Helper method to ensure rule is valid
     */
    private Boolean validateRule(SoftValidationRule__c rule){
        if (disableValidation == true) return true;

        Boolean isValid = true;
        String errorMsg = 'Unknown validation error.';
        Boolean errorMsgIsSet = false;

        try{
            //check Object
            Type objType = Type.forName(rule.ObjectAPIName__c);
            if (objType == null){
                if (isMessageSave == true){
                    rule.addError('Object with name "' + rule.ObjectAPIName__c + '" does not exist.');
                }
                else{
                    rule.addError('ObjectAPIName__c', 'Object with this name does not exist.');
                }

                errorMsgIsSet = true;
                throw new SoftValidationRuleHandlerException('abort validation');
            }

            SObject objRecord = (SObject) objType.newInstance();
            Schema.SObjectType sObjectType = objRecord.getSObjectType();
            Schema.DescribeSObjectResult sObjectDescribe = sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED);

            Set<String> supportedDataTypes = SoftValidationFormulaExpression.getSupportedDataTypes();

            if (isMessageSave == true){
                //check Message Type
                if (String.isBlank(rule.MessageType__c)){
                    rule.addError('MessageType__c', 'Complete this field.');
                    errorMsgIsSet = true;
                    throw new SoftValidationRuleHandlerException('abort validation');
                }

                //check Message
                if (String.isBlank(rule.Message__c)){
                    rule.addError('Message__c', 'Complete this field.');
                    errorMsgIsSet = true;
                    throw new SoftValidationRuleHandlerException('abort validation');
                }

                Map<String, Set<String>> fieldsForQuery = new Map<String, Set<String>>();
                Boolean ruleMessageIsValid = validateMessage(rule, sObjectType, supportedDataTypes, fieldsForQuery);
                if (ruleMessageIsValid == false){
                    errorMsgIsSet = true;
                    throw new SoftValidationRuleHandlerException('abort validation');
                }
            }
            else{
                //check Record Type
                if (String.isNotBlank(rule.RecordTypeDevName__c)){
                    Boolean recordHasRTField = sObjectDescribe.fields.getMap().containsKey('RecordTypeId');

                    if (!recordHasRTField){
                        rule.addError('RecordTypeDevName__c', 'Object "' + rule.ObjectAPIName__c + '" does not have Record Types.');
                        errorMsgIsSet = true;
                        throw new SoftValidationRuleHandlerException('abort validation');
                    }

                    Boolean rtExists = sObjectDescribe.getRecordTypeInfosByDeveloperName().containsKey(rule.RecordTypeDevName__c);
                    if (!rtExists){
                        rule.addError('RecordTypeDevName__c', 'Record Type with this name does not exist. Check spelling/case - RT name is case-sensitive.');
                        errorMsgIsSet = true;
                        throw new SoftValidationRuleHandlerException('abort validation');
                    }
                }

                //check Criteria populated/consistent
                List<Map<String, String>> rawCriteria = new List<Map<String, String>>();
                Set<Integer> nonBlankCriterionIndices = new Set<Integer>();
                Boolean hasRawCriteriaWithBlankRequiredFields = false;

                for (Integer i = 1; i <= SoftValidationController.MAX_CRITERIA_NUMBER; i++){
                    Map<String, String> rawCriterion = validateRuleGetRawCriterion(i, rule);

                    if (rawCriterion != null){
                        for (String fieldName : rawCriterion.keySet()){
                            String fieldValue = rawCriterion.get(fieldName);

                            if (String.isBlank(fieldValue)){
                                rule.addError('Criteria' + i + fieldName + '__c', 'Complete this field.');
                                hasRawCriteriaWithBlankRequiredFields = true;
                            }
                        }

                        nonBlankCriterionIndices.add(i);
                    }

                    rawCriteria.add(rawCriterion);
                }

                if (hasRawCriteriaWithBlankRequiredFields){
                    errorMsgIsSet = true;
                    throw new SoftValidationRuleHandlerException('abort validation');
                }

                //check if at least 1 Criterion is populated
                if (nonBlankCriterionIndices.isEmpty()) throw new SoftValidationRuleHandlerException('At least one Rule Criterion must be configured.');

                //check if Criteria is populated without gaps
                Integer lastPopulatedCriterionIndex;
                Integer invalidBlankCriterionIndex;
                for (Integer i = 0; i < rawCriteria.size(); i++){
                    if (rawCriteria.get(i) != null){
                        if (i > 0 && (lastPopulatedCriterionIndex == null || i - lastPopulatedCriterionIndex > 1)){
                            invalidBlankCriterionIndex = i + 1;
                            break;
                        }

                        lastPopulatedCriterionIndex = i;
                    }
                }
                if (invalidBlankCriterionIndex != null) throw new SoftValidationRuleHandlerException('Criterion #' + invalidBlankCriterionIndex + ' is misplaced. All Criteria must be configured successively (from 1 to ' + SoftValidationController.MAX_CRITERIA_NUMBER + '), without blank Criteria in between.');

                //check if Filter Logic can be parsed and has valid Criterion Indices
                if (String.isNotBlank(rule.FilterLogic__c)){
                    SoftValidationLogicExpression logicExpression;

                    try{
                        logicExpression = new SoftValidationLogicExpression(rule.FilterLogic__c);
                    }
                    catch(Exception ex){
                        Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
                        String filterLogicErrMsg = 'Parsing error: ' + ex.getMessage();
                        if (!isCustomException) filterLogicErrMsg += ', Stack String: ' + ex.getStackTraceString();

                        rule.addError('FilterLogic__c', filterLogicErrMsg);
                        errorMsgIsSet = true;
                        throw new SoftValidationRuleHandlerException('abort validation');
                    }

                    List<Integer> allIndices = logicExpression.getAllIndices();
                    for (Integer index : allIndices){
                        if (index < 1 || index > SoftValidationController.MAX_CRITERIA_NUMBER){
                            rule.addError('FilterLogic__c', 'Invalid criterion number - "' + index + '". Only numbers from 1 to ' + SoftValidationController.MAX_CRITERIA_NUMBER + ' are allowed.');
                            errorMsgIsSet = true;
                            throw new SoftValidationRuleHandlerException('abort validation');
                        }

                        if (!nonBlankCriterionIndices.contains(index)){
                            rule.addError('FilterLogic__c', 'Criterion #' + index + ' is not configured.');
                            errorMsgIsSet = true;
                            throw new SoftValidationRuleHandlerException('abort validation');
                        }
                    }

                    Set<Integer> allIndicesSet = new Set<Integer>(allIndices);
                    for (Integer index : nonBlankCriterionIndices){
                        if (!allIndicesSet.contains(index)){
                            rule.addError('FilterLogic__c', 'Criterion #' + index + ' is configured but not referenced in the filter logic.');
                            errorMsgIsSet = true;
                            throw new SoftValidationRuleHandlerException('abort validation');
                        }
                    }
                }

                //validate expressions
                Boolean hasInvalidExpressions = false;

                List<String> criterionExpressionPositions = new List<String>{'Left', 'Right'};
                for (Integer i = 0; i < rawCriteria.size(); i++){
                    Map<String, String> rawCriterion = rawCriteria.get(i);
                    if (rawCriterion == null) break;
                    Integer index = i + 1;

                    for (String position : criterionExpressionPositions){
                        Boolean expressionIsValid = false;
                        String expressionTypeFieldName = 'Criteria' + index + position + 'ExpressionType__c';
                        String expressionFieldName = 'Criteria' + index + position + 'Expression__c';

                        String expressionType = (String) rule.get(expressionTypeFieldName);
                        String expressionString = (String) rule.get(expressionFieldName);
                        SoftValidationFormulaExpression expression;

                        try{
                            expression = new SoftValidationFormulaExpression(expressionString, expressionType.toUpperCase());
                            expressionIsValid = true;
                        }
                        catch(Exception ex){
                            Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
                            String expressionErrMsg = 'Parsing error: ' + ex.getMessage();
                            if (!isCustomException) expressionErrMsg += ', Stack String: ' + ex.getStackTraceString();

                            rule.addError(expressionFieldName, expressionErrMsg);
                            errorMsgIsSet = true;
                            hasInvalidExpressions = true;
                        }

                        if (expressionIsValid){
                            //validate expression fields:
                            Map<String, Set<String>> fieldsForQuery = new Map<String, Set<String>>();
                            expression.getFieldsForQuery(fieldsForQuery);

                            Set<String> primaryObjectFieldsSet = fieldsForQuery.get('PRIMARY');
                            if (primaryObjectFieldsSet != null && !primaryObjectFieldsSet.isEmpty()){
                                for (String fieldExpression : primaryObjectFieldsSet){
                                    String fieldValidationErrorMsg = validateFieldExpression(sObjectType, supportedDataTypes, fieldExpression);

                                    if (String.isNotBlank(fieldValidationErrorMsg)){
                                        rule.addError(expressionFieldName, fieldValidationErrorMsg);
                                        errorMsgIsSet = true;
                                        hasInvalidExpressions = true;

                                        break;
                                    }
                                }
                            }
                        }
                    }
                }

                if (hasInvalidExpressions == true) throw new SoftValidationRuleHandlerException('abort validation');

                //validate rule as a whole
                //at this point parsing errors are not supposed to occur, but if they do, they will be handled in the general "catch" block
                SoftValidationRule softRule = new SoftValidationRule(rule.FilterLogic__c);

                for (Integer i = 0; i <= rawCriteria.size(); i++){
                    Map<String, String> rawCriterion = rawCriteria.get(i);
                    if (rawCriterion == null) break;
                    Integer index = i + 1;

                    String leftExpressionType = (String) rule.get('Criteria' + index + 'LeftExpressionType__c');
                    String leftExpression = (String) rule.get('Criteria' + index + 'LeftExpression__c');
                    String operator = (String) rule.get('Criteria' + index + 'Operator__c');
                    String rightExpressionType = (String) rule.get('Criteria' + index + 'RightExpressionType__c');
                    String rightExpression = (String) rule.get('Criteria' + index + 'RightExpression__c');

                    softRule.addCriterion(leftExpressionType, leftExpression, operator, rightExpressionType, rightExpression);
                }

                Map<String, Set<String>> fieldsForQuery = new Map<String, Set<String>>();

                //validate Merge Fields in the Rule Message
                if (String.isNotBlank(rule.Message__c)){
                    Boolean ruleMessageIsValid = validateMessage(rule, sObjectType, supportedDataTypes, fieldsForQuery);
                    if (ruleMessageIsValid == false){
                        errorMsgIsSet = true;
                        throw new SoftValidationRuleHandlerException('abort validation');
                    }
                }

                //final check - if Rule uses fields in the expressions we need to make a query to db to ensure it does not fail:
                softRule.getFieldsForQuery(fieldsForQuery);

                Set<String> primaryObjectFieldsSet = fieldsForQuery.get('PRIMARY');
                if (primaryObjectFieldsSet != null && !primaryObjectFieldsSet.isEmpty()){
                    //Begin 09/28/2022
                    //To avoid potential "Non-selective query against large object type" error we generate a mock record id and use it instead "limit 1" in the SQOL query.
                    String keyPrefix = Schema.getGlobalDescribe().get(rule.ObjectAPIName__c).getDescribe().getKeyPrefix();
                    Id mockRecordId = keyPrefix.rightPad(18, '0');
                    //End 09/28/2022

                    String primaryObjectFields = String.escapeSingleQuotes(String.join(new List<String>(primaryObjectFieldsSet), ','));
                    String query = 'SELECT ' + primaryObjectFields + ' FROM ' + rule.ObjectAPIName__c + ' WHERE Id = :mockRecordId';

                    try{
                        Database.query(query);
                    }
                    catch(Exception ex){
                        rule.addError('Failed to run SOQL query for this Rule: ' + ex.getMessage());
                        errorMsgIsSet = true;
                        throw new SoftValidationRuleHandlerException('abort validation');
                    }
                }
            }
        }
        catch(Exception ex){
            isValid = false;

            if (errorMsgIsSet == false){
                Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));

                errorMsg = ex.getMessage();
                if (!isCustomException) errorMsg += ', Stack String: ' + ex.getStackTraceString();
            }
        }

        if (isValid == false && errorMsgIsSet == false){
            rule.addError(errorMsg);
        }

        return isValid;
    }

    private Boolean validateMessage(SoftValidationRule__c rule, Schema.SObjectType sObjectType, Set<String> supportedDataTypes, Map<String, Set<String>> fieldsForQuery){
        Boolean isValid = true;
        SoftValidationMergeFieldsProcessor mergeFieldsProcessor;

        try{
            mergeFieldsProcessor = new SoftValidationMergeFieldsProcessor(rule.Message__c, true);
        }
        catch(Exception ex){
            Boolean isCustomException = CUSTOM_EXCEPTION_TYPES.contains(Type.forName(ex.getTypeName()));
            String expressionErrMsg = 'Parsing error: ' + ex.getMessage();
            if (!isCustomException) expressionErrMsg += ', Stack String: ' + ex.getStackTraceString();

            rule.addError('Message__c', expressionErrMsg);
            isValid = false;
        }

        if (isValid){
            mergeFieldsProcessor.getFieldsForQuery(fieldsForQuery);

            Set<String> primaryObjectFieldsSet = fieldsForQuery.get('PRIMARY');
            if (primaryObjectFieldsSet != null && !primaryObjectFieldsSet.isEmpty()){
                for (String fieldExpression : primaryObjectFieldsSet){
                    String fieldValidationErrorMsg = validateFieldExpression(sObjectType, supportedDataTypes, fieldExpression);

                    if (String.isNotBlank(fieldValidationErrorMsg)){
                        rule.addError('Message__c', fieldValidationErrorMsg);
                        isValid = false;

                        break;
                    }
                }
            }
        }

        return isValid;
    }

    /*
    * Verifies if a Criterion for the given index has all fields populated if its Left/Right Expressions are not blank.
    * Returns a map with values for all Criterion fields.
     */
    private Map<String, String> validateRuleGetRawCriterion(Integer index, SoftValidationRule__c rule){
        Map<String, String> rawCriterion;

        String leftExpressionType = (String) rule.get('Criteria' + index + 'LeftExpressionType__c');
        String leftExpression = (String) rule.get('Criteria' + index + 'LeftExpression__c');
        String operator = (String) rule.get('Criteria' + index + 'Operator__c');
        String rightExpressionType = (String) rule.get('Criteria' + index + 'RightExpressionType__c');
        String rightExpression = (String) rule.get('Criteria' + index + 'RightExpression__c');

        if (String.isNotBlank(leftExpression) || String.isNotBlank(rightExpression)){
            rawCriterion = new Map<String, String>{
                'LeftExpressionType' => leftExpressionType,
                'LeftExpression' => leftExpression,
                'Operator' => operator,
                'RightExpressionType' => rightExpressionType,
                'RightExpression' => rightExpression
            };
        }
        else{
            //just in case clear Type/Operator picklists for visual consistency
            rule.put('Criteria' + index + 'LeftExpressionType__c', null);
            rule.put('Criteria' + index + 'Operator__c', null);
            rule.put('Criteria' + index + 'RightExpressionType__c', null);
        }

        return rawCriterion;
    }

    /*
    * Calculates summary for CriteriaReview__c field based on rule's criteria
     */
    private void updateCriteriaReview(SoftValidationRule__c rule){
        String criteriaReview = '';
        Map<Integer, String> criterionReviewByIndex = new Map<Integer, String>();

        for (Integer i = 1; i <= SoftValidationController.MAX_CRITERIA_NUMBER; i++){
            String criterionReview = getCriterionReview(i, rule);
            if (String.isNotBlank(criterionReview)) criterionReviewByIndex.put(i, criterionReview);
        }

        if (String.isBlank(rule.FilterLogic__c)){
            List<String> criterionReviews = new List<String>();

            for (Integer i = 1; i <= SoftValidationController.MAX_CRITERIA_NUMBER; i++){
                String criterionReview = criterionReviewByIndex.get(i);

                if (String.isBlank(criterionReview)) break;
                criterionReviews.add(criterionReview);
            }

            criteriaReview = String.join(criterionReviews, ' AND ');
        }
        else{
            String digits = '';

            for (Integer i = 0; i < rule.FilterLogic__c.length(); i++){
                String oneCharacter = rule.FilterLogic__c.substring(i, i + 1);
                Boolean isNumeric = oneCharacter.isNumeric();
                Boolean isLastIteration = (i == rule.FilterLogic__c.length() - 1);

                if (isNumeric){
                    digits += oneCharacter;
                }

                if (!isNumeric || isLastIteration){
                    if (digits.length() > 0){
                        Integer index = Integer.valueOf(digits);
                        criteriaReview += (criterionReviewByIndex.containsKey(index) ? criterionReviewByIndex.get(index) : digits);
                    }

                    if (!isNumeric){
                        criteriaReview += oneCharacter;
                        digits = '';
                    }
                }
            }
        }

        rule.CriteriaReview__c = criteriaReview;
    }

    /*
    * Generates summary string for the given criterion index
     */
    private String getCriterionReview(Integer index, SoftValidationRule__c rule){
        String criterionReview;
        Integer expressionLengthLimit = 0;

        String leftExpressionType = (String) rule.get('Criteria' + index + 'LeftExpressionType__c');
        String leftExpression = (String) rule.get('Criteria' + index + 'LeftExpression__c');
        String operator = (String) rule.get('Criteria' + index + 'Operator__c');
        String rightExpressionType = (String) rule.get('Criteria' + index + 'RightExpressionType__c');
        String rightExpression = (String) rule.get('Criteria' + index + 'RightExpression__c');

        if (String.isBlank(leftExpression)) return null;

        criterionReview = '' +
            '['+
                (expressionLengthLimit > 0 && leftExpression.length() > expressionLengthLimit ? leftExpression.substring(0, expressionLengthLimit) + '...' : leftExpression) +
                ' ' + SoftValidationCriterion.getOperatorShortcut(operator) + ' ' +
                (expressionLengthLimit > 0 && rightExpression.length() > expressionLengthLimit ? rightExpression.substring(0, expressionLengthLimit) + '...' : rightExpression) +
            ']';


        return criterionReview;
    }

    /*
    * Makes sure that field exists and is of supported type, otherwise returns error message
     */
    private String validateFieldExpression(Schema.SObjectType sObjectType, Set<String> supportedDataTypes, String fieldExpression){
        String fieldValidationErrorMsg;
        SoftValidationUtils.SoftValidationFieldTypeDetails fieldTypeDetails = SoftValidationUtils.getFieldTypeRecursive(sObjectType, fieldExpression);

        if (fieldTypeDetails != null){
            String fieldNameOriginalLower = fieldTypeDetails.fieldNameOriginal.toLowerCase();

            if (fieldTypeDetails.describeFieldResult == null){
                fieldValidationErrorMsg = 'Field with name "' + fieldTypeDetails.fieldNameOriginal + '" does not exist on object "' + fieldTypeDetails.objectName + '".';
                if (!(fieldNameOriginalLower.endsWith('__c') || fieldNameOriginalLower.endsWith('__r'))){
                    fieldValidationErrorMsg += ' If it\'s a standard lookup field then make sure to add "Id" to the end of the field name.';
                }
            }
            else{
                String fieldDisplayType = String.valueOf(fieldTypeDetails.describeFieldResult.getType());

                if (fieldTypeDetails.isLastFieldInExpression == true){
                    if (fieldDisplayType == 'REFERENCE'){
                        if (!(fieldNameOriginalLower.endsWith('id') || fieldNameOriginalLower.endsWith('__c'))){
                            fieldValidationErrorMsg = 'Last field in expression cannot end with a lookup field: "' + fieldTypeDetails.fieldNameOriginal + '".';
                        }
                    }

                    if (String.isBlank(fieldValidationErrorMsg) && fieldTypeDetails.type != null && !supportedDataTypes.contains(fieldTypeDetails.type)){
                        fieldValidationErrorMsg = 'Field "' + fieldTypeDetails.fieldNameOriginal + '": unsupported field type ' + fieldDisplayType;
                    }
                }
            }
        }

        return fieldValidationErrorMsg;
    }

    public class SoftValidationRuleHandlerException extends Exception {}
}