/******************************************************************************
// File Name:       SoftValidationUtils
// Summary:         Helper class for "Soft Validation" solution with a number of re-usable static methods
// Test Class:      SoftValidationUtilsTest
// Created On:      07/29/2021

// Modification Log: (Name - Change Summary - Initial)
====================
Konstantin Ermolenko - 07/29/2021 - created class
*******************************************************************************/

public without sharing class SoftValidationUtils {

    /************************** PUBLIC METHODS **************************/

    /*
    * This method finds index of the given @closingChar, ignoring text literals.
     */
    public static Integer findClosingCharacterIndex(String expressionString, String openingChar, String closingChar){
        Integer index = -1;
        Integer charToFindOccurrenceCount = 0;
        Boolean isTextLiteral = false;

        for (Integer i = 0; i < expressionString.length(); i++){
            String character = expressionString.substring(i, i + 1);

            if (character == '"'){
                isTextLiteral = !isTextLiteral;
            }
            else if (isTextLiteral == false && (character == openingChar || character == closingChar)){
                charToFindOccurrenceCount += (character == openingChar ? 1 : -1);
                if (character == closingChar && charToFindOccurrenceCount < 0){
                    index = i;
                    break;
                }
            }
        }

        return index;
    }

    /*
    * Helper method, which throws exception if given Field Expression is not valid. It does not check whether a field exists in the database for real or not.
    * For passing validation it can only contain alphanumeric characters, must begin with a letter, cannot end with an underscore/__r or contain two consecutive underscore/dot characters
     */
    public static Map<String, Object> validateFieldExpressionSoft(String fieldExpression){
        Boolean isValid = true;
        String errorMsg;

        if (fieldExpression.startsWith('.') || fieldExpression.endsWith('.')){
            isValid = false;
            errorMsg = 'invalid field expression - "' + fieldExpression + '". It cannot start or end with a dot character.';
        }
        else if (fieldExpression.indexOf('..') != -1){
            isValid = false;
            errorMsg = 'invalid field expression - "' + fieldExpression + '". It cannot contain two consecutive dot characters.';
        }
        else{
            List<String> fieldExpressionItems = fieldExpression.split('\\.');

            for (Integer i = 0; i < fieldExpressionItems.size(); i++){
                String fieldExpressionItem = fieldExpressionItems.get(i);
                String fieldExpressionItemLower = fieldExpressionItem.toLowerCase();

                if (fieldExpressionItemLower.left(1).isAlpha() == false){
                    isValid = false;
                    errorMsg = 'invalid field name - "' + fieldExpressionItem + '". A field name must begin with a letter.';
                    break;
                }

                if (fieldExpressionItems.size() - 1 == i){ //last item in expression
                    if (fieldExpressionItemLower.endsWith('__r')){
                        isValid = false;
                        errorMsg = 'invalid field expression - "' + fieldExpression + '". Last field in expression cannot end with \'__r\'.';
                        break;
                    }

                    if (fieldExpressionItemLower.endsWith('__c')) fieldExpressionItemLower = fieldExpressionItemLower.left(fieldExpressionItemLower.length() - 3);
                }
                else{
                    if (fieldExpressionItemLower.endsWith('__c') || fieldExpressionItemLower.endsWith('id')){
                        isValid = false;
                        errorMsg = 'invalid field expression - "' + fieldExpression + '". Intermediate field in expression cannot end with \'__c\' or \'Id\'.';
                        break;
                    }

                    if (fieldExpressionItemLower.endsWith('__r')) fieldExpressionItemLower = fieldExpressionItemLower.left(fieldExpressionItemLower.length() - 3);
                }

                if (fieldExpressionItemLower.endsWith('_')){
                    isValid = false;
                    errorMsg = 'invalid field name - "' + fieldExpressionItem + '". A field name cannot end with an underscore.';
                    break;
                }
                else if (fieldExpressionItemLower.indexOf('__') != -1){
                    isValid = false;
                    errorMsg = 'invalid field name - "' + fieldExpressionItem + '". A field name cannot contain two consecutive underscore characters.';
                    break;
                }
                else{
                    isValid = Pattern.matches('[a-zA-Z0-9_]+', fieldExpressionItemLower);

                    if (isValid == false){
                        errorMsg = 'invalid field name - "' + fieldExpressionItem + '". A field name can only contain alphanumeric characters and underscores.';
                        break;
                    }
                }
            }
        }

        return new Map<String, Object>{'isValid' => isValid, 'errorMsg' => errorMsg};
    }

    /*
    * This method populates the given @fieldsForQuery variable with objectName + fieldName
     */
    public static void registerFieldForQuery(Map<String, Set<String>> fieldsForQuery, String objectName, String fieldName){
        if (!fieldsForQuery.containsKey(objectName)){
            fieldsForQuery.put(objectName, new Set<String>());
        }

        fieldsForQuery.get(objectName).add(fieldName);
    }

    /*
    * Helper method to get a value for the given Record + Field Name (can traverse relation fields) and determine field type.
    * IMPORTANT: returns NULL if meets a "null" relation field while traversing chain of fields.
     */
    public static SoftValidationFieldValue getFieldValue(SObject record, String fieldName){
        SoftValidationFieldValue fieldValueResult;

        if (fieldName.indexOf('.') == -1){
            Object fieldValue;
            SoftValidationFieldTypeDetails fieldTypeDetails = getFieldType(record.getSObjectType(), fieldName);

            if (fieldTypeDetails != null && fieldTypeDetails.type != null){
                fieldValue = record.get(fieldName);

                if (fieldValue != null){
                    if (fieldTypeDetails.type == 'STRING'){
                        fieldValue = String.valueOf(fieldValue); //making sure Ids are converted to Strings
                    }
                    else if (fieldTypeDetails.type == 'INTEGER'){
                        fieldValue = Integer.valueOf(fieldValue); //making sure Decimals with 0 scale are converted to Integers
                    }
                }
            }

            fieldValueResult = new SoftValidationFieldValue();
            fieldValueResult.value = fieldValue;
            fieldValueResult.fieldTypeDetails = fieldTypeDetails;
        }
        else{
            SObject parentRecord = record.getSObject(fieldName.substringBefore('.'));

            if (parentRecord != null){
                fieldValueResult = getFieldValue(parentRecord, fieldName.substringAfter('.'));
            }
        }

        return fieldValueResult;
    }

    /*
    * Returns Field Type details (SoftValidationFieldTypeDetails object) for the given record and Field Name.
    * Uses "sObjectFieldTypeCache" static property to cache data.
    * NOTE: @fieldName is a single field name, i.e. values like "Account__r.Name" are not supported
     */
    public static SoftValidationFieldTypeDetails getFieldType(Schema.SObjectType sObjectType, String fieldName){
        SoftValidationFieldTypeDetails fieldTypeDetails = new SoftValidationFieldTypeDetails();

        Map<String, SoftValidationFieldTypeDetails> sObjectFieldTypes = sObjectFieldTypeCache.get(sObjectType);

        if (sObjectFieldTypes == null){
            sObjectFieldTypes = new Map<String, SoftValidationFieldTypeDetails>();
            sObjectFieldTypeCache.put(sObjectType, sObjectFieldTypes);
        }

        String fieldNameLower = fieldName.toLowerCase();

        if (!sObjectFieldTypes.containsKey(fieldNameLower)){
            Schema.DescribeSObjectResult sObjectDescribeResult = getSObjectDescribe(sObjectType);
            fieldTypeDetails.objectName = sObjectDescribeResult.getName();
            fieldTypeDetails.fieldName = fieldName;

            Map<String, Schema.SObjectField> fieldsMap = sObjectDescribeResult.fields.getMap();

            if (fieldsMap.containsKey(fieldName)){
                fieldTypeDetails = new SoftValidationFieldTypeDetails();

                Schema.DescribeFieldResult fieldDescribeResult = fieldsMap.get(fieldName).getDescribe();
                String fieldDisplayType = String.valueOf(fieldDescribeResult.getType());
                String genericFieldType;

                switch on fieldDisplayType{
                    when 'STRING', 'TEXTAREA', 'ID', 'REFERENCE', 'COMBOBOX', 'PICKLIST', 'MULTIPICKLIST', 'EMAIL', 'PHONE', 'URL'{
                        genericFieldType = 'STRING';
                    }
                    when 'INTEGER', 'DOUBLE', 'CURRENCY', 'PERCENT' {
                        genericFieldType = (fieldDescribeResult.getScale() == 0 ? 'INTEGER' : 'DECIMAL');
                    }
                    when else{
                        genericFieldType = fieldDisplayType;
                    }
                }

                fieldTypeDetails.type = genericFieldType;
                fieldTypeDetails.describeFieldResult = fieldDescribeResult;
            }

            sObjectFieldTypes.put(fieldNameLower, fieldTypeDetails);
        }
        else{
            fieldTypeDetails = sObjectFieldTypes.get(fieldNameLower);
        }

        return fieldTypeDetails;
    }

    /*
    * Helper method to traverse relation fields in the given @fieldName and determine the last field type.
    * @fieldName can be either a single field name, or expression like "Account__r.Name"
    * IMPORTANT: method will return NULL if comes across a polymorphic lookup field
     */
    public static SoftValidationFieldTypeDetails getFieldTypeRecursive(Schema.SObjectType sObjectType, String fieldName){
        SoftValidationFieldTypeDetails fieldTypeDetails;

        if (fieldName.indexOf('.') == -1){
            fieldTypeDetails = getFieldType(sObjectType, fieldName);
            fieldTypeDetails.fieldNameOriginal = fieldName;
            fieldTypeDetails.isLastFieldInExpression = true;
        }
        else{
            String lookupFieldNameOriginal = fieldName.substringBefore('.');
            String lookupFieldName = ((lookupFieldNameOriginal.endsWithIgnoreCase('__r'))
                ? lookupFieldNameOriginal.left(lookupFieldNameOriginal.length() - 1) + 'c'
                : lookupFieldNameOriginal + 'Id');

            fieldTypeDetails = getFieldType(sObjectType, lookupFieldName);
            fieldTypeDetails.fieldNameOriginal = lookupFieldNameOriginal;
            fieldTypeDetails.isLastFieldInExpression = false;

            if (fieldTypeDetails.describeFieldResult != null){
                String fieldDisplayType = String.valueOf(fieldTypeDetails.describeFieldResult.getType());

                if (fieldDisplayType == 'REFERENCE'){
                    List<Schema.SObjectType> referencedSObjects = fieldTypeDetails.describeFieldResult.getReferenceTo();

                    if (referencedSObjects.size() == 1){
                        fieldTypeDetails = getFieldTypeRecursive(referencedSObjects.get(0), fieldName.substringAfter('.'));
                    }
                    else{
                        //if more than 1 SObject Types returned (polymorphic lookup),
                        //then we cannot continue parsing process as without a real record we don't know, which path to pick up
                        fieldTypeDetails = null;
                    }
                }
            }
        }

        return fieldTypeDetails;
    }

    /************************** PRIVATE METHODS **************************/

    /*
    * Returns SObject Describe data (Schema.DescribeSObjectResult object) for the given Schema.SObjectType.
    * Uses "sObjectDescribeCache" static property to cache data.
     */
    private static Schema.DescribeSObjectResult getSObjectDescribe(Schema.SObjectType sObjectType){
        Schema.DescribeSObjectResult sObjectDescribe = sObjectDescribeCache.get(sObjectType);

        if (sObjectDescribe == null){
            sObjectDescribe = sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED);
            sObjectDescribeCache.put(sObjectType, sObjectDescribe);
        }

        return sObjectDescribe;
    }

    /************************** PRIVATE PROPERTIES **************************/

    private static Map<Schema.SObjectType, Schema.DescribeSObjectResult> sObjectDescribeCache{
        get{
            if (sObjectDescribeCache == null){
                sObjectDescribeCache = new Map<Schema.SObjectType, Schema.DescribeSObjectResult>();
            }

            return sObjectDescribeCache;
        }
        set;
    }

    private static Map<Schema.SObjectType, Map<String, SoftValidationFieldTypeDetails>> sObjectFieldTypeCache{
        get{
            if (sObjectFieldTypeCache == null){
                sObjectFieldTypeCache = new Map<Schema.SObjectType, Map<String, SoftValidationFieldTypeDetails>>();
            }

            return sObjectFieldTypeCache;
        }
        set;
    }

    /************************** HELPER CLASSES **************************/

    public class SoftValidationFieldTypeDetails{
        public String objectName {get; set;}
        public String fieldName {get; set;}
        public Schema.DescribeFieldResult describeFieldResult {get; set;} //if null then field does not exist
        public String type {get; set;} //high-level type, e.g. Field Types like 'STRING', 'PICKLIST', 'EMAIL', etc. will be united in one type = 'STRING'

        //holds name of the field like it was entered in the expression.
        //needed for validating fields, like "Account.Name" (real field name is "AccountId") or "CustomObj__r.Name" (real name is "CustomObj__c")
        public String fieldNameOriginal {get; set;}

        //needed for validating fields, like "Account.Name" to ensure that Field Type Details are applied to the target (last) field in the expression
        public Boolean isLastFieldInExpression {get; set;}
    }

    public class SoftValidationFieldValue{
        public Object value {get; set;}
        public SoftValidationFieldTypeDetails fieldTypeDetails {get; set;}
    }
}